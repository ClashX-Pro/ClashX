//
//  ApiRequest.swift
//  ClashX
//
//  Created by CYC on 2018/7/30.
//  Copyright © 2018年 yichengchen. All rights reserved.
//

import Cocoa
import Alamofire
import SwiftyJSON
import Starscream

protocol ApiRequestStreamDelegate: class {
    func didUpdateTraffic(up: Int, down: Int)
    func didGetLog(log: String, level: String)
}

enum RequestError: Error {
    case decodeFail
}

class ApiRequest {
    static let shared = ApiRequest()
    private init(){
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 604800
        configuration.timeoutIntervalForResource = 604800
        configuration.httpMaximumConnectionsPerHost = 50
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        alamoFireManager = Session(configuration: configuration)
    }
    
    private static func authHeader() -> HTTPHeaders {
        let secret = ConfigManager.shared.apiSecret
        return (secret.count > 0) ? ["Authorization":"Bearer \(secret)"] : [:]
    }
    
    private static func req(
        _ url: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default)
        -> DataRequest {
            guard ConfigManager.shared.isRunning else {
                return AF.request("")
            }
            
            return shared.alamoFireManager
                .request(ConfigManager.apiUrl + url,
                method: method,
                parameters: parameters,
                encoding:encoding,
                headers: authHeader())
    }
    
    weak var delegate: ApiRequestStreamDelegate?

    private var trafficWebSocket: WebSocket? = nil
    private var loggingWebSocket: WebSocket? = nil

    private var trafficWebSocketRetryCount = 0
    private var loggingWebSocketRetryCount = 0

    private var alamoFireManager: Session
    

    static func requestConfig(completeHandler:@escaping ((ClashConfig)->())){
        let data = clashGetConfigs()?.toString().data(using: .utf8) ?? Data()
        guard let config = ClashConfig.fromData(data) else {
            NSUserNotificationCenter.default.post(title: "Error", info: "Get clash config failed. Try Fix your config file then reload config or restart ClashX.")
            (NSApplication.shared.delegate as? AppDelegate)?.startProxy()
            return
        }
        completeHandler(config)
    }
    
    
    static func requestConfigUpdate() -> String?{
        let filePath = "\(kConfigFolderPath)\(ConfigManager.selectConfigName).yaml"
        
        let res = clashUpdateConfig(filePath.goStringBuffer())?.toString() ?? "unknown error"
        
        if res == "success" {
            return nil
        }
        return res
    }
    
    static func updateOutBoundMode(mode:ClashProxyMode, callback:@escaping ((Bool)->())) {
        req("/configs", method: .patch, parameters: ["mode":mode.rawValue], encoding: JSONEncoding.default)
            .responseJSON{ response in
            switch response.result {
            case .success(_):
                callback(true)
            case .failure(_):
                callback(false)
            }
        }
    }
    
    static func requestProxyGroupList() -> ClashProxyResp {
        let json = JSON(parseJSON: clashGetProxies()?.toString() ?? "")
        return ClashProxyResp(json.object)
    }
    
    static func updateAllowLan(allow:Bool,completeHandler:@escaping (()->())) {
        req("/configs",
            method: .patch,
            parameters: ["allow-lan":allow],
            encoding: JSONEncoding.default).response{
            _ in
            completeHandler()
        }
    }
    
    static func updateProxyGroup(group:String,selectProxy:String,callback:@escaping ((Bool)->())) {
        let groupEncoded = group.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        req("/proxies/\(groupEncoded)",
            method: .put,
            parameters: ["name":selectProxy],
            encoding: JSONEncoding.default)
            .responseJSON { (response) in
            callback(response.response?.statusCode == 204)
        }
    }
    
