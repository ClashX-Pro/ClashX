//
//  RemoteConfigManager.swift
//  ClashX
//
//  Created by CYC on 2018/11/6.
//  Copyright © 2018 west2online. All rights reserved.
//

import Cocoa
import Alamofire
import Yams

class RemoteConfigManager {
    
    var configs: [RemoteConfigModel] = []
    var autoUpateTimer: Timer?
    
    static let shared = RemoteConfigManager()

    private init(){
        if let savedConfigs = UserDefaults.standard.object(forKey: "kRemoteConfigs") as? Data {
            let decoder = JSONDecoder()
            if let loadedConfig = try? decoder.decode([RemoteConfigModel].self, from: savedConfigs) {
                configs = loadedConfig
            } else {
                assertionFailure()
            }
        }
        migrateOldRemoteConfig()
        setupAutoUpdateTimer()
    }
    
    func saveConfigs() {
        Logger.log(msg: "Saving Remote Config Setting")
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(configs) {
             UserDefaults.standard.set(encoded, forKey: "kRemoteConfigs")
        }
    }
    
    func migrateOldRemoteConfig() {
        if let url = UserDefaults.standard.string(forKey: "kRemoteConfigUrl"),
            let name = URL(string: url)?.host{
            configs.append(RemoteConfigModel(url: url, name: name))
            UserDefaults.standard.removeObject(forKey: "kRemoteConfigUrl")
            saveConfigs()
        }
    }
    
    func setupAutoUpdateTimer() {
        autoUpateTimer?.invalidate()
        autoUpateTimer = nil
        guard RemoteConfigManager.autoUpdateEnable else {
            Logger.log(msg: "autoUpdateEnable did not enable,autoUpateTimer invalidated.")
            return
        }
        Logger.log(msg: "set up autoUpateTimer")
        let timeInterval: TimeInterval = 60 * 60 * 3 // Three hour
        autoUpateTimer = Timer.scheduledTimer(timeInterval: timeInterval, target: self, selector: #selector(autoUpdateCheck), userInfo: nil, repeats: true)
    }
    
    
    static var autoUpdateEnable:Bool {
        get {
            return UserDefaults.standard.object(forKey: "kAutoUpdateEnable") as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "kAutoUpdateEnable")
            RemoteConfigManager.shared.setupAutoUpdateTimer()
        }
    }
    
    @objc func autoUpdateCheck() {
        guard RemoteConfigManager.autoUpdateEnable else {return}
        Logger.log(msg: "Tigger config auto update check")
        updateCheck()
    }
    
    func updateCheck(ignoreTimeLimit: Bool = false) {
        let currentConfigName = ConfigManager.selectConfigName
        
        let group = DispatchGroup()
        
        for config in configs {
            if config.updating {continue}
            // 12hour check
            
            let timeLimitNoMantians = Date().timeIntervalSince(config.updateTime ?? Date(timeIntervalSince1970: 0)) < 60 * 60 * 12
            
            if timeLimitNoMantians && !ignoreTimeLimit {
                Logger.log(msg: "[Auto Upgrade] Bypassing \(config.name) due to time check")
                continue
            }
            Logger.log(msg: "[Auto Upgrade] Requesting \(config.name)")
            let isCurrentConfig = config.name == currentConfigName
            config.updating = true
            group.enter()
            RemoteConfigManager.updateConfig(config: config) { error in
                config.updating = false
                group.leave()
                if error == nil {
                    config.updateTime = Date()
                }
                
                if isCurrentConfig {
                    if let error = error {
                        // Fail
                        NSUserNotificationCenter.default
                            .post(title: NSLocalizedString("Remote Config Update Fail", comment: ""),
                                  info: error)
                    } else {
                        // Success
                        NSUserNotificationCenter.default
                            .post(title: NSLocalizedString("Remote Config Update", comment: "")
                                , info: NSLocalizedString("Succeed!", comment: ""))
                        NotificationCenter.default.post(Notification(name: kShouldUpDateConfig))
                        RemoteConfigManager.didUpdateConfig()
                    }
                }
                Logger.log(msg: "[Auto Upgrade] Finish \(config.name) result: \(error ?? "succeed")")
            }
            
            group.notify(queue: .main) {
                [weak self] in
                self?.saveConfigs()
            }
        }
    }
    
    
    static func getRemoteConfigData(config: RemoteConfigModel, complete:@escaping ((Data?)->Void)) {
        guard var urlRequest = try? URLRequest(url: config.url, method: .get) else {
            assertionFailure()
            Logger.log(msg: "[getRemoteConfigData] url incorrect,\(config.name) \(config.url)")
            return
        }
        urlRequest.cachePolicy = .reloadIgnoringCacheData

        request(urlRequest).responseData { res in
            complete(res.result.value)
        }
    }
    
    static func updateConfig(config: RemoteConfigModel, complete:((String?)->())?=nil) {
        getRemoteConfigData(config: config) { data in
            guard let newData = data else {
                complete?("Download fail")
                return
            }
            guard let newConfigString = String(data: newData, encoding: .utf8),
                verifyConfig(string: newConfigString) else {
                complete?("Remote Config Format Error")
                return
            }
            let savePath = kConfigFolderPath.appending(config.name).appending(".yaml")
            let fm = FileManager.default
            do {
                if fm.fileExists(atPath: savePath) {
                    try fm.removeItem(atPath: savePath)
                }
                try newData.write(to: URL(fileURLWithPath: savePath))
                complete?(nil)
            } catch let err {
                complete?(err.localizedDescription)
            }
        }
        
    }
    
    static func verifyConfig(string: String) -> Bool {
        do {
            let yaml = try Yams.load(yaml: string) as? [String: Any]
            if let proxies = yaml?["Proxy"] as? [Any], proxies.count > 0 {
                return true
            }
        } catch let error {
            Logger.log(msg: error.localizedDescription)
            return false
        }
        return false
    }
    
    static func didUpdateConfig() {
        guard let hook = UserDefaults.standard.string(forKey: "kDidUpdateRemoteConfigHook") else {return}
        DispatchQueue.global().async {
            let appleScriptStr = "do shell script \"\(hook)\""
            let appleScript = NSAppleScript(source: appleScriptStr)
            _ = appleScript?.executeAndReturnError(nil)
        }
    }
    
}

