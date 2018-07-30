//
//  ClashConfig.swift
//  ClashX
//
//  Created by CYC on 2018/7/30.
//  Copyright © 2018年 west2online. All rights reserved.
//
import Foundation

class ClashConfig:Codable {
    let port:Int
    let socketPort:Int
    let allowLan:Bool
    let mode:String
    let logLevel:String
    
    private enum CodingKeys : String, CodingKey {
        case port, socketPort = "socket-port", allowLan = "allow-lan", mode, logLevel = "log-level"
    }
    
    static func fromData(_ data:Data)->ClashConfig{
        let decoder = JSONDecoder()
        let model = try? decoder.decode(ClashConfig.self, from: data)
        return model!
    }
}
