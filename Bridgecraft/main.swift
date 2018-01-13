//
//  main.swift
//  Bridgecraft
//
//  Created by Tamas Lustyik on 2018. 01. 12..
//  Copyright © 2018. Tamas Lustyik. All rights reserved.
//

import Foundation
import SourceKittenFramework
import XcodeEditor


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


func cloneProject(at url: URL, to newURL: URL) throws {
    do {
        if FileManager.default.fileExists(atPath: newURL.path) {
            try FileManager.default.removeItem(at: newURL)
        }
        try FileManager.default.copyItem(at: url, to: newURL)
    }
    catch {
        printError("cannot clone project at \(url.path) to \(newURL.path): \(error)")
        throw error
    }
}

func bridgingHeaderPath(projectURL: URL, targetName: String) throws -> String {
    let output: String
    do {
        output = try shell("/usr/bin/xcodebuild", args: [
            "-showBuildSettings",
            "-project", projectURL.path,
            "-target", targetName
        ])
    }
    catch {
        printError("cannot query build settings for \(projectURL.path): \(error)")
        throw error
    }
    
    var headerPath: String? = nil
    
    output.enumerateLines { (line, stop) in
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("SWIFT_OBJC_BRIDGING_HEADER = ") {
            headerPath = trimmed.split(separator: "=").last?.trimmingCharacters(in: .whitespaces)
            stop = true
        }
    }
    
    guard headerPath != nil else {
        printError("bridging header setting not found in project")
        throw BridgecraftError.unknown
    }
    
    return headerPath!
}

func generateBridgingSource(headerPath: String, sourceURL: URL) throws {
    do {
        let source = "#import \"\(headerPath)\"\n"
        try source.write(to: sourceURL, atomically: false, encoding: .utf8)
    }
    catch {
        printError("cannot write bridging source at \(sourceURL.path): \(error)")
        throw error
    }
}

func addBridgingSourceToProject(sourceURL: URL, projectURL: URL, targetName: String) throws {
    guard let project = XCProject(filePath: projectURL.path) else {
        printError("cannot load project at \(projectURL.path)")
        throw BridgecraftError.unknown
    }
    
    let data: Data
    do {
        data = try Data(contentsOf: sourceURL, options: [])
    }
    catch {
        printError("cannot load bridging source at \(sourceURL.path): \(error)")
        throw error
    }
    
    let fileName = sourceURL.lastPathComponent
    let sourceFileDef = XCSourceFileDefinition(name: fileName,
                                               data: data,
                                               type: .SourceCodeObjC)
    
    let group = project.mainGroup()
    group?.addSourceFile(sourceFileDef)
    
    guard let sourceFile = project.file(withName: fileName) else {
        printError("cannot add source file to project")
        throw BridgecraftError.unknown
    }
    
    guard let target = project.target(withName: targetName) else {
        printError("cannot find target \(targetName)")
        throw BridgecraftError.unknown
    }
    target.addMember(sourceFile)
    
    project.save()
}

func compilerFlagsForBridgingSource(sourceURL: URL, projectURL: URL, targetName: String) throws -> [String] {
    let output: String
    do {
        output = try shell("/usr/bin/xcodebuild", args: [
            "clean", "build", "-n",
            "-project", projectURL.path,
            "-target", targetName
        ])
    }
    catch {
        printError("cannot dry-run build for \(projectURL.path)")
        throw error
    }
    
    let pattern = "-c \(sourceURL.resolvingSymlinksInPath().path)"
    var compilerFlags: [String]? = nil
    
    let gluedPrefixes = ["-I", "-D", "-F", "-mmacosx-version-min"]
    let splitPrefixes = ["-iquote", "-arch", "-isysroot"]
    
    output.enumerateLines { (line, stop) in
        guard line.range(of: pattern) != nil else {
            return
        }

        let escapedLine = line.replacingOccurrences(of: "\\ ", with: "##")
        let tokens = escapedLine.split(separator: " ")
        let pairs = zip(tokens, tokens.dropFirst())
        
        let relevantTokens = pairs
            .flatMap { pair -> [String] in
                
                if gluedPrefixes.contains(where: { pair.0.hasPrefix($0) }) {
                    return [String(pair.0)]
                }
                else if splitPrefixes.contains(where: { pair.0.hasPrefix($0) }) {
                    return [String(pair.0), String(pair.1)]
                }
                return []
            }
            .map { $0.replacingOccurrences(of: "##", with: " ") }

        compilerFlags = relevantTokens
        stop = true
    }

    guard compilerFlags != nil else {
        printError("cannot parse compiler flags")
        throw BridgecraftError.unknown
    }

    return compilerFlags!
}

