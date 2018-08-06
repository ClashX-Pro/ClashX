//
//  AutoStartManager.swift
//  ClashX
//
//  Created by 称一称 on 2018/6/14.
//  Copyright © 2018年 west2online. All rights reserved.
//

import Foundation
import ServiceManagement
import RxSwift



public class LaunchAtLogin {
    private static let id = "com.west2online.ClashX.LaunchHelper"
    
    static let shared = LaunchAtLogin()

    private init() {
        self.isEnableVirable.value = self.isEnabled
    }
    
    public var isEnabled: Bool {
        get {
            guard let jobs = (SMCopyAllJobDictionaries(kSMDomainUserLaunchd).takeRetainedValue() as? [[String: AnyObject]]) else {
                return false
            }
            let job = jobs.first { $0["Label"] as! String == LaunchAtLogin.id }
            return job?["OnDemand"] as? Bool ?? false
        }
        set {
            SMLoginItemSetEnabled(LaunchAtLogin.id as CFString, newValue)
            isEnableVirable.value = newValue
        }
    }
    
    var isEnableVirable = Variable<Bool>(false)
}
