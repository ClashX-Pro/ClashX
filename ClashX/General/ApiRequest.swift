//
//  ApiRequest.swift
//  ClashX
//
//  Created by CYC on 2018/7/30.
//  Copyright © 2018年 yichengchen. All rights reserved.
//

import Alamofire
import Cocoa
import Starscream
import SwiftyJSON

protocol ApiRequestStreamDelegate: class {
    func didUpdateTraffic(up: Int, down: Int)
    func didGetLog(log: String, level: String)
}

enum RequestError: Error {
    case decodeFail
}

typealias ErrorString = String

class ApiRequest {
    static let shared = ApiRequest()

    private var proxyRespCache: ClashProxyResp?

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 604800
        configuration.timeoutIntervalForResource = 604800
        configuration.httpMaximumConnectionsPerHost = 100
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        alamoFireManager = Session(configuration: configuration)
    }

    private static func authHeader() -> HTTPHeaders {
        let secret = ConfigManager.shared.apiSecret
        return (secret.count > 0) ? ["Authorization": "Bearer \(secret)"] : [:]
    }

    @discardableResult
    private static func req(
        _ url: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default
    )
        -> DataRequest {
        guard ConfigManager.shared.isRunning else {
            return AF.request("")
        }

        return shared.alamoFireManager
            .request(ConfigManager.apiUrl + url,
                     method: method,
                     parameters: parameters,
                     encoding: encoding,
                     headers: authHeader())
    }

    weak var delegate: ApiRequestStreamDelegate?

    private var trafficWebSocket: WebSocket?
    private var loggingWebSocket: WebSocket?

    private var trafficWebSocketRetryCount = 0
    private var loggingWebSocketRetryCount = 0

    private var alamoFireManager: Session

    static func requestConfig(completeHandler: @escaping ((ClashConfig) -> Void)) {
        if !ConfigManager.builtInApiMode {
            req("/configs").responseData {
                res in
                do {
                    let data = try res.result.get()
                    guard let config = ClashConfig.fromData(data) else {
                        throw RequestError.decodeFail
                    }
                    completeHandler(config)
                } catch let err {
                    Logger.log(err.localizedDescription)
                    NSUserNotificationCenter.default.post(title: "Error", info: err.localizedDescription)
                }
            }
            return
        }

        let data = clashGetConfigs()?.toString().data(using: .utf8) ?? Data()
        guard let config = ClashConfig.fromData(data) else {
            NSUserNotificationCenter.default.post(title: "Error", info: "Get clash config failed. Try Fix your config file then reload config or restart ClashX.")
            (NSApplication.shared.delegate as? AppDelegate)?.startProxy()
            return
        }
        completeHandler(config)
    }

    static func requestConfigUpdate(configName: String, callback: @escaping ((ErrorString?) -> Void)) {
        let filePath = "\(kConfigFolderPath)\(configName).yaml"
        let placeHolderErrorDesp = "Error occoured, Please try to fix it by restarting ClashX. "

        // DEV MODE: Use API
        if !ConfigManager.builtInApiMode {
            req("/configs", method: .put, parameters: ["Path": filePath], encoding: JSONEncoding.default).responseJSON { res in
                if res.response?.statusCode == 204 {
                    ConfigManager.shared.isRunning = true
                    callback(nil)
                } else {
                    let errorJson = try? res.result.get()
                    let err = JSON(errorJson ?? "")["message"].string ?? placeHolderErrorDesp
                    callback(err)
                }
            }
            return
        }

        // NORMAL MODE: Use internal api
        let res = clashUpdateConfig(filePath.goStringBuffer())?.toString() ?? placeHolderErrorDesp
        if res == "success" {
            callback(nil)
        } else {
            callback(res)
        }
    }

    static func updateOutBoundMode(mode: ClashProxyMode, callback: ((Bool) -> Void)? = nil) {
        req("/configs", method: .patch, parameters: ["mode": mode.rawValue], encoding: JSONEncoding.default)
            .responseJSON { response in
                switch response.result {
                case .success:
                    callback?(true)
                case .failure:
                    callback?(false)
                }
            }
    }

    static func updateLogLevel(level: ClashLogLevel, callback: ((Bool) -> Void)? = nil) {
        req("/configs", method: .patch, parameters: ["log-level": level.rawValue], encoding: JSONEncoding.default).responseJSON(completionHandler: { response in
            switch response.result {
            case .success:
                callback?(true)
            case .failure:
                callback?(false)
            }
        })
    }

    static func requestProxyGroupList(completeHandler: ((ClashProxyResp) -> Void)? = nil) {
        req("/proxies").responseJSON {
            res in
            let proxies = ClashProxyResp(try? res.result.get())
            ApiRequest.shared.proxyRespCache = proxies
            completeHandler?(proxies)
        }
        return
    }

    static func requestProxyProviderList(completeHandler: ((ClashProviderResp) -> Void)? = nil) {
        req("/providers/proxies").responseData { res in
            let provider = ClashProviderResp.create(try? res.result.get())
            completeHandler?(provider)
        }
    }

    static func updateAllowLan(allow: Bool, completeHandler: (() -> Void)? = nil) {
        req("/configs",
            method: .patch,
            parameters: ["allow-lan": allow],
            encoding: JSONEncoding.default).response {
            _ in
            completeHandler?()
        }
    }

    static func updateProxyGroup(group: String, selectProxy: String, callback: @escaping ((Bool) -> Void)) {
        let groupEncoded = group.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        req("/proxies/\(groupEncoded)",
            method: .put,
            parameters: ["name": selectProxy],
            encoding: JSONEncoding.default)
            .responseJSON { response in
                callback(response.response?.statusCode == 204)
            }
    }

    static func getAllProxyList(callback: @escaping (([ClashProxyName]) -> Void)) {
        requestProxyGroupList {
            proxyInfo in
            let lists: [ClashProxyName] = proxyInfo.proxies
                .filter { $0.name == "GLOBAL" }
                .first?.all ?? []
            callback(lists)
        }
    }

    static func getProxyDelay(proxyName: String, callback: @escaping ((Int) -> Void)) {
        req("/proxies/\(proxyName.encoded)/delay",
            method: .get,
            parameters: ["timeout": 5000, "url": ConfigManager.shared.benchMarkUrl])
            .responseJSON { res in
                switch res.result {
                case let .success(value):
                    let json = JSON(value)
                    callback(json["delay"].intValue)
                case .failure:
                    callback(0)
                }
            }
    }

    static func getRules(completeHandler: @escaping ([ClashRule]) -> Void) {
        req("/rules").responseData { res in
            guard let data = try? res.result.get() else { return }
            let rule = ClashRuleResponse.fromData(data)
            completeHandler(rule.rules ?? [])
        }
    }

    static func healthCheck(proxy: ClashProviderName) {
        Logger.log("HeathCheck for \(proxy) started")
        req("/providers/proxies/\(proxy.encoded)/healthcheck").response { res in
            if res.response?.statusCode == 204 {
                Logger.log("HeathCheck for \(proxy) finished")
            } else {
                Logger.log("HeathCheck for \(proxy) failed")
            }
        }
    }
}

