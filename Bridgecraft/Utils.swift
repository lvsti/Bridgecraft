//
//  Utils.swift
//  Bridgecraft
//
//  Created by Tamas Lustyik on 2018. 01. 23..
//  Copyright © 2018. Tamas Lustyik. All rights reserved.
//

import Foundation

enum BridgecraftError: Error {
    case unknown
}

@discardableResult
func shell(_ command: String, args: [String]) throws -> String {
    let ps = Process()
    ps.launchPath = command
    ps.arguments = args
    
    let pipe = Pipe()
    ps.standardOutput = pipe
    
    ps.launch()
    
    var buffer = Data()
    while ps.isRunning {
        buffer.append(pipe.fileHandleForReading.readDataToEndOfFile())
    }
    
    guard ps.terminationStatus == 0 else {
        throw BridgecraftError.unknown
    }
    
    guard let output = String(data: buffer, encoding: String.Encoding.utf8) else {
        throw BridgecraftError.unknown
    }
    
    return output
}

func printError(_ msg: String) {
    msg.withCString { cstr in
        fputs(cstr, stderr)
        fputs("\n", stderr)
    }
}

