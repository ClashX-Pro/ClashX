//
//  AppDelegate.swift
//  ClashX
//
//  Created by CYC on 2018/6/10.
//  Copyright © 2018年 yichengchen. All rights reserved.
//

import Alamofire
import AppCenter
import AppCenterAnalytics
import AppCenterCrashes
import Cocoa
import CocoaLumberjack
import LetsMove
import RxCocoa
import RxSwift

let statusItemLengthWithSpeed: CGFloat = 72

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var statusItem: NSStatusItem!
    @IBOutlet var checkForUpdateMenuItem: NSMenuItem!

    @IBOutlet var statusMenu: NSMenu!
    @IBOutlet var proxySettingMenuItem: NSMenuItem!
    @IBOutlet var autoStartMenuItem: NSMenuItem!

    @IBOutlet var proxyModeGlobalMenuItem: NSMenuItem!
    @IBOutlet var proxyModeDirectMenuItem: NSMenuItem!
    @IBOutlet var proxyModeRuleMenuItem: NSMenuItem!
    @IBOutlet var allowFromLanMenuItem: NSMenuItem!
    @IBOutlet var enhancedModeMenuItem: NSMenuItem!

    @IBOutlet var proxyModeMenuItem: NSMenuItem!
    @IBOutlet var showNetSpeedIndicatorMenuItem: NSMenuItem!
    @IBOutlet var dashboardMenuItem: NSMenuItem!
    @IBOutlet var separatorLineTop: NSMenuItem!
    @IBOutlet var sepatatorLineEndProxySelect: NSMenuItem!
    @IBOutlet var configSeparatorLine: NSMenuItem!
    @IBOutlet var logLevelMenuItem: NSMenuItem!
    @IBOutlet var httpPortMenuItem: NSMenuItem!
    @IBOutlet var socksPortMenuItem: NSMenuItem!
    @IBOutlet var apiPortMenuItem: NSMenuItem!
    @IBOutlet var ipMenuItem: NSMenuItem!
    @IBOutlet var remoteConfigAutoupdateMenuItem: NSMenuItem!
    @IBOutlet var copyExportCommandMenuItem: NSMenuItem!
    @IBOutlet var copyExportCommandExternalMenuItem: NSMenuItem!
    @IBOutlet var externalControlSeparator: NSMenuItem!
    @IBOutlet var connectionsMenuItem: NSMenuItem!

    var disposeBag = DisposeBag()
    var statusItemView: StatusItemViewProtocol!
    var isSpeedTesting = false

    var runAfterConfigReload: (() -> Void)?

    private var lastStreamResetTime: Date = .distantPast
    private var pendingStreamResetWork: DispatchWorkItem?

    func applicationWillFinishLaunching(_ notification: Notification) {
        Logger.log("applicationWillFinishLaunching")
        signal(SIGPIPE, SIG_IGN)
        // crash recorder
        failLaunchProtect()
        NSAppleEventManager.shared()
            .setEventHandler(self,
                             andSelector: #selector(handleURL(event:reply:)),
                             forEventClass: AEEventClass(kInternetEventClass),
                             andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.log("applicationDidFinishLaunching")
        Logger.log("Appversion: \(AppVersionUtil.currentVersion) \(AppVersionUtil.currentBuild)")
        ProcessInfo.processInfo.disableSuddenTermination()
        // setup menu item first
        statusItem = NSStatusBar.system.statusItem(withLength: statusItemLengthWithSpeed)
        statusItemView = StatusItemView.create(statusItem: statusItem)
        statusItemView.updateSize(width: statusItemLengthWithSpeed)
        statusMenu.delegate = self
        setupStatusMenuItemData()
        DispatchQueue.main.async {
            self.postFinishLaunching()
        }
    }

    func postFinishLaunching() {
        Logger.log("postFinishLaunching")
        defer {
            statusItem.menu = statusMenu
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                self.checkMenuIconVisable()
            }
        }
        if #unavailable(macOS 10.15) {
            // dashboard is not support in macOS 10.15 below
            dashboardMenuItem.isHidden = true
            connectionsMenuItem.isHidden = true
        }
        AppVersionUtil.showUpgradeAlert()
        ICloudManager.shared.setup()

        if WebPortalManager.hasWebProtal {
            WebPortalManager.shared.addWebProtalMenuItem(&statusMenu)
        }
        setupLanguageMenu()
        // 启用自动更新检查（使用fork项目的GitHub Pages）
        AutoUpgardeManager.shared.setup()
        AutoUpgardeManager.shared.setupCheckForUpdatesMenuItem(checkForUpdateMenuItem)
        // install proxy helper
        _ = ClashResourceManager.check()
        PrivilegedHelperManager.shared.checkInstall()
        ConfigFileManager.copySampleConfigIfNeed()

        PFMoveToApplicationsFolderIfNecessary()

        // claer not existed selected model
        removeUnExistProxyGroups()

        // clash logger
        if ApiRequest.useDirectApi() {
            Logger.log("setup built in logger/traffic")
            clash_setLogBlock { line, level in
                let clashLevel = ClashLogLevel(rawValue: level ?? "info")
                Logger.log(line ?? "", level: clashLevel ?? .info, function: "")
            }
            clashSetupLogger()

            clash_setTrafficBlock { [weak self] up, down in
                if RemoteControlManager.selectConfig == nil,
                   ConfigManager.shared.isEnhancedModeActive == false {
                    DispatchQueue.main.async {
                        self?.didUpdateTraffic(up: Int(up), down: Int(down))
                    }
                }
            }
            clashSetupTraffic()

        } else {
            Logger.log("do not setup built in logger/traffic, useDirectApi = false")
        }
        // start proxy
        Logger.log("initClashCore")
        initClashCore()
        Logger.log("initClashCore finish")
        setupData()
        runAfterConfigReload = { [weak self] in
            if !Settings.builtInApiMode {
                self?.selectAllowLanWithMenory()
            }
        }
        updateConfig(showNotification: false)
        updateLoggingLevel()
        restoreEnhancedModeIfNeeded()

        // start watch config file change
        ConfigManager.watchCurrentConfigFile()

        RemoteConfigManager.shared.autoUpdateCheck()

        setupNetworkNotifier()
        registCrashLogger()
        KeyboardShortCutManager.setup()
        RemoteControlManager.setupMenuItem(separator: externalControlSeparator)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return TerminalConfirmAction.run()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        UserDefaults.standard.set(0, forKey: "launch_fail_times")
        Logger.log("ClashFX will terminate")
        if ConfigManager.shared.isEnhancedModeActive {
            PrivilegedHelperManager.shared.helper()?.stopMihomoCore { _ in }
        }
        if NetworkChangeNotifier.isCurrentSystemSetToClash(looser: true) ||
            NetworkChangeNotifier.hasInterfaceProxySetToClash() {
            Logger.log("Need Reset Proxy Setting again", level: .error)
            SystemProxyManager.shared.disableProxy()
        }
    }

    func checkMenuIconVisable() {
        guard let button = statusItem.button else { assertionFailure(); return }
        guard let window = button.window else { assertionFailure(); return }
        let buttonRect = button.convert(button.bounds, to: nil)
        let onScreenRect = window.convertToScreen(buttonRect)
        var leftScreenX: CGFloat = 0
        for screen in NSScreen.screens where screen.frame.origin.x < leftScreenX {
            leftScreenX = screen.frame.origin.x
        }
        let isMenuIconHidden = onScreenRect.midX < leftScreenX

        var isCoverdByNotch = false
        if #available(macOS 12, *), NSScreen.screens.count == 1, let screen = NSScreen.screens.first {
            // 修复 macOS 15+ 兼容性：添加额外的安全检查
            // auxiliaryTopLeftArea 和 auxiliaryTopRightArea 在某些情况下可能为 nil
            if let leftArea = screen.auxiliaryTopLeftArea, let rightArea = screen.auxiliaryTopRightArea {
                // 添加额外的尺寸验证，避免无效的 CGRect 导致崩溃
                if leftArea.width > 0 && rightArea.width > 0 && leftArea.maxX < rightArea.minX {
                    if onScreenRect.minX > leftArea.maxX, onScreenRect.maxX < rightArea.minX {
                        isCoverdByNotch = true
                    }
                }
            }
        }

        Logger.log("checkMenuIconVisable: \(onScreenRect) \(leftScreenX), hidden: \(isMenuIconHidden), coverd by notch:\(isCoverdByNotch)")

        if isMenuIconHidden || isCoverdByNotch, !Settings.disableMenubarNotice {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("The status icon is coverd or hide by other app.", comment: "")
            alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Never show again", comment: ""))
            if alert.runModal() == .alertSecondButtonReturn {
                Settings.disableMenubarNotice = true
            }
        }
    }

    func setupStatusMenuItemData() {
        ConfigManager.shared
            .showNetSpeedIndicatorObservable
            .bind { [weak self] show in
                guard let self = self else { return }
                self.showNetSpeedIndicatorMenuItem.state = (show ?? true) ? .on : .off
                let statusItemLength: CGFloat = (show ?? true) ? statusItemLengthWithSpeed : 25
                self.statusItem.length = statusItemLength
                self.statusItemView.updateSize(width: statusItemLength)
                self.statusItemView.showSpeedContainer(show: show ?? true)
            }.disposed(by: disposeBag)

        statusItemView.updateViewStatus(enableProxy: ConfigManager.shared.proxyPortAutoSet)
        enhancedModeMenuItem.state = Settings.enhancedMode ? .on : .off
    }

    func setupData() {
        SSIDSuspendTool.shared.setup()
        ConfigManager.shared
            .showNetSpeedIndicatorObservable.skip(1)
            .bind {
                _ in
                ApiRequest.shared.resetTrafficStreamApi()
            }.disposed(by: disposeBag)

        Observable
            .merge([ConfigManager.shared.proxyPortAutoSetObservable,
                    ConfigManager.shared.isProxySetByOtherVariable.asObservable(),
                    ConfigManager.shared.proxyShouldPaused.asObservable()])
            .observe(on: MainScheduler.instance)
            .map { _ -> NSControl.StateValue in
                if (ConfigManager.shared.isProxySetByOtherVariable.value || ConfigManager.shared.proxyShouldPaused.value) && ConfigManager.shared.proxyPortAutoSet {
                    return .mixed
                }
                return ConfigManager.shared.proxyPortAutoSet ? .on : .off
            }.distinctUntilChanged()
            .bind { [weak self] status in
                guard let self = self else { return }
                self.proxySettingMenuItem.state = status
                self.statusItemView.updateViewStatus(enableProxy: status == .on)
            }.disposed(by: disposeBag)

        let configObservable = ConfigManager.shared
            .currentConfigVariable
            .asObservable()
        Observable.zip(configObservable, configObservable.skip(1))
            .filter { _, new in return new != nil }
            .observe(on: MainScheduler.instance)
            .bind { [weak self] old, config in
                guard let self = self, let config = config else { return }
                self.proxyModeDirectMenuItem.state = .off
                self.proxyModeGlobalMenuItem.state = .off
                self.proxyModeRuleMenuItem.state = .off

                switch config.mode {
                case .direct: self.proxyModeDirectMenuItem.state = .on
                case .global: self.proxyModeGlobalMenuItem.state = .on
                case .rule: self.proxyModeRuleMenuItem.state = .on
                }
                self.allowFromLanMenuItem.state = config.allowLan ? .on : .off

                self.proxyModeMenuItem.title = "\(NSLocalizedString("Proxy Mode", comment: "")) (\(config.mode.name))"

                if old?.usedHttpPort != config.usedHttpPort || old?.usedSocksPort != config.usedSocksPort {
                    Logger.log("port config updated,new: \(config.usedHttpPort),\(config.usedSocksPort)")
                    if ConfigManager.shared.proxyPortAutoSet {
                        SystemProxyManager.shared.enableProxy(port: config.usedHttpPort, socksPort: config.usedSocksPort)
                    }
                }

                self.httpPortMenuItem.title = "Http Port: \(config.usedHttpPort)"
                self.socksPortMenuItem.title = "Socks Port: \(config.usedSocksPort)"
                self.apiPortMenuItem.title = "Api Port: \(ConfigManager.shared.apiPort)"
                self.ipMenuItem.title = "IP: \(NetworkChangeNotifier.getPrimaryIPAddress() ?? "")"

                if RemoteControlManager.selectConfig == nil {
                    ClashStatusTool.checkPortConfig(cfg: config)
                }

            }.disposed(by: disposeBag)

        if !PrivilegedHelperManager.shared.isHelperCheckFinished.value &&
            ConfigManager.shared.proxyPortAutoSet {
            PrivilegedHelperManager.shared.isHelperCheckFinished
                .filter { $0 }
                .take(1)
                .take(while: { _ in ConfigManager.shared.proxyPortAutoSet })
                .observe(on: MainScheduler.instance)
                .bind(onNext: { _ in
                    SystemProxyManager.shared.enableProxy()
                }).disposed(by: disposeBag)
        } else if ConfigManager.shared.proxyPortAutoSet {
            SystemProxyManager.shared.enableProxy()
        }

        LaunchAtLogin.shared
            .isEnableVirable
            .asObservable()
            .subscribe(onNext: { [weak self] enable in
                guard let self = self else { return }
                self.autoStartMenuItem.state = enable ? .on : .off
            }).disposed(by: disposeBag)

        remoteConfigAutoupdateMenuItem.state = RemoteConfigManager.autoUpdateEnable ? .on : .off

        if !PrivilegedHelperManager.shared.isHelperCheckFinished.value {
            proxySettingMenuItem.target = nil
            PrivilegedHelperManager.shared.isHelperCheckFinished
                .filter { $0 }
                .take(1)
                .observe(on: MainScheduler.instance)
                .subscribe { [weak self] _ in
                    guard let self = self else { return }
                    self.proxySettingMenuItem.target = self
                }.disposed(by: disposeBag)
        }
    }

    func setupNetworkNotifier() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            NetworkChangeNotifier.start()
        }

        NotificationCenter
            .default
            .rx
            .notification(.systemNetworkStatusDidChange)
            .observe(on: MainScheduler.instance)
            .delay(.milliseconds(200), scheduler: MainScheduler.instance)
            .bind { _ in
                guard NetworkChangeNotifier.getPrimaryInterface() != nil else { return }
                let proxySetted = NetworkChangeNotifier.isCurrentSystemSetToClash()
                ConfigManager.shared.isProxySetByOtherVariable.accept(!proxySetted)
                if !proxySetted && ConfigManager.shared.proxyPortAutoSet {
                    let proxiesSetting = NetworkChangeNotifier.getRawProxySetting()
                    Logger.log("Proxy changed by other process!, current:\(proxiesSetting), is Interface Set: \(NetworkChangeNotifier.hasInterfaceProxySetToClash())", level: .warning)
                }
            }.disposed(by: disposeBag)

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(resetProxySettingOnWakeupFromSleep),
            name: NSWorkspace.didWakeNotification, object: nil
        )

        NotificationCenter
            .default
            .rx
            .notification(.systemNetworkStatusIPUpdate).map { _ in
                NetworkChangeNotifier.getPrimaryIPAddress(allowIPV6: false)
            }
            .startWith(NetworkChangeNotifier.getPrimaryIPAddress(allowIPV6: false))
            .distinctUntilChanged()
            .skip(1)
            .filter { $0 != nil }
            .observe(on: MainScheduler.instance)
            .debounce(.seconds(5), scheduler: MainScheduler.instance).bind { [weak self] _ in
                self?.healthCheckOnNetworkChange()
            }.disposed(by: disposeBag)

        ConfigManager.shared
            .isProxySetByOtherVariable
            .asObservable()
            .filter { _ in ConfigManager.shared.proxyPortAutoSet }
            .distinctUntilChanged()
            .filter { $0 }
            .filter { _ in !ConfigManager.shared.proxyShouldPaused.value }
            .bind { _ in
                let rawProxy = NetworkChangeNotifier.getRawProxySetting()
                Logger.log("proxy changed to no clashX setting: \(rawProxy)", level: .warning)
                NSUserNotificationCenter.default.postProxyChangeByOtherAppNotice()
            }.disposed(by: disposeBag)

        NotificationCenter
            .default
            .rx
            .notification(.systemNetworkStatusIPUpdate).map { _ in
                NetworkChangeNotifier.getPrimaryIPAddress(allowIPV6: false)
            }.bind { [weak self] _ in
                if RemoteControlManager.selectConfig != nil {
                    self?.resetStreamApi()
                }
            }.disposed(by: disposeBag)
    }

    func updateProxyList(withMenus menus: [NSMenuItem]) {
        let startIndex = statusMenu.items.firstIndex(of: separatorLineTop)! + 1
        let endIndex = statusMenu.items.firstIndex(of: sepatatorLineEndProxySelect)!
        sepatatorLineEndProxySelect.isHidden = menus.isEmpty
        for _ in 0 ..< endIndex - startIndex {
            statusMenu.removeItem(at: startIndex)
        }
        for each in menus {
            statusMenu.insertItem(each, at: startIndex)
        }
    }

    func updateConfigFiles() {
        guard let menu = configSeparatorLine.menu else { return }
        MenuItemFactory.generateSwitchConfigMenuItems {
            items in
            let lineIndex = menu.items.firstIndex(of: self.configSeparatorLine)!
            for _ in 0 ..< lineIndex {
                menu.removeItem(at: 0)
            }
            for item in items.reversed() {
                menu.insertItem(item, at: 0)
            }
        }
    }

    func updateLoggingLevel() {
        ApiRequest.updateLogLevel(level: ConfigManager.selectLoggingApiLevel)
        for item in logLevelMenuItem.submenu?.items ?? [] {
            item.state = item.title.lowercased() == ConfigManager.selectLoggingApiLevel.rawValue ? .on : .off
        }
        NotificationCenter.default.post(name: .reloadDashboard, object: nil)
    }

    func startProxy() {
        if ConfigManager.shared.isRunning { return }

        if !Settings.isApiSecretSet {
            if #available(macOS 11.0, *), let password = SecCreateSharedWebCredentialPassword() as? String {
                Settings.apiSecret = password
            } else {
                Settings.apiSecret = UUID().uuidString
            }
        }

        if clash_checkSecret().toString().isEmpty || Settings.overrideConfigSecret {
            clash_setSecret(Settings.apiSecret.goStringBuffer())
        }

        struct StartProxyResp: Codable {
            let externalController: String
            let secret: String
        }

        // setup ui config first
        if let htmlPath = Bundle.main.path(forResource: "index", ofType: "html", inDirectory: "dashboard") {
            let uiPath = URL(fileURLWithPath: htmlPath).deletingLastPathComponent().path
            setUIPath(uiPath.goStringBuffer())
        }

        Logger.log("Trying start proxy, build-in mode: \(Settings.builtInApiMode), allow lan: \(ConfigManager.allowConnectFromLan) custom port: \(Settings.proxyPort)")

        var apiAddr = ""
        if Settings.apiPort > 0 {
            if Settings.apiPortAllowLan {
                apiAddr = "0.0.0.0:\(Settings.apiPort)"
            } else {
                apiAddr = "127.0.0.1:\(Settings.apiPort)"
            }
        }
        let startRes = run(Settings.builtInApiMode.goObject(),
                           ConfigManager.allowConnectFromLan.goObject(),
                           Settings.enableIPV6.goObject(),
                           GoUint32(Settings.proxyPort),
                           apiAddr.goStringBuffer())?
            .toString() ?? ""
        let jsonData = startRes.data(using: .utf8) ?? Data()
        if let res = try? JSONDecoder().decode(StartProxyResp.self, from: jsonData) {
            let port = res.externalController.components(separatedBy: ":").last ?? "9090"
            ConfigManager.shared.allowExternalControl = !res.externalController.contains("127.0.0.1") && !res.externalController.contains("localhost")
            ConfigManager.shared.apiPort = port
            ConfigManager.shared.apiSecret = res.secret
            ConfigManager.shared.isRunning = true
            proxyModeMenuItem.isEnabled = true
            dashboardMenuItem.isEnabled = true
        } else {
            ConfigManager.shared.isRunning = false
            proxyModeMenuItem.isEnabled = false
            Logger.log(startRes, level: .error)
            NSUserNotificationCenter.default.postConfigErrorNotice(msg: startRes)
        }
        Logger.log("Start proxy done")
    }

    func syncConfig(completeHandler: (() -> Void)? = nil) {
        ApiRequest.requestConfig { config in
            ConfigManager.shared.currentConfig = config
            completeHandler?()
        }
    }

    func resetStreamApi() {
        let now = Date()
        let minInterval: TimeInterval = 0.5
        pendingStreamResetWork?.cancel()

        let elapsed = now.timeIntervalSince(lastStreamResetTime)
        if elapsed >= minInterval {
            lastStreamResetTime = now
            ApiRequest.shared.delegate = self
            ApiRequest.shared.resetStreamApis()
        } else {
            let work = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.lastStreamResetTime = Date()
                ApiRequest.shared.delegate = self
                ApiRequest.shared.resetStreamApis()
            }
            pendingStreamResetWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + (minInterval - elapsed), execute: work)
        }
    }

    func updateConfig(configName: String? = nil, showNotification: Bool = true, completeHandler: ((ErrorString?) -> Void)? = nil) {
        startProxy()
        guard ConfigManager.shared.isRunning else { return }

        let config = configName ?? ConfigManager.selectConfigName

        ClashProxy.cleanCache()

        ApiRequest.requestConfigUpdate(configName: config) {
            [weak self] err in
            guard let self = self else { return }

            defer {
                completeHandler?(err)
            }

            if let err {
                UpdateConfigAction.showError(text: err, configName: config)
            } else {
                self.syncConfig()
                self.resetStreamApi()
                self.runAfterConfigReload?()
                self.runAfterConfigReload = nil
                if showNotification {
                    NSUserNotificationCenter.default
                        .post(title: NSLocalizedString("Reload Config Succeed", comment: ""),
                              info: NSLocalizedString("Success", comment: ""))
                }

                if let newConfigName = configName {
                    ConfigManager.selectConfigName = newConfigName
                }
                self.selectProxyGroupWithMemory()
                self.selectOutBoundModeWithMenory()
                MenuItemFactory.recreateProxyMenuItems()
                NotificationCenter.default.post(name: .reloadDashboard, object: nil)
            }
        }
    }

    @objc func resetProxySettingOnWakeupFromSleep() {
        guard !ConfigManager.shared.isProxySetByOtherVariable.value,
              ConfigManager.shared.proxyPortAutoSet else { return }
        guard NetworkChangeNotifier.getPrimaryInterface() != nil else { return }
        if !NetworkChangeNotifier.isCurrentSystemSetToClash() {
            let rawProxy = NetworkChangeNotifier.getRawProxySetting()
            Logger.log("Resting proxy setting, current:\(rawProxy)", level: .warning)
            SystemProxyManager.shared.disableProxy()
            SystemProxyManager.shared.enableProxy()
        }

        if RemoteControlManager.selectConfig != nil {
            resetStreamApi()
        }
    }

    @objc func healthCheckOnNetworkChange() {
        ApiRequest.getMergedProxyData {
            proxyResp in
            guard let proxyResp = proxyResp else { return }

            var providers = Set<ClashProxyName>()

            let groups = proxyResp.proxyGroups.filter(\.type.isAutoGroup)
            for group in groups {
                group.all?.compactMap {
                    proxyResp.proxiesMap[$0]?.enclosingProvider?.name
                }.forEach {
                    providers.insert($0)
                }
            }

            for group in groups {
                Logger.log("Start auto health check for group \(group.name)")
                ApiRequest.healthCheck(proxy: group.name)
            }

            for provider in providers {
                Logger.log("Start auto health check for provider \(provider)")
                ApiRequest.healthCheck(proxy: provider)
            }
        }
    }
}

