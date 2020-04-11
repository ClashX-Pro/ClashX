//
//  ProxyMenuItem.swift
//  ClashX
//
//  Created by CYC on 2019/2/18.
//  Copyright © 2019 west2online. All rights reserved.
//

import Cocoa

class ProxyMenuItem: NSMenuItem {
    let proxyName: String
    let maxProxyNameLength: CGFloat

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var enableShowUsingView: Bool {
        MenuItemFactory.useViewToRenderProxy
    }

    init(proxy: ClashProxy,
         action selector: Selector?,
         selected: Bool,
         speedtestAble: Bool,
         maxProxyNameLength: CGFloat) {
        proxyName = proxy.name
        self.maxProxyNameLength = maxProxyNameLength
        super.init(title: proxyName, action: selector, keyEquivalent: "")
        if speedtestAble && enableShowUsingView {
            view = ProxyItemView(name: proxyName,
                                 selected: selected,
                                 delay: proxy.history.last?.delayDisplay)
        } else {
            if speedtestAble {
                attributedTitle = getAttributedTitle(name: proxyName, delay: proxy.history.last?.delayDisplay)
            }
            state = selected ? .on : .off
        }

        NotificationCenter.default.addObserver(self, selector: #selector(updateDelayNotification(note:)), name: .speedTestFinishForProxy, object: nil)
    }

    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func didClick() {
        if let action = action {
            _ = target?.perform(action, with: self)
        }
        menu?.cancelTracking()
    }

    @objc private func updateDelayNotification(note: Notification) {
        guard let name = note.userInfo?["proxyName"] as? String, name == proxyName else {
            return
        }
        if let delay = note.userInfo?["delay"] as? String {
            if enableShowUsingView {
                (view as? ProxyItemView)?.update(delay: delay)
            } else {
                attributedTitle = getAttributedTitle(name: proxyName, delay: delay)
            }
        }
    }
}

extension ProxyMenuItem: ProxyGroupMenuHighlightDelegate {
    func highlight(item: NSMenuItem?) {
        (view as? ProxyItemView)?.isHighlighted = item == self
    }
}

extension ProxyMenuItem {
    func getAttributedTitle(name: String, delay: String?) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [
            NSTextTab(textAlignment: .right, location: 65 + maxProxyNameLength, options: [:]),
        ]
        let proxyName = name.replacingOccurrences(of: "\t", with: " ")
        let str: String
        if let delay = delay {
            str = "\(proxyName)\t\(delay)"
        } else {
            str = proxyName.appending(" ")
        }

        let attributed = NSMutableAttributedString(
            string: str,
            attributes: [
                NSAttributedString.Key.paragraphStyle: paragraph,
                NSAttributedString.Key.font: NSFont.menuBarFont(ofSize: 14),
            ]
        )

        let hackAttr = [NSAttributedString.Key.font: NSFont.menuBarFont(ofSize: 15)]
        attributed.addAttributes(hackAttr, range: NSRange(name.utf16.count..<name.utf16.count + 1))

        if delay != nil {
            let delayAttr = [NSAttributedString.Key.font: NSFont.menuBarFont(ofSize: 12)]
            attributed.addAttributes(delayAttr, range: NSRange(name.utf16.count + 1..<str.utf16.count))
        }
        return attributed
    }
}