    static func getAllProxyList(callback:@escaping (([ClashProxyName])->())) {
        let proxyInfo = requestProxyGroupList()
        let proxyGroupType:[ClashProxyType] = [.urltest,.fallback,.loadBalance,.select,.direct,.reject]
        let lists:[ClashProxyName] = proxyInfo.proxies
            .filter{$0.name == "GLOBAL" && proxyGroupType.contains($0.type)}
            .first?.all ?? []
        callback(lists)
    }
    
    static func getProxyDelay(proxyName:String,callback:@escaping ((Int)->())) {
        let proxyNameEncoded = proxyName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        
        req("/proxies/\(proxyNameEncoded)/delay"
            , method: .get
            , parameters: ["timeout":5000,"url":"http://www.gstatic.com/generate_204"])
            .responseJSON { res in
                switch res.result {
                case .success(let value):
                    let json = JSON(value)
                    callback(json["delay"].intValue)
                case .failure(_):
                    callback(0)
                }
        }
    }
    
    static func getRules(completeHandler:@escaping ([ClashRule])->()) {
        req("/rules").responseData { res in
            guard let data = try? res.result.get() else {return}
            let rule = ClashRuleResponse.fromData(data)
            completeHandler(rule.rules ?? [])
        }
    }
}

// Stream Apis
extension ApiRequest {
    
    func resetStreamApis() {
        trafficWebSocketRetryCount = 0
        loggingWebSocketRetryCount = 0
        requestTrafficInfo()
        requestLog()
    }
    
    private func requestTrafficInfo() {
        trafficWebSocket?.disconnect(forceTimeout: 0, closeCode: 0)
        trafficWebSocketRetryCount += 1
        if trafficWebSocketRetryCount > 5 {
            NSUserNotificationCenter.default.postStreamApiConnectFail(api:"Traffic")
            return
        }
        
        let socket = WebSocket(url: URL(string: ConfigManager.apiUrl.appending("/traffic"))!)
        
        for header in ApiRequest.authHeader() {
            socket.request.setValue(header.value, forHTTPHeaderField: header.name)
        }
        socket.delegate = self
        socket.connect()
        trafficWebSocket = socket
                
    }
    
    private func requestLog() {
        loggingWebSocket?.disconnect()
        loggingWebSocketRetryCount += 1
        if loggingWebSocketRetryCount > 5 {
            NSUserNotificationCenter.default.postStreamApiConnectFail(api:"Log")
            return
        }
        
        let uriString = "/logs?level=".appending(ConfigManager.selectLoggingApiLevel.rawValue)
        let socket = WebSocket(url: URL(string: ConfigManager.apiUrl.appending(uriString))!)
        
        for header in ApiRequest.authHeader() {
            socket.request.setValue(header.value, forHTTPHeaderField: header.name)
        }
        socket.delegate = self
        socket.connect()
        loggingWebSocket = socket
    }
    
}

extension ApiRequest: WebSocketDelegate {
    func websocketDidConnect(socket: WebSocketClient) {
        guard let webSocket = socket as? WebSocket else {return}
        if webSocket == trafficWebSocket {
            Logger.log("trafficWebSocket did Connect", level: .debug)
        } else {
            Logger.log("loggingWebSocket did Connect", level: .debug)
        }
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        guard let err = error else {
            return
        }
        
        Logger.log(err.localizedDescription, level: .error)
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            guard let webSocket = socket as? WebSocket else {return}
            if webSocket == self.trafficWebSocket {
                Logger.log("trafficWebSocket did disconnect", level: .debug)
                self.requestTrafficInfo()
            } else {
                Logger.log("loggingWebSocket did disconnect", level: .debug)
                self.requestLog()
            }
        }
        
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        guard let webSocket = socket as? WebSocket else {return}
        let json = JSON(parseJSON: text)
        if webSocket == trafficWebSocket {
            delegate?.didUpdateTraffic(up: json["up"].intValue, down: json["down"].intValue)
        } else {
            delegate?.didGetLog(log: json["payload"].stringValue, level: json["type"].string ?? "info")
        }
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {}
}
