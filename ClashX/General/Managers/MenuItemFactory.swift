//
//  MenuItemFactory.swift
//  ClashX
//
//  Created by CYC on 2018/8/4.
//  Copyright © 2018年 yichengchen. All rights reserved.
//

import Cocoa
import SwiftyJSON
import RxCocoa

class MenuItemFactory {
    static func menuItems(completionHandler: @escaping (([NSMenuItem])->Void)){
        
        if ConfigManager.shared.currentConfig?.mode == .direct {
            completionHandler([])
            return
        }
        
        ApiRequest.requestProxyGroupList() {
            proxyInfo in
            var menuItems = [NSMenuItem]()
            
            for proxy in proxyInfo.proxyGroups {
                var menu:NSMenuItem?
                switch proxy.type {
                case .select: menu = self.generateSelectorMenuItem(proxyGroup: proxy, proxyInfo: proxyInfo)
                case .urltest,.fallback: menu = generateUrlTestFallBackMenuItem(proxyGroup: proxy, proxyInfo: proxyInfo)
                case .loadBalance:
                    menu = generateLoadBalanceMenuItem(proxyGroup: proxy, proxyInfo: proxyInfo)
                default: continue
                }
                
                if let menu = menu {
                    menuItems.append(menu)
                    menu.isEnabled=true
                }
            }
            completionHandler(menuItems.reversed())
        }
    }
    
    
    static func generateSelectorMenuItem(proxyGroup:ClashProxy,
                                         proxyInfo:ClashProxyResp) -> NSMenuItem? {
        let proxyMap = proxyInfo.proxiesMap
        
        let isGlobalMode = ConfigManager.shared.currentConfig?.mode == .global
        if isGlobalMode {
            if proxyGroup.name != "GLOBAL" {return nil}
        } else {
            if proxyGroup.name == "GLOBAL" {return nil}
        }
        
        let menu = NSMenuItem(title: proxyGroup.name, action: nil, keyEquivalent: "")
        let selectedName = proxyGroup.now ?? ""
        if !ConfigManager.shared.disableShowCurrentProxyInMenu {
            menu.view = ProxyGroupMenuItemView(group: proxyGroup.name, targetProxy: selectedName)
        }
        let submenu = NSMenu(title: proxyGroup.name)
        var hasSelected = false
        
        for proxy in proxyGroup.all ?? []{
            guard let proxyModel = proxyMap[proxy] else {continue}
            
            if isGlobalMode && proxyModel.type == .select {
                continue
            }
            let proxyItem = ProxyMenuItem(proxy: proxyModel, action: #selector(MenuItemFactory.actionSelectProxy(sender:)),
                                          maxProxyNameLength:proxyGroup.maxProxyNameLength)
            proxyItem.target = MenuItemFactory.self
            proxyItem.isSelected = proxy == selectedName
            
            if proxyItem.isSelected {hasSelected = true}
            submenu.addItem(proxyItem)
        }
        
        if (!hasSelected && submenu.items.count>0) {
            self.actionSelectProxy(sender: submenu.items[0] as! ProxyMenuItem)
        }
        addSpeedTestMenuItem(submenu, proxyGroup: proxyGroup)
        menu.submenu = submenu
        if !ConfigManager.shared.disableShowCurrentProxyInMenu {
            menu.view = ProxyGroupMenuItemView(group: proxyGroup.name, targetProxy: selectedName)
        }
        return menu
    }
    
    
    static func generateUrlTestFallBackMenuItem(proxyGroup:ClashProxy,proxyInfo:ClashProxyResp)->NSMenuItem? {
        
        let proxyMap = proxyInfo.proxiesMap
        let selectedName = proxyGroup.now ?? ""
        let menu = NSMenuItem(title: proxyGroup.name, action: nil, keyEquivalent: "")
        if !ConfigManager.shared.disableShowCurrentProxyInMenu {
            menu.view = ProxyGroupMenuItemView(group: proxyGroup.name, targetProxy: selectedName)
        }
        let submenu = NSMenu(title: proxyGroup.name)

        let nowMenuItem = NSMenuItem(title: "now:\(selectedName)", action: #selector(empty), keyEquivalent: "")
        nowMenuItem.target = MenuItemFactory.self
        
        if let nowProxy = proxyMap[selectedName],let historyMenu = generateHistoryMenu(nowProxy) {
            nowMenuItem.submenu = historyMenu
        }

        submenu.addItem(nowMenuItem)
        submenu.addItem(NSMenuItem.separator())

        for proxyName in proxyGroup.all ?? [] {
            guard let proxy = proxyMap[proxyName] else {continue}
            let proxyMenuItem = NSMenuItem(title: proxy.name, action: #selector(empty), keyEquivalent: "")
            proxyMenuItem.target = MenuItemFactory.self
            if proxy.name == selectedName {
                proxyMenuItem.state = .on
            }
            
            if let historyMenu = generateHistoryMenu(proxy){
                proxyMenuItem.submenu = historyMenu
            }
            
            submenu.addItem(proxyMenuItem)
        }
        menu.submenu = submenu
        return menu
    }
    
    static func addSpeedTestMenuItem(_ menus: NSMenu, proxyGroup: ClashProxy) {
        menus.addItem(NSMenuItem.separator())
        let speedTestItem = ProxyGroupSpeedTestMenuItem(group: proxyGroup)
        speedTestItem.target = MenuItemFactory.self
        speedTestItem.action = #selector(empty)
        menus.addItem(speedTestItem)
    }
    
    static func generateHistoryMenu(_ proxy:ClashProxy) -> NSMenu? {
        let historyMenu = NSMenu(title: "")
        for his in proxy.history {
            historyMenu.addItem(
                NSMenuItem(title: "\(his.dateDisplay) \(his.delayDisplay)", action: nil, keyEquivalent: ""))
        }
        return historyMenu.items.count > 0 ? historyMenu : nil
    }
    
    static func generateLoadBalanceMenuItem(proxyGroup:ClashProxy, proxyInfo:ClashProxyResp)->NSMenuItem? {
        
        let proxyMap = proxyInfo.proxiesMap

        let menu = NSMenuItem(title: proxyGroup.name, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: proxyGroup.name)
        
        for proxy in proxyGroup.all ?? [] {
            guard let proxyModel = proxyMap[proxy] else {continue}
            let proxyItem = ProxyMenuItem(proxy: proxyModel,
                                          action:#selector(empty),
                                          maxProxyNameLength:proxyGroup.maxProxyNameLength)
            proxyItem.isSelected = false
            proxyItem.target = MenuItemFactory.self
            submenu.addItem(proxyItem)
        }
        
        menu.submenu = submenu
        
        return menu
    }
   
    static func generateSwitchConfigMenuItems() -> [NSMenuItem] {
        var items = [NSMenuItem]()
        for config in ConfigManager.getConfigFilesList() {
            let item = NSMenuItem(title: config, action: #selector(MenuItemFactory.actionSelectConfig(sender:)), keyEquivalent: "")
            item.target = MenuItemFactory.self
            item.state = ConfigManager.selectConfigName == config ? .on : .off
            items.append(item)
        }
        return items
    }
}


extension MenuItemFactory {
    @objc static func actionSelectProxy(sender:ProxyMenuItem){
        guard let proxyGroup = sender.menu?.title else {return}
        let proxyName = sender.proxyName
        
        ApiRequest.updateProxyGroup(group: proxyGroup, selectProxy: proxyName) { (success) in
            if (success) {
                for items in sender.menu?.items ?? [NSMenuItem]() {
                    items.state = .off
                }
                sender.state = .on
                // remember select proxy
                ConfigManager.selectedProxyMap[proxyGroup] = proxyName
            }
        }
    }
    
    
    @objc static func actionSelectConfig(sender:NSMenuItem){
        let config = sender.title
        ConfigManager.selectConfigName = config
        NotificationCenter.default.post(name: kShouldUpDateConfig,
                                        object: nil,
                                        userInfo: ["notification": false])
    }
    
    @objc static func empty(){}
}