func preprocessBridgingSource(sourceURL: URL, compilerFlags: [String], preprocessedURL: URL) throws {
    do {
        try shell("/usr/bin/clang", args: [
            "-x", "objective-c", "-C", "-fmodules", "-fimplicit-modules",
            "-E", sourceURL.path,
            "-o", preprocessedURL.path
        ] + compilerFlags)
    }
    catch {
        printError("failed to preprocess file at \(sourceURL.path): \(error)")
        throw error
    }
}

func fixNullability(preprocessedURL: URL) throws {
    do {
        let src = try String(contentsOf: preprocessedURL)
        let wrappedSrc =
            """
            #import <Foundation/Foundation.h>
            NS_ASSUME_NONNULL_BEGIN
            \(src)
            NS_ASSUME_NONNULL_END
            """
        try wrappedSrc.write(to: preprocessedURL, atomically: false, encoding: .utf8)
    }
    catch {
        printError("failed to fix nullability in preprocessed file at \(preprocessedURL.path): \(error)")
        throw error
    }
}

func generateSwiftInterface(preprocessedURL: URL) throws -> String {
    let req = Request.interface(file: preprocessedURL.path,
                                uuid: UUID().uuidString,
                                arguments: [])
    let result: [String: SourceKitRepresentable]
    do {
        result = try req.failableSend()
    }
    catch {
        printError("failed to generate interface for \(preprocessedURL.path): \(error)")
        throw error
    }
    
    guard let srcText = result["key.sourcetext"] as? String, !srcText.isEmpty else {
        printError("generated interface is empty")
        throw BridgecraftError.unknown
    }
    
    return srcText
}

func cleanUp(projectURL: URL, sourceURL: URL, preprocessedURL: URL) {
    _ = try? FileManager.default.removeItem(at: projectURL)
    _ = try? FileManager.default.removeItem(at: sourceURL)
    _ = try? FileManager.default.removeItem(at: preprocessedURL)
}

// -----------------------------------------------------------------------------

if CommandLine.arguments.count < 3 {
    print("Usage: \(CommandLine.arguments.first!) <project_file> <target_name> [options]")
    print("Options:")
    print("  --assume-nonnull       Assumes that all headers have been audited for nullability")
    print("\n")
    exit(1)
}

let origProjectURL = URL(fileURLWithPath: CommandLine.arguments[1])
let targetName = CommandLine.arguments[2]
let assumeNonnull = CommandLine.arguments.count >= 4 && CommandLine.arguments[3] == "--assume-nonnull"

let seed = arc4random() % 100

let projectFolderURL = origProjectURL.deletingLastPathComponent()
let sourceURL = projectFolderURL.appendingPathComponent("Bridging-\(seed).m")
let preprocessedURL = sourceURL.deletingPathExtension().appendingPathExtension("mi")

let newName = "\(origProjectURL.deletingPathExtension().lastPathComponent)-\(seed).\(origProjectURL.pathExtension)"
let projectURL = origProjectURL.deletingLastPathComponent().appendingPathComponent(newName)

do {
    // make a copy of the project
    try cloneProject(at: origProjectURL, to: projectURL)
    
    // get bridging header
    let headerPath = try bridgingHeaderPath(projectURL: projectURL, targetName: targetName)
    
    // generate dummy.m
    try generateBridgingSource(headerPath: headerPath, sourceURL: sourceURL)
    
    // add dummy.m to the scheme's target
    try addBridgingSourceToProject(sourceURL: sourceURL,
                                   projectURL: projectURL,
                                   targetName: targetName)
    
    // get relevant compiler flags
    let compilerFlags = try compilerFlagsForBridgingSource(sourceURL: sourceURL,
                                                           projectURL: projectURL,
                                                           targetName: targetName)
    
    // preprocess dummy.m
    try preprocessBridgingSource(sourceURL: sourceURL,
                                 compilerFlags: compilerFlags,
                                 preprocessedURL: preprocessedURL)
    
    if assumeNonnull {
        // add nullability annotations
        try fixNullability(preprocessedURL: preprocessedURL)
    }
    
    // generate interface with sourcekitten
    let interface = try generateSwiftInterface(preprocessedURL: preprocessedURL)

    // clean up
    cleanUp(projectURL: projectURL, sourceURL: sourceURL, preprocessedURL: preprocessedURL)

    print("\(interface)")
}
catch {
    // clean up
    cleanUp(projectURL: projectURL, sourceURL: sourceURL, preprocessedURL: preprocessedURL)
    exit(2)
}
