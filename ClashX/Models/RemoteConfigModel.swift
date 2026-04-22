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
    var name: String
    var updateTime: Date?
    var updating = false
    var isPlaceHolderName = false
    var generatedByShareLinks = false
    var generatedTemplateVersion: Int?

    init(url: String, name: String, updateTime: Date? = nil) {
        self.url = url
        self.name = name
        self.updateTime = updateTime
    }

    private enum CodingKeys: String, CodingKey {
        case url, name, updateTime, generatedByShareLinks, generatedTemplateVersion
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

extension RemoteConfigModel: Equatable {
    static func == (lhs: RemoteConfigModel, rhs: RemoteConfigModel) -> Bool {
        return lhs.name == rhs.name && lhs.url == rhs.url
    }
}
