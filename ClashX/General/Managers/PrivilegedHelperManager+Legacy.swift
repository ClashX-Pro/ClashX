//
//  PrivilegedHelperManager+Legacy.swift
//  ClashX
//
//  Created by yicheng 2020/4/22.
//  Copyright © 2020 west2online. All rights reserved.
//

import Cocoa

extension PrivilegedHelperManager {
    func getInstallScript() -> String {
        let appPath = Bundle.main.bundlePath
        let bash = """
        #!/bin/bash
        set -e
        
        plistPath=/Library/LaunchDaemons/\(PrivilegedHelperManager.machServiceName).plist
        rm -rf /Library/PrivilegedHelperTools/\(PrivilegedHelperManager.machServiceName)
        if [ -e ${plistPath} ]; then
        launchctl unload -w ${plistPath}
        rm ${plistPath}
        fi
        launchctl remove \(PrivilegedHelperManager.machServiceName) || true
        
        rm -f /Library/PrivilegedHelperTools/com.west2online.ClashX.ProxyConfigHelper
        cp \(appPath)/Contents/Library/LaunchServices/\(PrivilegedHelperManager.machServiceName) /Library/PrivilegedHelperTools/\(PrivilegedHelperManager.machServiceName)

        echo '
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        <key>Label</key>
        <string>\(PrivilegedHelperManager.machServiceName)</string>
        <key>MachServices</key>
        <dict>
        <key>\(PrivilegedHelperManager.machServiceName)</key>
        <true/>
        </dict>
        <key>Program</key>
        <string>/Library/PrivilegedHelperTools/\(PrivilegedHelperManager.machServiceName)</string>
        <key>ProgramArguments</key>
        <array>
        <string>/Library/PrivilegedHelperTools/\(PrivilegedHelperManager.machServiceName)</string>
        </array>
        </dict>
        </plist>
        ' > ${plistPath}
        
        launchctl load -w ${plistPath}
        """
        return bash
    }

    func legacyInstallHelper() {
        defer {
            resetConnection()
        }
        let script = getInstallScript()
        let tmpPath = FileManager.default.temporaryDirectory.appendingPathComponent(NSUUID().uuidString).appendingPathExtension("sh")
        do {
            try script.write(to: tmpPath, atomically: true, encoding: .utf8)
            let appleScriptStr = "do shell script \"bash \(tmpPath.path) \" with administrator privileges"
            let appleScript = NSAppleScript(source: appleScriptStr)
            var dict: NSDictionary?
            if let _ = appleScript?.executeAndReturnError(&dict) {
                return
            } else {
                Logger.log("apple script fail: \(String(describing: dict))")
            }
        } catch let err {
            Logger.log("legacyInstallHelper create script fail: \(err)")
        }
    }
}
