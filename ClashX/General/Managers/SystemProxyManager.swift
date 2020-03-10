//
//  SystemProxyManager.swift
//  ClashX
//
//  Created by yichengchen on 2019/8/17.
//  Copyright © 2019 west2online. All rights reserved.
//

import AppKit
import ServiceManagement

class SystemProxyManager: NSObject {
    static let shared = SystemProxyManager()

    private static let machServiceName = "com.west2online.ClashX.ProxyConfigHelper"
    private var authRef: AuthorizationRef?
    private var connection: NSXPCConnection?
    private var _helper: ProxyConfigRemoteProcessProtocol?
    private var savedProxyInfo: [String: Any] {
        get {
            return UserDefaults.standard.dictionary(forKey: "kSavedProxyInfo") ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "kSavedProxyInfo")
        }
    }

    private var disableRestoreProxy: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "kDisableRestoreProxy")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "kDisableRestoreProxy")
        }
    }

    private var cancelInstallCheck = false

    // MARK: - LifeCycle

    override init() {
        super.init()
        initAuthorizationRef()
    }

    // MARK: - Public

    func checkInstall() {
        Logger.log("checkInstall", level: .debug)
        while !cancelInstallCheck && !helperStatus() {
            Logger.log("need to install helper", level: .debug)
            if Thread.isMainThread {
                notifyInstall()
            } else {
                DispatchQueue.main.async {
                    self.notifyInstall()
                }
            }
        }
    }

    func saveProxy() {
        guard !disableRestoreProxy else { return }
        Logger.log("saveProxy", level: .debug)
        helper()?.getCurrentProxySetting({ [weak self] info in
            Logger.log("saveProxy done", level: .debug)
            if let info = info as? [String: Any] {
                self?.savedProxyInfo = info
            }
        })
    }

    func enableProxy() {
        let port = ConfigManager.shared.currentConfig?.port ?? 0
        let socketPort = ConfigManager.shared.currentConfig?.socketPort ?? 0
        SystemProxyManager.shared.enableProxy(port: port, socksPort: socketPort)
    }

    func enableProxy(port: Int, socksPort: Int) {
        guard port > 0 && socksPort > 0 else {
            Logger.log("enableProxy fail: \(port) \(socksPort)", level: .error)
            return
        }
        Logger.log("enableProxy", level: .debug)
        helper()?.enableProxy(withPort: Int32(port), socksPort: Int32(socksPort), authData: authData(), error: { error in
            if let error = error {
                Logger.log("enableProxy \(error)", level: .error)
            }
        })
    }

    func disableProxy() {
        let port = ConfigManager.shared.currentConfig?.port ?? 0
        let socketPort = ConfigManager.shared.currentConfig?.socketPort ?? 0
        SystemProxyManager.shared.disableProxy(port: port, socksPort: socketPort)
    }

    func disableProxy(port: Int, socksPort: Int, forceDisable: Bool = false) {
        Logger.log("disableProxy", level: .debug)

        if disableRestoreProxy || forceDisable {
            helper()?.disableProxy(withAuthData: authData(), error: { error in
                if let error = error {
                    Logger.log("disableProxy \(error)", level: .error)
                }
            })
            return
        }

        helper()?.restoreProxy(withCurrentPort: Int32(port), socksPort: Int32(socksPort), info: savedProxyInfo, authData: authData(), error: { error in
            if let error = error {
                Logger.log("restoreProxy \(error)", level: .error)
            }
        })
    }

    // MARK: - Expriment Menu Items

    func addDisableRestoreProxyMenuItem(_ menu: inout NSMenu) {
        let item = NSMenuItem(title: NSLocalizedString("Disable Restore Proxy Setting", comment: ""), action: #selector(optionMenuItemTap(sender:)), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        updateMenuItemStatus(item)
    }

    func updateMenuItemStatus(_ item: NSMenuItem) {
        item.state = disableRestoreProxy ? .on : .off
    }

    @objc func optionMenuItemTap(sender: NSMenuItem) {
        disableRestoreProxy = !disableRestoreProxy
        updateMenuItemStatus(sender)
    }

    // MARK: - Private

    private func initAuthorizationRef() {
        // Create an empty AuthorizationRef
        let status = AuthorizationCreate(nil, nil, AuthorizationFlags(), &authRef)
        if status != OSStatus(errAuthorizationSuccess) {
            Logger.log("initAuthorizationRef AuthorizationCreate failed", level: .error)
            return
        }
    }

    /// Install new helper daemon
    private func installHelperDaemon() -> DaemonInstallResult {
        Logger.log("installHelperDaemon", level: .info)

        defer {
            connection?.invalidate()
            connection = nil
            _helper = nil
        }

        // Create authorization reference for the user
        var authRef: AuthorizationRef?
        var authStatus = AuthorizationCreate(nil, nil, [], &authRef)

        // Check if the reference is valid
        guard authStatus == errAuthorizationSuccess else {
            Logger.log("Authorization failed: \(authStatus)", level: .error)
            return .authorizationFail
        }

        // Ask user for the admin privileges to install the
        var authItem = AuthorizationItem(name: kSMRightBlessPrivilegedHelper, valueLength: 0, value: nil, flags: 0)
        var authRights = AuthorizationRights(count: 1, items: &authItem)
        let flags: AuthorizationFlags = [[], .interactionAllowed, .extendRights, .preAuthorize]
        authStatus = AuthorizationCreate(&authRights, nil, flags, &authRef)
        defer {
            if let ref = authRef {
                AuthorizationFree(ref, [])
            }
        }
        // Check if the authorization went succesfully
        guard authStatus == errAuthorizationSuccess else {
            Logger.log("Couldn't obtain admin privileges: \(authStatus)", level: .error)
            return .getAdmainFail
        }

        // Launch the privileged helper using SMJobBless tool
        var error: Unmanaged<CFError>?

        if SMJobBless(kSMDomainSystemLaunchd, SystemProxyManager.machServiceName as CFString, authRef, &error) == false {
            let blessError = error!.takeRetainedValue() as Error
            Logger.log("Bless Error: \(blessError)", level: .error)
            return .blessError((blessError as NSError).code)
        }

        Logger.log("\(SystemProxyManager.machServiceName) installed successfully", level: .info)
        return .success
    }

    private func authData() -> Data? {
        guard let authRef = authRef else { return nil }
        var authRefExtForm = AuthorizationExternalForm()

        // Make an external form of the AuthorizationRef
        var status = AuthorizationMakeExternalForm(authRef, &authRefExtForm)
        if status != OSStatus(errAuthorizationSuccess) {
            Logger.log("AppviewController: AuthorizationMakeExternalForm failed", level: .error)
            return nil
        }

        // Add all or update required authorization right definition to the authorization database
        var currentRight: CFDictionary?

        // Try to get the authorization right definition from the database
        status = AuthorizationRightGet(AppAuthorizationRights.rightName.utf8String!, &currentRight)

        if status == errAuthorizationDenied {
            let defaultRules = AppAuthorizationRights.rightDefaultRule
            status = AuthorizationRightSet(authRef,
                                           AppAuthorizationRights.rightName.utf8String!,
                                           defaultRules as CFDictionary,
                                           AppAuthorizationRights.rightDescription,
                                           nil, "Common" as CFString)
        }

        // We need to put the AuthorizationRef to a form that can be passed through inter process call
        let authData = NSData(bytes: &authRefExtForm, length: kAuthorizationExternalFormLength)
        return authData as Data
    }

    private func helperConnection() -> NSXPCConnection? {
        // Check that the connection is valid before trying to do an inter process call to helper
        if connection == nil {
            connection = NSXPCConnection(machServiceName: SystemProxyManager.machServiceName, options: NSXPCConnection.Options.privileged)
            connection?.remoteObjectInterface = NSXPCInterface(with: ProxyConfigRemoteProcessProtocol.self)
            connection?.invalidationHandler = {
                [weak self] in
                guard let self = self else { return }
                self.connection?.invalidationHandler = nil
                OperationQueue.main.addOperation {
                    self.connection = nil
                    self._helper = nil
                    Logger.log("XPC Connection Invalidated")
                }
            }
            connection?.resume()
        }
        return connection
    }

    private func helper(failture: (() -> Void)? = nil) -> ProxyConfigRemoteProcessProtocol? {
        if _helper == nil {
            guard let newHelper = helperConnection()?.remoteObjectProxyWithErrorHandler({ error in
                Logger.log("Helper connection was closed with error: \(error)")
                failture?()
            }) as? ProxyConfigRemoteProcessProtocol else { return nil }
            _helper = newHelper
        }
        return _helper
    }

    private func helperStatus() -> Bool {
        let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchServices/" + SystemProxyManager.machServiceName)
        guard
            let helperBundleInfo = CFBundleCopyInfoDictionaryForURL(helperURL as CFURL) as? [String: Any],
            let helperVersion = helperBundleInfo["CFBundleShortVersionString"] as? String,
            let helper = self.helper() else {
            return false
        }
        let helperFileExists = FileManager.default.fileExists(atPath: "/Library/PrivilegedHelperTools/com.west2online.ClashX.ProxyConfigHelper")
        let timeout: TimeInterval = helperFileExists ? 15 : 2
        var installed = false
        let time = Date()
        let semaphore = DispatchSemaphore(value: 0)
        helper.getVersion { installedHelperVersion in
            Logger.log("helper version \(installedHelperVersion ?? "") require version \(helperVersion)", level: .debug)
            installed = installedHelperVersion == helperVersion
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: DispatchTime.now() + timeout)
        let interval = Date().timeIntervalSince(time)
        Logger.log("check helper using time: \(interval)")
        return installed
    }
}

