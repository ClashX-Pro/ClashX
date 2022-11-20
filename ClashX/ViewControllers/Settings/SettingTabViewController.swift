//
//  SettingTabViewController.swift
//  ClashX Pro
//
//  Created by yicheng on 2022/11/20.
//  Copyright © 2022 west2online. All rights reserved.
//

import Cocoa

class SettingTabViewController: NSTabViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        tabStyle = .toolbar
        NSApp.activate(ignoringOtherApps: true)
    }

}
