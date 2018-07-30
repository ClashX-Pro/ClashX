//
//  ConfigManager.swift
//  ClashX
//
//  Created by 称一称 on 2018/6/12.
//  Copyright © 2018年 west2online. All rights reserved.
//

import Foundation
import Cocoa

class ConfigManager {
    
    private static let instance = ConfigManager()
    var _httpProxyPort = 0
    var _socksProxyPort = 0
    
    static var proxyPortAutoSet:Bool {
        get{
            return UserDefaults.standard.bool(forKey: "proxyPortAutoSet")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "proxyPortAutoSet")
        }
    }
    
    static var httpProxyPort:Int {
        get{
            return instance._httpProxyPort
        }
        set {
            instance._httpProxyPort = newValue
        }
    }
    
    static var socksProxyPort:Int {
        get{
            return instance._socksProxyPort
        }
        set {
            instance._socksProxyPort = newValue
        }
    }
    
    static var apiUrl:String{
        get {
            return "http://127.0.0.1:8080"
        }
    }
}
