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

    @IBOutlet weak var allowApiLanUsageSwitcher: NSButton!
    @IBOutlet weak var proxyPortTextField: NSTextField!
    @IBOutlet weak var apiPortTextField: NSTextField!
    @IBOutlet var ssidSuspendTextField: NSTextView!

    @IBOutlet weak var apiSecretTextField: NSTextField!

    @IBOutlet weak var apiSecretOverrideButton: NSButton!

    var disposeBag = DisposeBag()
    override func viewDidLoad() {
        super.viewDidLoad()
        ignoreListTextView.string = Settings.proxyIgnoreList.joined(separator: ",")
        ignoreListTextView.rx
            .string.debounce(.milliseconds(500), scheduler: MainScheduler.instance)
            .map { $0.components(separatedBy: ",").filter {!$0.isEmpty} }
            .subscribe { arr in
                Settings.proxyIgnoreList = arr
            }.disposed(by: disposeBag)

        ssidSuspendTextField.string = Settings.disableSSIDList.joined(separator: ",")
        ssidSuspendTextField.rx
            .string.debounce(.milliseconds(500), scheduler: MainScheduler.instance)
            .map { $0.components(separatedBy: ",").filter {!$0.isEmpty} }
            .subscribe { arr in
                Settings.disableSSIDList = arr
                SSIDSuspendTool.shared.update()
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

        if Settings.proxyPort > 0 {
            proxyPortTextField.stringValue = "\(Settings.proxyPort)"
        } else {
            proxyPortTextField.stringValue = "\(ConfigManager.shared.currentConfig?.mixedPort ?? 0)"
        }
        if Settings.apiPort > 0 {
            apiPortTextField.stringValue = "\(Settings.apiPort)"
        } else {
            apiPortTextField.stringValue = ConfigManager.shared.apiPort
        }

        apiSecretTextField.stringValue = Settings.apiSecret
        apiSecretTextField.rx.text.compactMap {$0}.bind {
            Settings.apiSecret = $0
        }.disposed(by: disposeBag)

        apiSecretOverrideButton.state = Settings.overrideConfigSecret ? .on : .off
        apiSecretOverrideButton.rx.state.bind { state in
            Settings.overrideConfigSecret = state == .on
        }.disposed(by: disposeBag)

        proxyPortTextField.rx.text
            .compactMap {$0}
            .compactMap {Int($0)}
            .bind {
                Settings.proxyPort = $0
            }.disposed(by: disposeBag)

        apiPortTextField.rx.text
            .compactMap {$0}
            .compactMap {Int($0)}
            .bind {
                Settings.apiPort = $0
            }.disposed(by: disposeBag)
        allowApiLanUsageSwitcher.state = Settings.apiPortAllowLan ? .on : .off
        allowApiLanUsageSwitcher.rx.state.bind { state in
            Settings.apiPortAllowLan = state == .on
        }.disposed(by: disposeBag)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(nil)
    }

    @IBAction func actionResetIgnoreList(_ sender: Any) {
        ignoreListTextView.string = Settings.proxyIgnoreListDefaultValue.joined(separator: ",")
        Settings.proxyIgnoreList = Settings.proxyIgnoreListDefaultValue
    }
}
