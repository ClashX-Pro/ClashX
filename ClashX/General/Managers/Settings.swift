//
//  Settings.swift
//  ClashX
//
//  Created by yicheng on 2020/12/18.
//  Copyright © 2020 west2online. All rights reserved.
//

import Foundation
enum Settings {
    @UserDefault("mmdbDownloadUrl", defaultValue: "")
    static var mmdbDownloadUrl:String

    @UserDefault("filterInterface", defaultValue: true)
    static var filterInterface:Bool

    @UserDefault("disableNoti", defaultValue: false)
    static var disableNoti:Bool

    @UserDefault("usePacMode", defaultValue: false)
    static var usePacMode:Bool

    @UserDefault("configAutoUpdateInterval", defaultValue: 48*60*60)
    static var configAutoUpdateInterval: TimeInterval

    @UserDefault("proxyIgnoreList", defaultValue: ["192.168.0.0/16",
                                                   "10.0.0.0/8",
                                                   "172.16.0.0/12",
                                                   "127.0.0.1",
                                                   "localhost",
                                                   "*.local",
                                                   "timestamp.apple.com",
                                                   "sequoia.apple.com",
                                                   "seed-sequoia.siri.apple.com"])
    static var proxyIgnoreList: [String]
}
