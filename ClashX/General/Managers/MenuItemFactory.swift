//
//  MenuItemFactory.swift
//  ClashX
//
//  Created by CYC on 2018/8/4.
//  Copyright © 2018年 yichengchen. All rights reserved.
//

import Cocoa
import RxCocoa
import SwiftyJSON

class MenuItemFactory {
    private static var cachedProxyData: ClashProxyResp?

    static var useViewToRenderProxy: Bool = UserDefaults.standard.object(forKey: "useViewToRenderProxy") as? Bool ?? AppDelegate.isAboveMacOS152 {
        didSet {
            UserDefaults.standard.set(useViewToRenderProxy, forKey: "useViewToRenderProxy")
        }
    }

    // MARK: - Public

    static func refreshExistingMenuItems() {
        let previousInfo = cachedProxyData
        getMergedProxyData {
            info in
            if info?.proxiesMap.keys != previousInfo?.proxiesMap.keys {
                // force update menu
                refreshMenuItems(mergedData: info)
                return
            }

            for proxy in info?.proxies ?? [] {
                NotificationCenter.default.post(name: .proxyUpdate(for: proxy.name), object: proxy, userInfo: nil)
            }
        }
    }

    static func recreateProxyMenuItems() {
        getMergedProxyData {
            proxyInfo in
            refreshMenuItems(mergedData: proxyInfo)
        }
    }

