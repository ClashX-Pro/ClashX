//
//  NetworkChangeNotifier.swift
//  ClashX
//
//  Created by yicheng on 2019/10/15.
//  Copyright © 2019 west2online. All rights reserved.
//

import Cocoa
import SystemConfiguration

class NetworkChangeNotifier {
    static func start() {
        let changed: SCDynamicStoreCallBack = { dynamicStore, _, _ in
            NotificationCenter.default.post(name: kSystemNetworkStatusDidChange, object: nil)
        }
        var dynamicContext = SCDynamicStoreContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        let dcAddress = withUnsafeMutablePointer(to: &dynamicContext, { UnsafeMutablePointer<SCDynamicStoreContext>($0) })

        if let dynamicStore = SCDynamicStoreCreate(kCFAllocatorDefault, "com.clashx.networknotification" as CFString, changed, dcAddress) {
            let keysArray = ["State:/Network/Global/Proxies" as CFString] as CFArray
            SCDynamicStoreSetNotificationKeys(dynamicStore, nil, keysArray)
            let loop = SCDynamicStoreCreateRunLoopSource(kCFAllocatorDefault, dynamicStore, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), loop, .defaultMode)
            CFRunLoopRun()
        }
    }

    static func currentSystemProxySetting() -> (UInt, UInt, UInt) {
        let proxiesSetting = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as! [String: AnyObject]
        let httpProxy = proxiesSetting[kCFNetworkProxiesHTTPPort as String] as? UInt ?? 0
        let socksProxy = proxiesSetting[kCFNetworkProxiesSOCKSPort as String] as? UInt ?? 0
        let httpsProxy = proxiesSetting[kCFNetworkProxiesHTTPSPort as String] as? UInt ?? 0
        return (httpProxy, httpsProxy, socksProxy)
    }

    static func getPrimaryIPAddress() -> String? {
        let key: CFString
        let store: SCDynamicStore?
        let dict: [String: String]?
        let primaryIntf: String?

        store = SCDynamicStoreCreate(nil, "ClashX" as CFString, nil, nil)
        if store == nil {
            return nil
        }

        key = SCDynamicStoreKeyCreateNetworkGlobalEntity(nil, kSCDynamicStoreDomainState, kSCEntNetIPv4)
        dict = SCDynamicStoreCopyValue(store, key) as? [String: String]
        primaryIntf = dict?[kSCDynamicStorePropNetPrimaryInterface as String]
        guard let primary = primaryIntf else {
            return nil
        }

        var ipv6: String?

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        defer {
            freeifaddrs(ifaddr)
        }
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    let name = String(cString: interface.ifa_name)
                    if name == primary {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr,
                                    socklen_t(interface.ifa_addr.pointee.sa_len),
                                    &hostname,
                                    socklen_t(hostname.count),
                                    nil,
                                    socklen_t(0),
                                    NI_NUMERICHOST)

                        let ip = String(cString: hostname)
                        if addrFamily == UInt8(AF_INET) {
                            return ip
                        } else {
                            ipv6 = "[\(ip)]"
                        }
                    }
                }
            }
        }
        return ipv6
    }
}