// MARK: - Connections

extension ApiRequest {
    static func getConnections(completeHandler: @escaping ([ClashConnectionSnapShot.Connection]) -> Void) {
        req("/connections").responseData { res in
            guard let data = try? res.result.get() else { return }
            let resp = ClashConnectionSnapShot.fromData(data)
            completeHandler(resp.connections)
        }
    }

    static func closeConnection(_ conn: ClashConnectionSnapShot.Connection) {
        req("/connections/".appending(conn.id), method: .delete).response { _ in }
    }

    static func closeAllConnection() {
        req("/connections", method: .delete).response { _ in }
    }
}

// MARK: - Stream Apis

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
            NSUserNotificationCenter.default.postStreamApiConnectFail(api: "Traffic")
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
            NSUserNotificationCenter.default.postStreamApiConnectFail(api: "Log")
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
        guard let webSocket = socket as? WebSocket else { return }
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
            guard let webSocket = socket as? WebSocket else { return }
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
        guard let webSocket = socket as? WebSocket else { return }
        let json = JSON(parseJSON: text)
        if webSocket == trafficWebSocket {
            delegate?.didUpdateTraffic(up: json["up"].intValue, down: json["down"].intValue)
        } else {
            delegate?.didGetLog(log: json["payload"].stringValue, level: json["type"].string ?? "info")
        }
    }

    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {}
}
