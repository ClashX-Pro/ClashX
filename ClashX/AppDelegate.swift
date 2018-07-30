//
//  AppDelegate.swift
//  ClashX
//
//  Created by 称一称 on 2018/6/10.
//  Copyright © 2018年 west2online. All rights reserved.
//

import Cocoa
import LetsMove
import Alamofire

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    static let StatusItemIconWidth: CGFloat = NSStatusItem.variableLength * 2


    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var proxySettingMenuItem: NSMenuItem!
    @IBOutlet weak var autoStartMenuItem: NSMenuItem!
    
    let ssQueue = DispatchQueue(label: "com.w2fzu.ssqueue", attributes: .concurrent)

    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        signal(SIGPIPE, SIG_IGN)

        _ = ProxyConfigManager.install()
        PFMoveToApplicationsFolderIfNecessary()

        statusItem = NSStatusBar.system.statusItem(withLength: 57)
        let view = StatusItemView.create(statusItem: statusItem,statusMenu: statusMenu)
        statusItem.view = view
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
        ApiRequest.requestConfig{ (config) in
            print(config.port)
            ConfigManager.httpProxyPort = config.port
            ConfigManager.socksProxyPort = config.socketPort

            if ConfigManager.proxyPortAutoSet {
                _ = ProxyConfigManager.setUpSystemProxy(port: ConfigManager.httpProxyPort,socksPort: ConfigManager.socksProxyPort)
            }
            self.startTrafficMonitor()
        }
    }
    
    func startTrafficMonitor(){
        ApiRequest.requestTrafficInfo(){ [weak self] up,down in
            guard let `self` = self else {return}
            ((self.statusItem.view) as! StatusItemView).updateSpeedLabel(up: up, down: down)
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
        ApiRequest.requestConfigUpdate() { [weak self] success in
            guard let strongSelf = self else {return}
        }
    }
}


