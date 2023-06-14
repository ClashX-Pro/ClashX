//
//  SSIDSuspendTool.swift
//  ClashX Pro
//
//  Created by yicheng on 2023/5/24.
//  Copyright © 2023 west2online. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa

class SSIDSuspendTool {
    static let shared = SSIDSuspendTool()
    var disposeBag = DisposeBag()
    func setup() {
        NotificationCenter
            .default
            .rx
            .notification(.systemNetworkStatusDidChange)
            .observe(on: MainScheduler.instance)
            .delay(.seconds(2), scheduler: MainScheduler.instance)
            .bind { [weak self] _ in
                self?.update()
            }.disposed(by: disposeBag)

        ConfigManager.shared
            .proxyShouldPaused
            .asObservable()
            .distinctUntilChanged()
            .filter { _ in ConfigManager.shared.proxyPortAutoSet }
            .bind { pause in
                if pause {
                    SystemProxyManager.shared.disableProxy()
                } else {
                    SystemProxyManager.shared.enableProxy()
                }
            }.disposed(by: disposeBag)

        update()
    }

    func update() {
        if shouldSuspend() {
            ConfigManager.shared.proxyShouldPaused.accept(true)
        } else {
            ConfigManager.shared.proxyShouldPaused.accept(false)
        }
    }

    func shouldSuspend() -> Bool {
        if let currentSSID = NetworkChangeNotifier.getCurrentSSID() {
            return Settings.disableSSIDList.contains(currentSSID)
        } else {
            return false
        }
    }
}
