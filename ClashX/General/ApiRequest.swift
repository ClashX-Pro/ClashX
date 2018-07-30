//
//  ApiRequest.swift
//  ClashX
//
//  Created by CYC on 2018/7/30.
//  Copyright © 2018年 west2online. All rights reserved.
//

import Cocoa
import Alamofire



class ApiRequest{
    static func requestConfig(completeHandler:@escaping ((ClashConfig)->())){
        request(ConfigManager.apiUrl + "/configs", method: .get).responseData{
            res in
            guard let data = res.result.value else {return}
            let config = ClashConfig.fromData(data)
            completeHandler(config)
        }
    }
    
    static func requestTrafficInfo(callback:@escaping ((Int,Int)->()) ){
        request(ConfigManager.apiUrl + "/traffic").stream {(data) in
            if let jsonData = try? JSONSerialization.jsonObject(with: data) as? [String:Int] {
                callback(jsonData!["up"] ?? 0, jsonData!["down"] ?? 0)
            }
        }
    }
    
    static func requestConfigUpdate(callback:@escaping ((Bool)->())){
        request(ConfigManager.apiUrl + "/configs", method: .put).responseJSON{
            data in
            // response is undocumented yet.
            callback(true)
        }
    }
}
