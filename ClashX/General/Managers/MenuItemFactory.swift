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
    static func menuItems(completionHandler:@escaping (([NSMenuItem])->())){
        ApiRequest.requestProxyGroupList { (res) in
            let dataDict = JSON(res)
            var menuItems = [NSMenuItem]()
            if (ConfigManager.shared.currentConfig?.mode == .direct) {
                completionHandler(menuItems)
                return
            }
            for proxyGroup in dataDict.dictionaryValue.sorted(by: {  $0.0 < $1.0}) {
                var menu:NSMenuItem?
                switch proxyGroup.value["type"].stringValue {
                case "Selector": menu = self.generateSelectorMenuItem(json: dataDict, key: proxyGroup.key)
                case "URLTest","Fallback": menu = self.generateUrlTestMenuItem(proxyGroup: proxyGroup)
                default: continue
                }
                if (menu != nil) {menuItems.append(menu!)}
                
            }
            completionHandler(menuItems.reversed())
        }
    }
    
    static func generateSelectorMenuItem(json:JSON,key:String)->NSMenuItem? {
        let proxyGroup:(key: String, value: JSON) = (key,json[key])
        let isGlobalMode = ConfigManager.shared.currentConfig?.mode == .global
        if (isGlobalMode) {
            if proxyGroup.key != "GLOBAL" {return nil}
        } else {
            if proxyGroup.key == "GLOBAL" {return nil}
        }
        
        let menu = NSMenuItem(title: proxyGroup.key, action: nil, keyEquivalent: "")
        let selectedName = proxyGroup.value["now"].stringValue
        let submenu = NSMenu(title: proxyGroup.key)
        var hasSelected = false
        submenu.minimumWidth = 20
        for proxy in proxyGroup.value["all"].arrayValue {
            if isGlobalMode {
                if json[proxy.stringValue]["type"] == "Selector" {
                    continue
                }
            }
            
            let proxyItem = ProxyMenuItem(title: proxy.stringValue, action: #selector(MenuItemFactory.actionSelectProxy(sender:)), keyEquivalent: "")
            proxyItem.target = MenuItemFactory.self
            proxyItem.proxyName = proxy.stringValue
            let selected = proxy.stringValue == selectedName
            proxyItem.state = selected ? .on : .off

            if let delay = SpeedDataRecorder.shared.getDelay(proxy.stringValue) {
                let menuItemView = ProxyMenuItemView.create(proxy: proxy.stringValue, delay: delay)
                menuItemView.isSelected = selected
                menuItemView.onClick = { [weak proxyItem] in
                    guard let proxyItem = proxyItem else {return}
                    MenuItemFactory.actionSelectProxy(sender: proxyItem)
                }
                let fittitingWidth = menuItemView.fittingSize.width
                if (fittitingWidth > submenu.minimumWidth) {
                    submenu.minimumWidth = fittitingWidth
                }
                proxyItem.view = menuItemView
            }
            
            if selected {hasSelected = true}
            submenu.addItem(proxyItem)
            submenu.autoenablesItems = false
            
        }
        for item in submenu.items {
            item.view?.frame.size.width = submenu.minimumWidth
        }
        menu.submenu = submenu
        if (!hasSelected && submenu.items.count>0) {
            self.actionSelectProxy(sender: submenu.items[0] as! ProxyMenuItem)
        }
        return menu
    }
    
    static func generateUrlTestMenuItem(proxyGroup:(key: String, value: JSON))->NSMenuItem? {
        
        let menu = NSMenuItem(title: proxyGroup.key, action: nil, keyEquivalent: "")
        let selectedName = proxyGroup.value["now"].stringValue
        let submenu = NSMenu(title: proxyGroup.key)

        let nowMenuItem = NSMenuItem(title: "now:\(selectedName)", action: nil, keyEquivalent: "")
        
        submenu.addItem(nowMenuItem)
        menu.submenu = submenu
        return menu
    }
    
   
    static func generateSwitchConfigSubMenu() -> NSMenu {
        let subMenu = NSMenu(title: "Switch Configs")
        for config in ConfigManager.getConfigFilesList() {
            let item = NSMenuItem(title: config, action: #selector(MenuItemFactory.actionSelectConfig(sender:)), keyEquivalent: "")
            item.target = MenuItemFactory.self
            item.state = ConfigManager.selectConfigName == config ? .on : .off
            subMenu.addItem(item)
        }
        return subMenu
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
        NotificationCenter.default.post(Notification(name: kShouldUpDateConfig))
    }
}

class ProxyMenuItem:NSMenuItem {
    var proxyName:String = ""
}
