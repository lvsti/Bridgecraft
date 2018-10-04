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
    
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    ps.standardOutput = outputPipe
    ps.standardError = errorPipe
    
    ps.launch()
    
    ps.waitUntilExit()
    
    let outputPipeResult = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let errorPipeResult = errorPipe.fileHandleForReading.readDataToEndOfFile()
    
    guard let output = String(data: outputPipeResult, encoding: String.Encoding.utf8),
    let error = String(data: errorPipeResult, encoding: String.Encoding.utf8) else {
        printError("\(command) \(args.joined(separator: " "))")
        printError("Error parsing the output of the previous command.")
        throw BridgecraftError.unknown
    }
    
    guard ps.terminationStatus == 0 else {
        printError("\(command) \(args.joined(separator: " "))")
        printError("Terminated with the status \(ps.terminationStatus).")
        printError(output)
        printError(error)
        throw BridgecraftError.unknown
    }
    
    if verbose {
        print("\(command) \(args.joined(separator: " "))")
        print(output)
        print(error)
    }
    
    return output
}

func printError(_ msg: String) {
    msg.withCString { cstr in
        fputs(cstr, stderr)
        fputs("\n", stderr)
    }
}

