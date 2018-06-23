//
//  AppDelegate.swift
//  ClashX
//
//  Created by 称一称 on 2018/6/10.
//  Copyright © 2018年 west2online. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    static let StatusItemIconWidth: CGFloat = NSStatusItem.variableLength


    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var proxySettingMenuItem: NSMenuItem!
    @IBOutlet weak var autoStartMenuItem: NSMenuItem!
    
    let ssQueue = DispatchQueue(label: "com.w2fzu.ssqueue", attributes: .concurrent)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        signal(SIGPIPE, SIG_IGN)

        _ = ProxyConfigManager.install()
        
        statusItem = NSStatusBar.system.statusItem(withLength: AppDelegate.StatusItemIconWidth)
        statusItem.menu = statusMenu
        updateMenuItem()
        startProxy()
        
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        if ConfigManager.proxyPortAutoSet {
            _ = ProxyConfigManager.setUpSystemProxy(port: nil,socksPort: nil)
        }
    }

    func updateMenuItem(){
        proxySettingMenuItem.state = ConfigManager.proxyPortAutoSet ? .on : .off
        autoStartMenuItem.state = LaunchAtLogin.isEnabled ? .on:.off
        let image = proxySettingMenuItem.state == .on ?
            NSImage(named: NSImage.Name(rawValue: "menu_icon"))! :
            NSImage(named: NSImage.Name(rawValue: "menu_icon_disabled"))!
        
        statusItem.image = image
    }
    
    func startProxy() {
        ssQueue.async {
            run()
        }
        
        let ports = getPortsC()
        ConfigManager.httpProxyPort = Int(String(cString: ports.r0))!
        ConfigManager.socksProxyPort = Int(String(cString: ports.r1))!
        
        if ConfigManager.proxyPortAutoSet {
            _ = ProxyConfigManager.setUpSystemProxy(port: ConfigManager.httpProxyPort,socksPort: ConfigManager.socksProxyPort)
        }
    }
    
    @IBAction func actionQuit(_ sender: Any) {
        NSApplication.shared.terminate(self)
    }
    

    
    @IBAction func actionSetSystemProxy(_ sender: Any) {
        ConfigManager.proxyPortAutoSet = !ConfigManager.proxyPortAutoSet
        updateMenuItem()
        if ConfigManager.proxyPortAutoSet {
            _ = ProxyConfigManager.setUpSystemProxy(port: ConfigManager.httpProxyPort,socksPort: ConfigManager.socksProxyPort)
        } else {
            _ = ProxyConfigManager.setUpSystemProxy(port: nil,socksPort: nil)
        }

    }
    
    @IBAction func actionCopyExportCommand(_ sender: Any) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("export https_proxy=http://127.0.0.1:\(ConfigManager.httpProxyPort);export http_proxy=http://127.0.0.1:\(ConfigManager.httpProxyPort)", forType: .string)
    }
    
    @IBAction func actionStartAtLogin(_ sender: NSMenuItem) {
        LaunchAtLogin.isEnabled = !LaunchAtLogin.isEnabled
        updateMenuItem()
    }
    
    var genConfigWindow:NSWindowController?=nil
    @IBAction func actionGenConfig(_ sender: Any) {
        let ctrl = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
            .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "sampleConfigGenerator")) as! NSWindowController
        
        genConfigWindow?.close()
        genConfigWindow=ctrl
        ctrl.window?.title = ctrl.contentViewController?.title ?? ""
        ctrl.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        ctrl.window?.makeKeyAndOrderFront(self)

    }
    
    @IBAction func openConfigFolder(_ sender: Any) {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent("/.config/clash/config.ini")
        NSWorkspace.shared.openFile(path)
    }
    @IBAction func actionUpdateConfig(_ sender: Any) {
        ssQueue.async {
            updateConfigC()
        }
    }
}


