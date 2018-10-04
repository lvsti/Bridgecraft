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
func shell(_ command: String, args: [String], verbose: Bool = false) throws -> String {
    
    let ps = Process()
    ps.launchPath = command
    ps.arguments = args
    
    let pipe = Pipe()
    ps.standardOutput = pipe
    // We associate a dummy Pipe to the Process.standardError
    // to prevent the Process from printing the short error description to the terminal
    // since now we are printing the full error description
    ps.standardError = Pipe()
    
    ps.launch()
    
    ps.waitUntilExit()
    
    let buffer = pipe.fileHandleForReading.readDataToEndOfFile()
    
    guard let output = String(data: buffer, encoding: String.Encoding.utf8) else {
        printError("\(command) \(args.joined(separator: " "))\nError parsing the output of the previous command.")
        throw BridgecraftError.unknown
    }
    
    guard ps.terminationStatus == 0 else {
        printError("\(command) \(args.joined(separator: " "))\nTerminated with the status \(ps.terminationStatus).\n\(output)")
        throw BridgecraftError.unknown
    }
    
    if verbose {
        print("\(command) \(args.joined(separator: " "))\n\(output)")
    }
    
    return output
}

func printError(_ msg: String) {
    msg.withCString { cstr in
        fputs(cstr, stderr)
        fputs("\n", stderr)
    }
}

