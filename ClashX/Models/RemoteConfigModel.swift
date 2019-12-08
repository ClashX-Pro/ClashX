//
//  RemoteConfigModel.swift
//  ClashX
//
//  Created by yicheng on 2019/7/28.
//  Copyright © 2019 west2online. All rights reserved.
//

import Cocoa

class RemoteConfigModel: Codable {
    var url: String
    let name: String
    var updateTime: Date?
    var updating = false

    init(url: String, name: String, updateTime: Date? = nil) {
        self.url = url
        self.name = name
        self.updateTime = updateTime
    }

    private enum CodingKeys: String, CodingKey {
        case url, name, updateTime
    }

    func displayingTimeString() -> String {
        if updating { return NSLocalizedString("Updating", comment: "") }
        let dateFormater = DateFormatter()
        dateFormater.dateFormat = "MM-dd HH:mm"
        if let date = updateTime {
            return dateFormater.string(from: date)
        }
        return NSLocalizedString("Never", comment: "")
    }
}
