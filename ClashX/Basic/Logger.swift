//
//  Logger.swift
//  ClashX
//
//  Created by CYC on 2018/8/7.
//  Copyright © 2018年 yichengchen. All rights reserved.
//

import Foundation
import CocoaLumberjack
class Logger {
    static let shared = Logger()
    var fileLogger:DDFileLogger = DDFileLogger()
    
    private init() {
        DDLog.add(DDTTYLogger.sharedInstance) // TTY = Xcode console
        fileLogger.rollingFrequency = TimeInterval(60*60*24)  // 24 hours
        fileLogger.logFileManager.maximumNumberOfLogFiles = 3
        DDLog.add(fileLogger)

    }
    
    private func logToFile(msg:String,level:ClashLogLevel) {
        switch level {
        case .debug:
            DDLogDebug(msg)
        case .error:
            DDLogError(msg)
        case .info:
            DDLogInfo(msg)
        case .warning:
            DDLogWarn(msg)
        case .unknow:
            DDLogVerbose(msg)
        }
    }
    
    static func log(msg:String ,level:ClashLogLevel = .unknow) {
        shared.logToFile(msg: "[\(level.rawValue)] \(msg)", level: level)
    }
    
    func logFilePath() -> String {
        return fileLogger.logFileManager.sortedLogFilePaths.first ?? ""
    }
}
