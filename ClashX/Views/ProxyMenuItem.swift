//
//  ProxyMenuItem.swift
//  ClashX
//
//  Created by CYC on 2019/2/18.
//  Copyright © 2019 west2online. All rights reserved.
//

import Cocoa

class ProxyMenuItem:NSMenuItem {
    var proxyName:String = ""
    
    init(proxy: ClashProxy, action selector: Selector?, maxProxyNameLength:CGFloat) {
        super.init(title: proxy.name, action: selector, keyEquivalent: "")
        
        proxyName = proxy.name
        
        if let his = proxy.history.last {
            
            let paragraph = NSMutableParagraphStyle()
            paragraph.tabStops = [
                NSTextTab(textAlignment: .right, location: maxProxyNameLength + 80, options: [:]),
            ]
            
            let str = "\(proxy.name)\t\(his.delayDisplay)"
            
            let attributed = NSMutableAttributedString(
                string: str,
                attributes: [NSAttributedString.Key.paragraphStyle: paragraph]
            )
            
            let delayAttr = [NSAttributedString.Key.font:NSFont.menuFont(ofSize: 12)]
            attributed.addAttributes(delayAttr, range: NSRange(proxy.name.utf16.count+1 ..< str.utf16.count))
            self.attributedTitle = attributed
        }
        
        
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var isSelected:Bool = false {
        didSet {
            self.state = isSelected ? .on : .off
        }
    }
    
    

}

