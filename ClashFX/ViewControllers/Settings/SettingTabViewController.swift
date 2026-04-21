//
//  SettingTabViewController.swift
//  ClashX Pro
//
//  Created by yicheng on 2022/11/20.
//  Copyright © 2022 west2online. All rights reserved.
//

import Cocoa

class SettingTabViewController: NSTabViewController, NibLoadable {
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(macOS 15, *) {
            // NSTabViewController .toolbar style renders as a large gray block
            // on macOS 15 Sequoia — the toolbar layout changed significantly.
            // Fall back to segmentedControlOnTop which renders cleanly.
            tabStyle = .segmentedControlOnTop
        } else {
            tabStyle = .toolbar
            // Set SF Symbol images in code — storyboard catalog images render as
            // black squares in NSTabViewController toolbar style on macOS 11-14.
            if #available(macOS 11, *) {
                let storyboardSymbols = ["gearshape", "keyboard", "hammer"]
                for (idx, item) in tabViewItems.enumerated() where idx < storyboardSymbols.count {
                    item.image = NSImage(systemSymbolName: storyboardSymbols[idx], accessibilityDescription: nil)
                }
            }
        }
        insertAppearanceTab()
        NSApp.activate(ignoringOtherApps: true)
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        guard let window = view.window,
              let vc = tabViewItem?.viewController else { return }
        let contentSize = vc.preferredContentSize.height > 0
            ? vc.preferredContentSize
            : vc.view.frame.size
        guard contentSize.height > 0 else { return }
        let newFrame = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize))
        var frame = window.frame
        frame.origin.y += frame.height - newFrame.height
        frame.size.height = newFrame.height
        window.setFrame(frame, display: true, animate: true)
    }

    private func insertAppearanceTab() {
        let vc = AppearanceSettingViewController()
        let item = NSTabViewItem(viewController: vc)
        item.label = NSLocalizedString("Appearance", comment: "")
        if #available(macOS 11.0, *) {
            item.image = NSImage(systemSymbolName: "paintbrush", accessibilityDescription: nil)
        } else {
            item.image = NSImage(named: NSImage.colorPanelName)
        }
        insertTabViewItem(item, at: 1)
    }
}