// MARK: Main actions

extension AppDelegate {
    @IBAction func actionDashboard(_ sender: NSMenuItem?) {
        ClashWindowController<ClashWebViewContoller>.create().showWindow(sender)
    }

    @IBAction func actionConnections(_ sender: NSMenuItem?) {
        if #available(macOS 10.15, *) {
            ClashWindowController<DashboardViewController>.create().showWindow(sender)
        }
    }

    @IBAction func actionToggleEnhancedMode(_ sender: NSMenuItem) {
        let newState = !Settings.enhancedMode
        guard ConfigManager.shared.isRunning else { return }
        enhancedModeMenuItem.isEnabled = false

        let completion: (String?) -> Void = { [weak self] error in
            guard let self = self else { return }
            self.enhancedModeMenuItem.isEnabled = true
            if let error = error {
                Settings.enhancedMode = !newState
                self.enhancedModeMenuItem.state = !newState ? .on : .off
                Logger.log("Enhanced Mode toggle failed: \(error)", level: .error)
                NSUserNotificationCenter.default.postConfigErrorNotice(msg: error)
            } else {
                Settings.enhancedMode = newState
                self.enhancedModeMenuItem.state = newState ? .on : .off
                Logger.log("Enhanced Mode \(newState ? "enabled" : "disabled")")
                let info = newState ? "Enhanced Mode Enabled" : "Enhanced Mode Disabled"
                NSUserNotificationCenter.default
                    .post(title: NSLocalizedString("Enhanced Mode", comment: ""),
                          info: NSLocalizedString(info, comment: ""))
            }
            self.syncConfig()
            MenuItemFactory.recreateProxyMenuItems()
            self.resetStreamApi()
        }

        if newState {
            enableEnhancedMode(completion: completion)
        } else {
            disableEnhancedMode(completion: completion)
        }
    }

    private func enableEnhancedMode(completion: @escaping (String?) -> Void) {
        let tempConfigPath = kConfigFolderPath + ".enhanced_config.yaml"
        let selectedConfigPath = Paths.localConfigPath(for: ConfigManager.selectConfigName)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let writeResult = clashWriteEnhancedConfig(
                selectedConfigPath.goStringBuffer(),
                tempConfigPath.goStringBuffer()
            )?.toString() ?? ""

            DispatchQueue.main.async {
                guard let self = self else { return }

                guard !writeResult.hasPrefix("error:") else {
                    completion(writeResult)
                    return
                }

                guard let jsonData = writeResult.data(using: .utf8),
                      let portInfo = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String],
                      let extController = portInfo["externalController"],
                      let port = extController.components(separatedBy: ":").last else {
                    completion(NSLocalizedString("Failed to parse enhanced config", comment: ""))
                    return
                }
                let secret = portInfo["secret"] ?? ""

                guard let binaryPath = Bundle.main.path(forResource: "mihomo_core", ofType: nil) else {
                    completion(NSLocalizedString("mihomo_core not found", comment: ""))
                    return
                }

                guard let helper = PrivilegedHelperManager.shared.helper() else {
                    completion(NSLocalizedString("Helper not available", comment: ""))
                    return
                }

                clashSuspendCore()

                helper.startMihomoCore(
                    withBinaryPath: binaryPath,
                    configPath: tempConfigPath,
                    homeDir: kConfigFolderPath
                ) { [weak self] error in
                    DispatchQueue.main.async {
                        if let error = error {
                            _ = clashResumeCore()
                            completion(error)
                        } else {
                            ConfigManager.shared.apiPort = port
                            ConfigManager.shared.apiSecret = secret
                            ConfigManager.shared.isEnhancedModeActive = true
                            self?.waitForExternalCore(port: port, secret: secret, retriesLeft: 10) { success in
                                if success {
                                    self?.verifyTunStatus(port: port, secret: secret)
                                    completion(nil)
                                } else {
                                    Logger.log("External core failed to start, rolling back", level: .error)
                                    helper.stopMihomoCore { _ in
                                        DispatchQueue.main.async {
                                            ConfigManager.shared.isEnhancedModeActive = false
                                            ConfigManager.shared.isRunning = false
                                            clashReopenCacheDB()
                                            self?.startProxy()
                                            completion(NSLocalizedString("Enhanced Mode failed: core not responding", comment: ""))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func waitForExternalCore(port: String, secret: String, retriesLeft: Int, ready: @escaping (Bool) -> Void) {
        let url = URL(string: "http://127.0.0.1:\(port)/configs")!
        var request = URLRequest(url: url, timeoutInterval: 2)
        if !secret.isEmpty {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    Logger.log("External core API ready on port \(port)")
                    ready(true)
                } else if retriesLeft > 0 {
                    Logger.log("Waiting for external core (\(retriesLeft) retries left)...", level: .debug)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.waitForExternalCore(port: port, secret: secret, retriesLeft: retriesLeft - 1, ready: ready)
                    }
                } else {
                    Logger.log("External core API not responding after all retries", level: .error)
                    ready(false)
                }
            }
        }.resume()
    }

    private func disableEnhancedMode(completion: @escaping (String?) -> Void) {
        PrivilegedHelperManager.shared.helper()?.stopMihomoCore { [weak self] _ in
            DispatchQueue.main.async {
                ConfigManager.shared.isEnhancedModeActive = false
                ConfigManager.shared.isRunning = false
                clashReopenCacheDB()
                self?.startProxy()
                guard ConfigManager.shared.isRunning else {
                    completion(NSLocalizedString("Failed to restart built-in core", comment: ""))
                    return
                }
                let selectedConfig = ConfigManager.selectConfigName
                ApiRequest.requestConfigUpdate(configName: selectedConfig) { _ in
                    completion(nil)
                }
            }
        }
    }

    private func verifyTunStatus(port: String, secret: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.checkTunInterface()
            self.queryTunFromApi(port: port, secret: secret)
        }
    }

    private func checkTunInterface() {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else { return }
        defer { freeifaddrs(ifaddrPtr) }

        var tunInterfaces: [(name: String, hasIPv4: Bool, ipv4: String)] = []
        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = ptr {
            let name = String(cString: addr.pointee.ifa_name)
            if name.hasPrefix("utun") {
                let family = addr.pointee.ifa_addr.pointee.sa_family
                if family == UInt8(AF_INET) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(addr.pointee.ifa_addr, socklen_t(addr.pointee.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                    let ip = String(cString: hostname)
                    if let existing = tunInterfaces.firstIndex(where: { $0.name == name }) {
                        tunInterfaces[existing] = (name, true, ip)
                    } else {
                        tunInterfaces.append((name, true, ip))
                    }
                } else if !tunInterfaces.contains(where: { $0.name == name }) {
                    tunInterfaces.append((name, false, ""))
                }
            }
            ptr = addr.pointee.ifa_next
        }

        for iface in tunInterfaces {
            if iface.hasIPv4 {
                Logger.log("TUN interface \(iface.name) has IPv4: \(iface.ipv4)")
            } else {
                Logger.log("TUN interface \(iface.name) has NO IPv4", level: .warning)
            }
        }

        let mihomoTun = tunInterfaces.first(where: { $0.hasIPv4 && $0.ipv4.hasPrefix("198.18.") })
        if mihomoTun == nil {
            let logPath = kConfigFolderPath + ".mihomo_core.log"
            let coreLog = (try? String(contentsOfFile: logPath, encoding: .utf8)) ?? ""
            let tunError = coreLog.components(separatedBy: "\n")
                .first(where: { $0.contains("Start TUN") || $0.contains("operation not permitted") })
                ?? "Check Console.app for [mihomo_core] logs"
            Logger.log("TUN failed. Core log: \(tunError)", level: .error)
            NSUserNotificationCenter.default
                .post(title: NSLocalizedString("Enhanced Mode", comment: ""),
                      info: "TUN: \(tunError)")
        } else {
            Logger.log("TUN verified: \(mihomoTun!.name) @ \(mihomoTun!.ipv4)")
        }
    }

    private func queryTunFromApi(port: String, secret: String) {
        let url = URL(string: "http://127.0.0.1:\(port)/configs")!
        var request = URLRequest(url: url, timeoutInterval: 3)
        if !secret.isEmpty {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tun = json["tun"] as? [String: Any] else { return }

            let tunEnabled = tun["enable"] as? Bool ?? false
            let device = tun["device"] as? String ?? "unknown"
            let stack = tun["stack"] as? String ?? "unknown"
            Logger.log("API TUN status: enable=\(tunEnabled), device=\(device), stack=\(stack)")
        }.resume()
    }

    private func restoreEnhancedModeIfNeeded() {
        guard Settings.enhancedMode, ConfigManager.shared.isRunning else { return }

        let restore: () -> Void = { [weak self] in
            self?.enhancedModeMenuItem.isEnabled = false
            self?.enableEnhancedMode { [weak self] error in
                self?.enhancedModeMenuItem.isEnabled = true
                if let error = error {
                    Settings.enhancedMode = false
                    self?.enhancedModeMenuItem.state = .off
                    Logger.log("Failed to restore Enhanced Mode: \(error)", level: .error)
                } else {
                    self?.enhancedModeMenuItem.state = .on
                    Logger.log("Enhanced Mode restored successfully")
                }
                self?.syncConfig()
                MenuItemFactory.recreateProxyMenuItems()
                self?.resetStreamApi()
            }
        }

        if PrivilegedHelperManager.shared.isHelperCheckFinished.value {
            restore()
        } else {
            PrivilegedHelperManager.shared.isHelperCheckFinished
                .filter { $0 }
                .take(1)
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { _ in restore() })
                .disposed(by: disposeBag)
        }
    }

    @IBAction func actionAllowFromLan(_ sender: NSMenuItem) {
        ApiRequest.updateAllowLan(allow: !ConfigManager.allowConnectFromLan) {
            [weak self] in
            guard let self = self else { return }
            self.syncConfig()
            ConfigManager.allowConnectFromLan = !ConfigManager.allowConnectFromLan
        }
    }

    @IBAction func actionStartAtLogin(_ sender: NSMenuItem) {
        LaunchAtLogin.shared.isEnabled = !LaunchAtLogin.shared.isEnabled
    }

    @IBAction func actionSwitchProxyMode(_ sender: NSMenuItem) {
        let mode: ClashProxyMode
        switch sender {
        case proxyModeGlobalMenuItem:
            mode = .global
        case proxyModeDirectMenuItem:
            mode = .direct
        case proxyModeRuleMenuItem:
            mode = .rule
        default:
            return
        }
        switchProxyMode(mode: mode)
    }

    func switchProxyMode(mode: ClashProxyMode) {
        let config = ConfigManager.shared.currentConfig?.copy()
        config?.mode = mode
        ApiRequest.updateOutBoundMode(mode: mode) { _ in
            ConfigManager.shared.currentConfig = config
            ConfigManager.selectOutBoundMode = mode
            MenuItemFactory.recreateProxyMenuItems()
        }
    }

    @IBAction func actionShowNetSpeedIndicator(_ sender: NSMenuItem) {
        ConfigManager.shared.showNetSpeedIndicator = !(sender.state == .on)
    }

    @IBAction func actionSetSystemProxy(_ sender: Any?) {
        var canSaveProxy = true
        if ConfigManager.shared.proxyPortAutoSet && ConfigManager.shared.proxyShouldPaused.value {
            ConfigManager.shared.proxyPortAutoSet = false
        } else if ConfigManager.shared.isProxySetByOtherVariable.value {
            // should reset proxy to clashx
            ConfigManager.shared.isProxySetByOtherVariable.accept(false)
            ConfigManager.shared.proxyPortAutoSet = true
            // clear then reset.
            canSaveProxy = false
            SystemProxyManager.shared.disableProxy(port: 0, socksPort: 0, forceDisable: true)
        } else {
            ConfigManager.shared.proxyPortAutoSet = !ConfigManager.shared.proxyPortAutoSet
        }

        if ConfigManager.shared.proxyPortAutoSet {
            if canSaveProxy {
                SystemProxyManager.shared.saveProxy()
            }
            SystemProxyManager.shared.enableProxy()
        } else {
            SystemProxyManager.shared.disableProxy()
        }
    }

    @IBAction func actionCopyExportCommand(_ sender: NSMenuItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let port = ConfigManager.shared.currentConfig?.usedHttpPort ?? 0
        let socksport = ConfigManager.shared.currentConfig?.usedSocksPort ?? 0
        let localhost = "127.0.0.1"
        let isLocalhostCopy = sender == copyExportCommandMenuItem
        let ip = isLocalhostCopy ? localhost :
            NetworkChangeNotifier.getPrimaryIPAddress() ?? localhost
        pasteboard.setString("export https_proxy=http://\(ip):\(port) http_proxy=http://\(ip):\(port) all_proxy=socks5://\(ip):\(socksport)", forType: .string)
    }

    @IBAction func actionSpeedTest(_ sender: Any) {
        if isSpeedTesting {
            NSUserNotificationCenter.default.postSpeedTestingNotice()
            return
        }
        NSUserNotificationCenter.default.postSpeedTestBeginNotice()

        isSpeedTesting = true

        ApiRequest.getMergedProxyData { [weak self] resp in
            let group = DispatchGroup()

            for (name, _) in resp?.enclosingProviderResp?.providers ?? [:] {
                group.enter()
                ApiRequest.healthCheck(proxy: name) {
                    group.leave()
                }
            }

            for p in resp?.proxiesMap["GLOBAL"]?.all ?? [] {
                group.enter()
                ApiRequest.getProxyDelay(proxyName: p) { _ in
                    group.leave()
                }
            }
            group.notify(queue: DispatchQueue.main) {
                NSUserNotificationCenter.default.postSpeedTestFinishNotice()
                self?.isSpeedTesting = false
            }
        }
    }

    @IBAction func actionUpdateExternalResource(_ sender: Any) {
        UpdateExternalResourceAction.run()
    }

    @IBAction func actionQuit(_ sender: Any) {
        NSApplication.shared.terminate(self)
    }

    @IBAction func actionMoreSetting(_ sender: Any) {
        ClashWindowController<SettingTabViewController>.create().showWindow(sender)
    }

    // MARK: - Language

    private static let supportedLanguages: [(code: String, nativeName: String)] = [
        ("", NSLocalizedString("Follow System", comment: "")),
        ("en", "English"),
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁體中文"),
    ]

    func setupLanguageMenu() {
        let langItem = NSMenuItem()
        langItem.title = NSLocalizedString("Language", comment: "")

        let submenu = NSMenu()
        for lang in Self.supportedLanguages {
            let item = NSMenuItem(
                title: lang.nativeName,
                action: #selector(actionSelectLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = lang.code
            item.state = Settings.appLanguage == lang.code ? .on : .off
            submenu.addItem(item)
            if lang.code.isEmpty {
                submenu.addItem(.separator())
            }
        }
        langItem.submenu = submenu

        if let settingsIndex = statusMenu.items.firstIndex(where: { $0.action == #selector(actionMoreSetting(_:)) }) {
            statusMenu.insertItem(langItem, at: settingsIndex + 1)
        }
    }

    @objc func actionSelectLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String,
              code != Settings.appLanguage else { return }

        Settings.appLanguage = code
        if code.isEmpty {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()

        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Language", comment: "")
        alert.informativeText = NSLocalizedString("Language change requires restart", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Restart Now", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Later", comment: ""))

        if alert.runModal() == .alertFirstButtonReturn {
            restartApp()
        }
    }

    private func restartApp() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "sleep 0.5 && open \"\(path)\""]
        task.launch()
        NSApp.terminate(nil)
    }
}

// MARK: Streaming Info

extension AppDelegate: ApiRequestStreamDelegate {
    func didUpdateTraffic(up: Int, down: Int) {
        statusItemView.updateSpeedLabel(up: up, down: down)
    }

    func didGetLog(log: String, level: String) {
        Logger.log(log, level: ClashLogLevel(rawValue: level) ?? .unknow)
    }
}

// MARK: Help actions

extension AppDelegate {
    @IBAction func actionShowLog(_ sender: Any?) {
        NSWorkspace.shared.openFile(Logger.shared.logFilePath())
    }
}

// MARK: Config actions

extension AppDelegate {
    @IBAction func openConfigFolder(_ sender: Any) {
        if ICloudManager.shared.useiCloud.value {
            ICloudManager.shared.getUrl {
                url in
                if let url = url {
                    NSWorkspace.shared.open(url)
                }
            }
        } else {
            NSWorkspace.shared.openFile(kConfigFolderPath)
        }
    }

    @IBAction func actionUpdateConfig(_ sender: AnyObject) {
        updateConfig()
    }

    @IBAction func actionSetLogLevel(_ sender: NSMenuItem) {
        let level = ClashLogLevel(rawValue: sender.title.lowercased()) ?? .unknow
        ConfigManager.selectLoggingApiLevel = level
        dynamicLogLevel = level.toDDLogLevel()
        updateLoggingLevel()
        resetStreamApi()
    }

    @IBAction func actionAutoUpdateRemoteConfig(_ sender: Any) {
        RemoteConfigManager.autoUpdateEnable = !RemoteConfigManager.autoUpdateEnable
        remoteConfigAutoupdateMenuItem.state = RemoteConfigManager.autoUpdateEnable ? .on : .off
    }

    @IBAction func actionUpdateRemoteConfig(_ sender: Any) {
        RemoteConfigManager.shared.updateCheck(ignoreTimeLimit: true, showNotification: true)
    }

    @IBAction func actionSetUpdateInterval(_ sender: Any) {
        RemoteConfigManager.showAdd()
    }
}

// MARK: crash hanlder

extension AppDelegate {
    func registCrashLogger() {
        #if DEBUG
            return
        #else
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                AppCenter.start(withAppSecret: "dce6e9a3-b6e3-4fd2-9f2d-35c767a99663", services: [
                    Analytics.self,
                    Crashes.self
                ])
            }

        #endif
    }

    func failLaunchProtect() {
        #if DEBUG
            return
        #else
            UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": false])
            let x = UserDefaults.standard
            var launch_fail_times = 0
            if let xx = x.object(forKey: "launch_fail_times") as? Int { launch_fail_times = xx }
            launch_fail_times += 1
            x.set(launch_fail_times, forKey: "launch_fail_times")
            if launch_fail_times > 3 {
                // 发生连续崩溃
                ConfigFileManager.backupAndRemoveConfigFile()
                try? FileManager.default.removeItem(atPath: kConfigFolderPath + "Country.mmdb")
                if let domain = Bundle.main.bundleIdentifier {
                    UserDefaults.standard.removePersistentDomain(forName: domain)
                    UserDefaults.standard.synchronize()
                }
                NSUserNotificationCenter.default.post(title: "Fail on launch protect", info: "You origin Config has been renamed", notiOnly: false)
            }
            DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + Double(Int64(5 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) {
                x.set(0, forKey: "launch_fail_times")
            }
        #endif
    }
}

// MARK: Memory

extension AppDelegate {
    func selectProxyGroupWithMemory() {
        let copy = [SavedProxyModel](ConfigManager.selectedProxyRecords)
        for item in copy {
            guard item.config == ConfigManager.selectConfigName else { continue }
            Logger.log("Auto selecting \(item.group) \(item.selected)", level: .debug)
            ApiRequest.updateProxyGroup(group: item.group, selectProxy: item.selected) { success in
                if !success {
                    ConfigManager.selectedProxyRecords.removeAll { model -> Bool in
                        return model.key == item.key
                    }
                }
            }
        }
    }

    func removeUnExistProxyGroups() {
        let action: (([String]) -> Void) = { list in
            let unexists = ConfigManager.selectedProxyRecords.filter {
                !list.contains($0.config)
            }
            ConfigManager.selectedProxyRecords.removeAll {
                unexists.contains($0)
            }
        }

        if ICloudManager.shared.useiCloud.value {
            ICloudManager.shared.getConfigFilesList { list in
                action(list)
            }
        } else {
            let list = ConfigManager.getConfigFilesList()
            action(list)
        }
    }

    func selectOutBoundModeWithMenory() {
        ApiRequest.updateOutBoundMode(mode: ConfigManager.selectOutBoundMode) {
            [weak self] _ in
            ConnectionManager.closeAllConnection()
            self?.syncConfig()
        }
    }

    func selectAllowLanWithMenory() {
        ApiRequest.updateAllowLan(allow: ConfigManager.allowConnectFromLan) {
            [weak self] in
            self?.syncConfig()
        }
    }

    func hasMenuSelected() -> Bool {
        if #available(macOS 11, *) {
            return statusMenu.items.contains { $0.state == .on }
        } else {
            return true
        }
    }
}

// MARK: NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        MenuItemFactory.refreshExistingMenuItems()
        updateConfigFiles()
        syncConfig()
        NotificationCenter.default.post(name: .proxyMeneViewShowLeftPadding,
                                        object: nil,
                                        userInfo: ["show": hasMenuSelected()])
    }

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        for element in menu.items {
            (element.view as? ProxyGroupMenuHighlightDelegate)?.highlight(item: item)
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        for element in menu.items {
            (element.view as? ProxyGroupMenuHighlightDelegate)?.highlight(item: nil)
        }
    }
}

// MARK: URL Scheme

extension AppDelegate {
    @objc func handleURL(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let url = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else {
            return
        }

        guard let components = URLComponents(string: url),
              let scheme = components.scheme,
              scheme.hasPrefix("clash"),
              let host = components.host
        else { return }

        if host == "install-config" {
            guard let url = components.queryItems?.first(where: { item in
                item.name == "url"
            })?.value else { return }

            var userInfo = ["url": url]
            if let name = components.queryItems?.first(where: { item in
                item.name == "name"
            })?.value {
                userInfo["name"] = name
            }

            remoteConfigAutoupdateMenuItem.menu?.performActionForItem(at: 0)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NotificationCenter.default.post(name: Notification.Name(rawValue: "didGetUrl"), object: nil, userInfo: userInfo)
            }
        } else if host == "update-config" {
            updateConfig()
        }
    }
}
