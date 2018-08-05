//
//  ConfigFileFactory.swift
//  ClashX
//
//  Created by CYC on 2018/8/5.
//  Copyright © 2018年 west2online. All rights reserved.
//
import Foundation
import AppKit

class ConfigFileFactory {
    static func configFile(proxies:[ProxyServerModel]) -> String {
        var proxyStr = ""
        var proxyGroupStr = ""
        for proxy in proxies {
            let targetStr = "\(proxy.remark) = ss, \(proxy.serverHost), \(proxy.serverPort), \(proxy.method), \(proxy.password)\n"
            proxyStr.append(targetStr)
            proxyGroupStr.append("\(proxy.remark),")
        }
        let sampleConfig = NSData(contentsOfFile: Bundle.main.path(forResource: "sampleConfig", ofType: "ini")!)
        var sampleConfigStr = String(data: sampleConfig! as Data, encoding: .utf8)
        

        
        if proxies.count > 1 {
            let autoGroupStr = "ProxyAuto = url-test, \(proxyGroupStr), http://www.google.com/generate_204, 300"
            sampleConfigStr = sampleConfigStr?.replacingOccurrences(of: "{{ProxyAutoGroupPlaceHolder}}", with: autoGroupStr)
            proxyGroupStr.append("ProxyAuto,")
        }
        proxyGroupStr = String(proxyGroupStr.dropLast())

        sampleConfigStr = sampleConfigStr?.replacingOccurrences(of: "{{ProxyPlaceHolder}}", with: proxyStr)
        sampleConfigStr = sampleConfigStr?.replacingOccurrences(of: "{{ProxyGroupPlaceHolder}}", with: proxyGroupStr)

        return sampleConfigStr!
    }
    
    static func saveToClashConfigFile(str:String) {
        // save to ~/.config/clash/config.ini
        let path = (NSHomeDirectory() as NSString).appendingPathComponent("/.config/clash/config.ini")
        
        if (FileManager.default.fileExists(atPath: path)) {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
        }
        try? str.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
        NotificationCenter.default.post(Notification(name:kShouldUpDateConfig))
    }
    
    
    static func importConfigFile() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose Config Json File"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.becomeKey()
        let result = openPanel.runModal()
        if (result.rawValue == NSFileHandlingPanelOKButton && (openPanel.url) != nil) {
            let fileManager = FileManager.default
            let filePath:String = (openPanel.url?.path)!
            var profiles = [ProxyServerModel]()
            if (fileManager.fileExists(atPath: filePath) && filePath.hasSuffix("json")) {
                let data = fileManager.contents(atPath: filePath)
                let readString = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)!
                let readStringData = readString.data(using: String.Encoding.utf8.rawValue)
                
                let jsonArr1 = try! JSONSerialization.jsonObject(with: readStringData!, options: JSONSerialization.ReadingOptions.mutableContainers) as! NSDictionary

                for item in jsonArr1.object(forKey: "configs") as! [[String: AnyObject]]{
                    let profile = ProxyServerModel()
                    profile.serverHost = item["server"] as! String
                    profile.serverPort = item["server_port"] as! String
                    profile.method = item["method"] as! String
                    profile.password = item["password"] as! String
                    profile.remark = item["remarks"] as! String
                    if (profile.isValid()) {
                        profiles.append(profile)
                    }
                }
                
                let configStr = self.configFile(proxies: profiles)
                self.saveToClashConfigFile(str: configStr)
                
                let notification = NSUserNotification()
                notification.title = "Import Server Profile succeed!"
                notification.informativeText = "Successful import \(profiles.count) items"
                NSUserNotificationCenter.default
                    .deliver(notification)
            }else{
                let notification = NSUserNotification()
                notification.title = "Import Server Profile failed!"
                notification.informativeText = "Invalid config file!"
                NSUserNotificationCenter.default
                    .deliver(notification)
                return
            }
        }
    }
}
