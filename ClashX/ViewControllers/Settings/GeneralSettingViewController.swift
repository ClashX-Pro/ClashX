//
//  GeneralSettingViewController.swift
//  ClashX Pro
//
//  Created by yicheng on 2022/11/20.
//  Copyright © 2022 west2online. All rights reserved.
//

import Cocoa
import RxSwift

class GeneralSettingViewController: NSViewController {
    @IBOutlet var ignoreListTextView: NSTextView!
    @IBOutlet weak var launchAtLoginButton: NSButton!

    @IBOutlet weak var reduceNotificationsButton: NSButton!
    @IBOutlet weak var useiCloudButton: NSButton!

    var disposeBag = DisposeBag()
    override func viewDidLoad() {
        super.viewDidLoad()
        ignoreListTextView.string = Settings.proxyIgnoreList.joined(separator: ",")
        ignoreListTextView.rx
            .string.debounce(.milliseconds(500), scheduler: MainScheduler.instance)
            .map { $0.components(separatedBy: ",").filter {!$0.isEmpty} }
            .subscribe { arr in
                print(arr)
                Settings.proxyIgnoreList = arr
            }.disposed(by: disposeBag)

        LaunchAtLogin.shared.isEnableVirable
            .map { $0 ? .on : .off }
            .bind(to: launchAtLoginButton.rx.state)
            .disposed(by: disposeBag)
        launchAtLoginButton.rx.state.map({$0 == .on}).subscribe {
            LaunchAtLogin.shared.isEnabled = $0
        }.disposed(by: disposeBag)

        ICloudManager.shared.useiCloud
            .map { $0 ? .on : .off }
            .bind(to: useiCloudButton.rx.state)
            .disposed(by: disposeBag)
        useiCloudButton.rx.state.map({$0 == .on}).subscribe {
            ICloudManager.shared.userEnableiCloud = $0
        }.disposed(by: disposeBag)
        reduceNotificationsButton.toolTip = NSLocalizedString("Reduce alerts if notification permission is disabled", comment: "")
        reduceNotificationsButton.state = Settings.disableNoti ? .on : .off
        reduceNotificationsButton.rx.state.map {$0 == .on }.subscribe {
            Settings.disableNoti = $0
        }.disposed(by: disposeBag)
    }

}
