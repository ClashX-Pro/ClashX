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
    private static var cachedProxyMenuItem: [NSMenuItem]?
    private static var showSpeedTestItemAtTop: Bool = UserDefaults.standard.object(forKey: "kShowSpeedTestItemAtTop") as? Bool ?? AppDelegate.isAboveMacOS14 {
        didSet {
            UserDefaults.standard.set(showSpeedTestItemAtTop, forKey: "kShowSpeedTestItemAtTop")
        }
    }

    static var useViewToRenderProxy: Bool = UserDefaults.standard.object(forKey: "useViewToRenderProxy") as? Bool ?? false {
        didSet {
            UserDefaults.standard.set(useViewToRenderProxy, forKey: "useViewToRenderProxy")
        }
    }

    // MARK: - Public

    static func refreshMenuItems(completionHandler: (([NSMenuItem]) -> Void)? = nil) {
        if ConfigManager.shared.currentConfig?.mode == .direct {
            completionHandler?([])
            return
        }
        if let cached = cachedProxyMenuItem {
            completionHandler?(cached)
        }

        let group = DispatchGroup()
        group.enter()
        group.enter()

        var provider: ClashProviderResp?
        var proxyInfo: ClashProxyResp?

        group.notify(queue: .main) {
            guard let proxyInfo = proxyInfo, let proxyprovider = provider else {
                assertionFailure()
                return
            }
            proxyInfo.updateProvider(proxyprovider)

            var menuItems = [NSMenuItem]()
            for proxy in proxyInfo.proxyGroups {
                var menu: NSMenuItem?
                switch proxy.type {
                case .select: menu = self.generateSelectorMenuItem(proxyGroup: proxy, proxyInfo: proxyInfo)
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
            cachedProxyMenuItem = items
            completionHandler?(items)
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

        let isSpeedtestAble = proxyGroup.speedtestAble.count > 0

        for proxy in proxyGroup.all ?? [] {
            guard let proxyModel = proxyMap[proxy] else { continue }
            let proxyItem = ProxyMenuItem(proxy: proxyModel,
                                          action: #selector(MenuItemFactory.actionSelectProxy(sender:)),
                                          selected: proxy == selectedName,
                                          speedtestAble: isSpeedtestAble,
                                          maxProxyNameLength: proxyGroup.maxProxyNameLength)
            proxyItem.target = MenuItemFactory.self
            submenu.add(delegate: proxyItem)
            submenu.addItem(proxyItem)
        }

        if isSpeedtestAble && useViewToRenderProxy {
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
            let proxyMenuItem = NSMenuItem(title: proxy.name, action: #selector(empty), keyEquivalent: "")
            proxyMenuItem.target = MenuItemFactory.self
            if proxy.name == selectedName {
                proxyMenuItem.state = .on
            }

            if let historyMenu = generateHistoryMenu(proxy) {
                proxyMenuItem.submenu = historyMenu
            }

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
        if showSpeedTestItemAtTop {
            menu.insertItem(separator, at: 0)
            menu.insertItem(speedTestItem, at: 0)
        } else {
            menu.addItem(separator)
            menu.addItem(speedTestItem)
        }
        (menu as? ProxyGroupMenu)?.add(delegate: speedTestItem)
    }

    private static func generateHistoryMenu(_ proxy: ClashProxy) -> NSMenu? {
        let historyMenu = NSMenu(title: "")
        for his in proxy.history.reversed() {
            historyMenu.addItem(
                NSMenuItem(title: "\(his.dateDisplay) \(his.delayDisplay)", action: nil, keyEquivalent: ""))
        }
        return historyMenu.items.count > 0 ? historyMenu : nil
    }

    private static func generateLoadBalanceMenuItem(proxyGroup: ClashProxy, proxyInfo: ClashProxyResp) -> NSMenuItem? {
        let proxyMap = proxyInfo.proxiesMap

        let menu = NSMenuItem(title: proxyGroup.name, action: nil, keyEquivalent: "")
        let submenu = ProxyGroupMenu(title: proxyGroup.name)

        let isSpeedTestAble = proxyGroup.speedtestAble.count > 0
        for proxy in proxyGroup.all ?? [] {
            guard let proxyModel = proxyMap[proxy] else { continue }
            let proxyItem = ProxyMenuItem(proxy: proxyModel,
                                          action: #selector(empty),
                                          selected: false,
                                          speedtestAble: isSpeedTestAble,
                                          maxProxyNameLength: proxyGroup.maxProxyNameLength)
            proxyItem.target = MenuItemFactory.self
            submenu.add(delegate: proxyItem)
            submenu.addItem(proxyItem)
        }
        if isSpeedTestAble && useViewToRenderProxy {
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
                                          action: #selector(empty),
                                          selected: false,
                                          speedtestAble: false,
                                          maxProxyNameLength: proxyGroup.maxProxyNameLength)
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
        let speedtestItem = NSMenuItem(title: NSLocalizedString("Show speedTest at top", comment: ""), action: #selector(optionSpeedtestMenuItemTap(sender:)), keyEquivalent: "")
        speedtestItem.target = self
        menu.addItem(speedtestItem)
        updateSpeedtestMenuItemStatus(speedtestItem)

        let useViewRender = NSMenuItem(title: NSLocalizedString("Enhance proxy list render", comment: ""), action: #selector(optionUseViewRenderMenuItemTap(sender:)), keyEquivalent: "")
        useViewRender.target = self
        menu.addItem(useViewRender)
        updateUseViewRenderMenuItem(useViewRender)
    }

    static func updateSpeedtestMenuItemStatus(_ item: NSMenuItem) {
        item.state = showSpeedTestItemAtTop ? .on : .off
    }

    static func updateUseViewRenderMenuItem(_ item: NSMenuItem) {
        item.state = useViewToRenderProxy ? .on : .off
    }

    @objc static func optionSpeedtestMenuItemTap(sender: NSMenuItem) {
        showSpeedTestItemAtTop = !showSpeedTestItemAtTop
        updateSpeedtestMenuItemStatus(sender)
        refreshMenuItems()
    }

    @objc static func optionUseViewRenderMenuItemTap(sender: NSMenuItem) {
        useViewToRenderProxy = !useViewToRenderProxy
        updateUseViewRenderMenuItem(sender)
        refreshMenuItems()
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
                MenuItemFactory.refreshMenuItems()
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
