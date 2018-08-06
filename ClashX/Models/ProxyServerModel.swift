//
//  ProxyServerModel.swift
//  ClashX
//
//  Created by CYC on 2018/8/5.
//  Copyright © 2018年 west2online. All rights reserved.
//

import Cocoa

class ProxyServerModel: NSObject, Codable {
    @objc dynamic var serverHost:String = ""
    @objc dynamic var serverPort:String = ""
    @objc dynamic var password:String = ""
    @objc dynamic var method:String = "RC4-MD5"
    @objc dynamic var remark:String = "Proxy"
    
    
    static let supportMethod = [
        "RC4-MD5",
        "AES-128-CTR",
        "AES-192-CTR",
        "AES-256-CTR",
        "AES-128-CFB",
        "AES-192-CFB",
        "AES-256-CFB",
        "CHACHA20",
        "CHACHA20-IETF",
        "XCHACHA20",
        "AEAD_AES_128_GCM",
        "AEAD_AES_192_GCM",
        "AEAD_AES_256_GCM",
        "AEAD_CHACHA20_POLY1305"
    ]
    
    func isValid() -> Bool {
        let whitespace = NSCharacterSet.whitespacesAndNewlines
        remark = remark.components(separatedBy: whitespace).joined()
        if remark == "" {remark = "NewProxy"}
        
        func validateIpAddress(_ ipToValidate: String) -> Bool {
            
            var sin = sockaddr_in()
            var sin6 = sockaddr_in6()
            
            if ipToValidate.withCString({ cstring in inet_pton(AF_INET6, cstring, &sin6.sin6_addr) }) == 1 {
                // IPv6 peer.
                return true
            }
            else if ipToValidate.withCString({ cstring in inet_pton(AF_INET, cstring, &sin.sin_addr) }) == 1 {
                // IPv4 peer.
                return true
            }
            
            return false;
        }
        
        func validateDomainName(_ value: String) -> Bool {
            // this regex from ss-ng seems useless
            let validHostnameRegex = "^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\\-]*[a-zA-Z0-9])\\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\\-]*[A-Za-z0-9])$"
            
            if (value.range(of: validHostnameRegex, options: .regularExpression) != nil) {
                return true
            } else {
                return false
            }
        }
        
        func vaildatePort(_ value: String) -> Bool {
            if let port = Int(value) {
                return port > 0 && port <= 65535
            }
            return false
        }
        
        func vaildateMethod(_ method:String) -> Bool {
            return type(of: self).supportMethod.contains(method.uppercased())
        }
        
        if !(validateIpAddress(serverHost) || validateDomainName(serverHost)) {
            return false
        }
        
        if !(vaildateMethod(method) && vaildatePort(serverPort)) {
            return false
        }
        
        if password.isEmpty {
            return false
        }
        
        return true
    }
    
    override func copy() -> Any {
        guard let data = try? JSONEncoder().encode(self) else {return ProxyServerModel()}
        let copy = try? JSONDecoder().decode(ProxyServerModel.self, from: data)
        return copy ?? ProxyServerModel()
    }
    

}