    static func refreshMenuItems(mergedData proxyInfo: ClashProxyResp?) {
        guard let proxyInfo = proxyInfo else { return }
        var menuItems = [NSMenuItem]()
        for proxy in proxyInfo.proxyGroups {
            var menu: NSMenuItem?
            switch proxy.type {
            case .select: menu = generateSelectorMenuItem(proxyGroup: proxy, proxyInfo: proxyInfo)
            case .urltest, .fallback: menu = generateUrlTestFallBackMenuItem(proxyGroup: proxy, proxyInfo: proxyInfo)
            case .loadBalance:
                menu = generateLoadBalanceMenuItem(proxyGroup: proxy, proxyInfo: proxyInfo)
            case .relay:
                menu = generateListOnlyMenuItem(proxyGroup: proxy, proxyInfo: proxyInfo)
            default: continue
            }

            if let menu = menu {
                menuItems.append(menu)
                menu.isEnabled = true
            }
        }
        let items = Array(menuItems.reversed())
        updateProxyList(withMenus: items)
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

    // MARK: - Private

    private static func getMergedProxyData(complete: ((ClashProxyResp?) -> Void)? = nil) {
        let group = DispatchGroup()
        group.enter()
        group.enter()

        var provider: ClashProviderResp?
        var proxyInfo: ClashProxyResp?

        group.notify(queue: .main) {
            guard let proxyInfo = proxyInfo, let proxyprovider = provider else {
                assertionFailure()
                complete?(nil)
                return
            }
            proxyInfo.updateProvider(proxyprovider)
            cachedProxyData = proxyInfo
            complete?(proxyInfo)
        }

        ApiRequest.requestProxyProviderList {
            proxyprovider in
            provider = proxyprovider
            group.leave()
        }

        ApiRequest.requestProxyGroupList {
            proxy in
            proxyInfo = proxy
            group.leave()
        }
    }

    // MARK: Updaters

    static func updateProxyList(withMenus menus: [NSMenuItem]) {
        let app = AppDelegate.shared
        let startIndex = app.statusMenu.items.firstIndex(of: app.separatorLineTop)! + 1
        let endIndex = app.statusMenu.items.firstIndex(of: app.sepatatorLineEndProxySelect)!
        app.sepatatorLineEndProxySelect.isHidden = menus.count == 0
        for _ in 0..<endIndex - startIndex {
            app.statusMenu.removeItem(at: startIndex)
        }
        for each in menus {
            app.statusMenu.insertItem(each, at: startIndex)
        }
    }

    // MARK: Generators

    private static func generateSelectorMenuItem(proxyGroup: ClashProxy,
                                                 proxyInfo: ClashProxyResp) -> NSMenuItem? {
        let proxyMap = proxyInfo.proxiesMap

        let isGlobalMode = ConfigManager.shared.currentConfig?.mode == .global
        if !isGlobalMode {
            if proxyGroup.name == "GLOBAL" { return nil }
        }

        let menu = NSMenuItem(title: proxyGroup.name, action: nil, keyEquivalent: "")
        let selectedName = proxyGroup.now ?? ""
        if !ConfigManager.shared.disableShowCurrentProxyInMenu {
            menu.view = ProxyGroupMenuItemView(group: proxyGroup.name, targetProxy: selectedName)
        }
        let submenu = ProxyGroupMenu(title: proxyGroup.name)

        for proxy in proxyGroup.all ?? [] {
            guard let proxyModel = proxyMap[proxy] else { continue }
            let proxyItem = ProxyMenuItem(proxy: proxyModel,
                                          group: proxyGroup,
                                          action: #selector(MenuItemFactory.actionSelectProxy(sender:)))
            proxyItem.target = MenuItemFactory.self
            submenu.add(delegate: proxyItem)
            submenu.addItem(proxyItem)
        }

        if proxyGroup.isSpeedTestable && useViewToRenderProxy {
            submenu.minimumWidth = proxyGroup.maxProxyNameLength + ProxyItemView.fixedPlaceHolderWidth
        }

        addSpeedTestMenuItem(submenu, proxyGroup: proxyGroup)
        menu.submenu = submenu
        if !ConfigManager.shared.disableShowCurrentProxyInMenu {
            menu.view = ProxyGroupMenuItemView(group: proxyGroup.name, targetProxy: selectedName)
        }
        return menu
    }

    private static func generateUrlTestFallBackMenuItem(proxyGroup: ClashProxy, proxyInfo: ClashProxyResp) -> NSMenuItem? {
        let proxyMap = proxyInfo.proxiesMap
        let selectedName = proxyGroup.now ?? ""
        let menu = NSMenuItem(title: proxyGroup.name, action: nil, keyEquivalent: "")
        if !ConfigManager.shared.disableShowCurrentProxyInMenu {
            menu.view = ProxyGroupMenuItemView(group: proxyGroup.name, targetProxy: selectedName)
        }
        let submenu = NSMenu(title: proxyGroup.name)

        for proxyName in proxyGroup.all ?? [] {
            guard let proxy = proxyMap[proxyName] else { continue }
            let proxyMenuItem = ProxyMenuItem(proxy: proxy, group: proxyGroup, action: #selector(empty), simpleItem: true)
            proxyMenuItem.target = MenuItemFactory.self
            if proxy.name == selectedName {
                proxyMenuItem.state = .on
            }

            proxyMenuItem.submenu = ProxyDelayHistoryMenu(proxy: proxy)

            submenu.addItem(proxyMenuItem)
        }
        addSpeedTestMenuItem(submenu, proxyGroup: proxyGroup)
        menu.submenu = submenu
        return menu
    }

    private static func addSpeedTestMenuItem(_ menu: NSMenu, proxyGroup: ClashProxy) {
        guard proxyGroup.speedtestAble.count > 0 else { return }
        let speedTestItem = ProxyGroupSpeedTestMenuItem(group: proxyGroup)
        let separator = NSMenuItem.separator()
        menu.insertItem(separator, at: 0)
        menu.insertItem(speedTestItem, at: 0)
        (menu as? ProxyGroupMenu)?.add(delegate: speedTestItem)
    }

    private static func generateLoadBalanceMenuItem(proxyGroup: ClashProxy, proxyInfo: ClashProxyResp) -> NSMenuItem? {
        let proxyMap = proxyInfo.proxiesMap

        let menu = NSMenuItem(title: proxyGroup.name, action: nil, keyEquivalent: "")
        let submenu = ProxyGroupMenu(title: proxyGroup.name)

        for proxy in proxyGroup.all ?? [] {
            guard let proxyModel = proxyMap[proxy] else { continue }
            let proxyItem = ProxyMenuItem(proxy: proxyModel,
                                          group: proxyGroup,
                                          action: #selector(empty))
            proxyItem.target = MenuItemFactory.self
            submenu.add(delegate: proxyItem)
            submenu.addItem(proxyItem)
        }
        if proxyGroup.isSpeedTestable && useViewToRenderProxy {
            submenu.minimumWidth = proxyGroup.maxProxyNameLength + ProxyItemView.fixedPlaceHolderWidth
        }
        addSpeedTestMenuItem(submenu, proxyGroup: proxyGroup)
        menu.submenu = submenu

        return menu
    }

    private static func generateListOnlyMenuItem(proxyGroup: ClashProxy, proxyInfo: ClashProxyResp) -> NSMenuItem? {
        let menu = NSMenuItem(title: proxyGroup.name, action: nil, keyEquivalent: "")
        let submenu = ProxyGroupMenu(title: proxyGroup.name)
        let proxyMap = proxyInfo.proxiesMap

        for proxy in proxyGroup.all ?? [] {
            guard let proxyModel = proxyMap[proxy] else { continue }
            let proxyItem = ProxyMenuItem(proxy: proxyModel,
                                          group: proxyGroup,
                                          action: #selector(empty),
                                          simpleItem: true)
            proxyItem.target = MenuItemFactory.self
            submenu.add(delegate: proxyItem)
            submenu.addItem(proxyItem)
        }
        menu.submenu = submenu
        return menu
    }
}

// MARK: - Experimental

extension MenuItemFactory {
    static func addExperimentalMenuItem(_ menu: inout NSMenu) {
        let useViewRender = NSMenuItem(title: NSLocalizedString("Enhance proxy list render", comment: ""), action: #selector(optionUseViewRenderMenuItemTap(sender:)), keyEquivalent: "")
        useViewRender.target = self
        menu.addItem(useViewRender)
        updateUseViewRenderMenuItem(useViewRender)
    }

    static func updateUseViewRenderMenuItem(_ item: NSMenuItem) {
        item.state = useViewToRenderProxy ? .on : .off
    }

    @objc static func optionUseViewRenderMenuItemTap(sender: NSMenuItem) {
        useViewToRenderProxy = !useViewToRenderProxy
        updateUseViewRenderMenuItem(sender)
        refreshExistingMenuItems()
        recreateProxyMenuItems()
    }
}

// MARK: - Action

extension MenuItemFactory {
    @objc static func actionSelectProxy(sender: ProxyMenuItem) {
        guard let proxyGroup = sender.menu?.title else { return }
        let proxyName = sender.proxyName

        ApiRequest.updateProxyGroup(group: proxyGroup, selectProxy: proxyName) { success in
            if success {
                for items in sender.menu?.items ?? [NSMenuItem]() {
                    items.state = .off
                }
                sender.state = .on
                // remember select proxy
                let newModel = SavedProxyModel(group: proxyGroup, selected: proxyName, config: ConfigManager.selectConfigName)
                ConfigManager.selectedProxyRecords.removeAll { model -> Bool in
                    return model.key == newModel.key
                }
                ConfigManager.selectedProxyRecords.append(newModel)
                // terminal Connections for this group
                ConnectionManager.closeConnection(for: proxyGroup)
                // refresh menu items
                MenuItemFactory.refreshExistingMenuItems()
            }
        }
    }

    @objc static func actionSelectConfig(sender: NSMenuItem) {
        let config = sender.title
        AppDelegate.shared.updateConfig(configName: config, showNotification: false) {
            err in
            if err == nil {
                ConnectionManager.closeAllConnection()
            }
        }
    }

    @objc static func empty() {}
}
