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
        tabStyle = .toolbar
        // Set SF Symbol images in code — storyboard catalog images render as
        // black squares in NSTabViewController toolbar style on macOS 15+.
        if #available(macOS 11, *) {
            let symbols = ["gearshape", "keyboard", "hammer"]
            for (idx, item) in tabViewItems.enumerated() where idx < symbols.count {
                item.image = NSImage(systemSymbolName: symbols[idx], accessibilityDescription: nil)
            }
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
