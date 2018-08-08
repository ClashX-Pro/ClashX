//
//  ConfigManager.swift
//  ClashX
//
//  Created by 称一称 on 2018/6/12.
//  Copyright © 2018年 west2online. All rights reserved.
//

import Foundation
import Cocoa
import RxSwift

class ConfigManager {
    
    static let shared = ConfigManager()
    
    var currentConfig:ClashConfig?{
        get {
            return currentConfigVariable.value
        }
        
        set {
            currentConfigVariable.value = newValue
        }
    }
    var currentConfigVariable = Variable<ClashConfig?>(nil)
    
    var proxyPortAutoSet:Bool {
        get{
            return UserDefaults.standard.bool(forKey: "proxyPortAutoSet")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "proxyPortAutoSet")
        }
    }
    let proxyPortAutoSetObservable = UserDefaults.standard.rx.observe(Bool.self, "proxyPortAutoSet")
    
    var showNetSpeedIndicator:Bool {
        get{
            return UserDefaults.standard.bool(forKey: "showNetSpeedIndicator")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "showNetSpeedIndicator")
        }
    }
    let showNetSpeedIndicatorObservable = UserDefaults.standard.rx.observe(Bool.self, "showNetSpeedIndicator")
    
    static var apiUrl:String{
        get {
            return "http://127.0.0.1:8080"
        }
    }
    
    static var selectedProxyMap:[String:String] {
        get{
            return UserDefaults.standard.dictionary(forKey: "selectedProxyMap") as? [String:String] ?? ["Proxy":"ProxyAuto"]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "selectedProxyMap")
        }
    }
    
}
