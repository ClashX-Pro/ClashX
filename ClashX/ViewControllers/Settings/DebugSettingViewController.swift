//
//  DebugSettingViewController.swift
//  ClashX Pro
//
//  Created by yicheng on 2023/5/25.
//  Copyright © 2023 west2online. All rights reserved.
//

import AppKit
import RxSwift

class DebugSettingViewController: NSViewController {
    @IBOutlet weak var swiftuiMenuBarButton: NSButton!
    var disposeBag = DisposeBag()
    override func viewDidLoad() {
        super.viewDidLoad()
        swiftuiMenuBarButton.state = Settings.useSwiftUiMenuBar ? .on : .off
        swiftuiMenuBarButton.rx.state.bind { state in
            Settings.useSwiftUiMenuBar = state == .on
        }.disposed(by: disposeBag)
    }
    @IBAction func actionUnInstallProxyHelper(_ sender: Any) {
        PrivilegedHelperManager.shared.removeInstallHelper()
    }
    @IBAction func actionOpenLogFolder(_ sender: Any) {
        NSWorkspace.shared.openFile(Logger.shared.logFolder())
    }
    @IBAction func actionOpenLocalConfig(_ sender: Any) {
        NSWorkspace.shared.openFile(kConfigFolderPath)

    }
    @IBAction func actionOpenIcloudConfig(_ sender: Any) {
        if ICloudManager.shared.icloudAvailable {
            ICloudManager.shared.getUrl {
                url in
                if let url = url {
                    NSWorkspace.shared.open(url)
                }
            }
        } else {
            NSAlert.alert(with: NSLocalizedString("iCloud not available", comment: ""))
        }
    }
}
