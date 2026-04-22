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
        } else if #available(macOS 11, *) {
            tabStyle = .toolbar
        } else {
            // Catalina does not have SF Symbols and the generated bitmap fallback
            // images render blurry/cramped in toolbar-style tabs. Use segmented tabs
            // with text glyphs instead for a sharper, more consistent layout.
            tabStyle = .segmentedControlOnTop
        }
        configureTabIcons()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureTabIcons() {
        let symbolNames = ["gearshape", "keyboard", "hammer"]
        let fallbackGlyphs = ["⚙︎", "⌨︎", "⚒︎"]

        for (idx, item) in tabViewItems.enumerated() where idx < min(symbolNames.count, fallbackGlyphs.count) {
            let originalLabel = item.label
            if #available(macOS 11, *), let image = NSImage(systemSymbolName: symbolNames[idx], accessibilityDescription: nil) {
                item.image = image
                item.label = originalLabel
            } else {
                item.image = nil
                item.label = "\(fallbackGlyphs[idx]) \(originalLabel)"
            }
        }
    }
}