extension SystemProxyManager {
    private func notifyInstall() {
        guard showInstallHelperAlert() else { exit(0) }

        if cancelInstallCheck {
            return
        }

        let result = installHelperDaemon()
        if case .success = result {
            return
        }
        result.alertAction()
        NSAlert.alert(with: result.alertContent)
    }

    private func showInstallHelperAlert() -> Bool {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("ClashX needs to install a helper tool with administrator privileges to set system proxy quickly.If not helper tool installed, ClashX won't be able to set your system proxy", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Install", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Quit", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return true
        case .alertThirdButtonReturn:
            cancelInstallCheck = true
            Logger.log("cancelInstallCheck = true", level: .error)
            return true
        default:
            return false
        }
    }
}

fileprivate struct AppAuthorizationRights {
    static let rightName: NSString = "com.west2online.ClashX.ProxyConfigHelper.config"
    static let rightDefaultRule: Dictionary = adminRightsRule
    static let rightDescription: CFString = "ProxyConfigHelper wants to configure your proxy setting'" as CFString
    static var adminRightsRule: [String: Any] = ["class": "user",
                                                 "group": "admin",
                                                 "timeout": 0,
                                                 "version": 1]
}

fileprivate enum DaemonInstallResult {
    case success
    case authorizationFail
    case getAdmainFail
    case blessError(Int)

    var alertContent: String {
        switch self {
        case .success:
            return ""
        case .authorizationFail: return "Create authorization fail!"
        case .getAdmainFail: return "Get admain authorization fail!"
        case let .blessError(code):
            switch code {
            case kSMErrorInternalFailure: return "blessError: kSMErrorInternalFailure"
            case kSMErrorInvalidSignature: return "blessError: kSMErrorInvalidSignature"
            case kSMErrorAuthorizationFailure: return "blessError: kSMErrorAuthorizationFailure"
            case kSMErrorToolNotValid: return "blessError: kSMErrorToolNotValid"
            case kSMErrorJobNotFound: return "blessError: kSMErrorJobNotFound"
            case kSMErrorServiceUnavailable: return "blessError: kSMErrorServiceUnavailable"
            case kSMErrorJobNotFound: return "blessError: kSMErrorJobNotFound"
            case kSMErrorJobMustBeEnabled: return "ClashX Helper is disabled by other process. Please run \"sudo launchctl enable system/com.west2online.ClashX.ProxyConfigHelper\" in your terminal. The command has been copied to your pasteboard"
            case kSMErrorInvalidPlist: return "blessError: kSMErrorInvalidPlist"
            default:
                return "bless unknown error:\(code)"
            }
        }
    }

    func alertAction() {
        switch self {
        case let .blessError(code):
            switch code {
            case kSMErrorJobMustBeEnabled:
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("sudo launchctl enable system/com.west2online.ClashX.ProxyConfigHelper", forType: .string)
            default:
                break
            }
        default:
            break
        }
    }
}
