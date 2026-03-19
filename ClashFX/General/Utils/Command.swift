//
//  Command.swift
//  ClashX
//
//  Created by yicheng on 2023/10/13.
//  Copyright © 2023 west2online. All rights reserved.
//

import Foundation

struct Command {
    let cmd: String
    let args: [String]

    func run() -> String {
        var output = ""

        // 检查命令路径是否存在
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: cmd) else {
            Logger.log("Command path does not exist: \(cmd)", level: .warning)
            return ""
        }

        let task = Process()
        task.launchPath = cmd
        task.arguments = args

        let outpipe = Pipe()
        task.standardOutput = outpipe

        do {
            task.launch()
            task.waitUntilExit()
            let outdata = outpipe.fileHandleForReading.readDataToEndOfFile()
            if var string = String(data: outdata, encoding: .utf8) {
                output = string.trimmingCharacters(in: .newlines)
            }
        } catch {
            Logger.log("Failed to run command: \(cmd), error: \(error)", level: .error)
        }

        return output
    }
}
