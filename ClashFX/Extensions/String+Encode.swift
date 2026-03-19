//
//  String+Encode.swift
//  ClashX
//
//  Created by yicheng on 2019/12/11.
//  Copyright © 2019 west2online. All rights reserved.
//

import Cocoa

extension String {
    var encoded: String {
        return addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
    }
}
