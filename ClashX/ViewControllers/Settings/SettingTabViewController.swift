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
            if #available(macOS 11, *) {
                let symbols = ["gearshape", "keyboard", "hammer"]
                for (idx, item) in tabViewItems.enumerated() where idx < symbols.count {
                    item.image = NSImage(systemSymbolName: symbols[idx], accessibilityDescription: nil)
                }
            }
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
