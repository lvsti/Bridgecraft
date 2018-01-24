//
//  PatchCommand.swift
//  Bridgecraft
//
//  Created by Tamas Lustyik on 2018. 01. 23..
//  Copyright © 2018. Tamas Lustyik. All rights reserved.
//

import Foundation
import XcodeEditor

extension PatchCommand {
    static func execute(outputPath: [String],
                        projectPath: String,
                        targetName: String,
                        sourceFilePath: String) {
        let cmd = PatchCommand(outputPath: outputPath,
                               projectPath: projectPath,
                               targetName: targetName,
                               sourceFilePath: sourceFilePath)
        cmd.run()
    }
}
    
struct PatchCommand {
    private let projectURL: URL
    private let outputProjectURL: URL
    private let targetName: String
    private let sourceFileURL: URL
    
    init(outputPath: [String],
         projectPath: String,
         targetName: String,
         sourceFilePath: String) {
        projectURL = URL(fileURLWithPath: projectPath)
        sourceFileURL = URL(fileURLWithPath: sourceFilePath)
        self.targetName = targetName

        if let path = outputPath.first {
            outputProjectURL = URL(fileURLWithPath: path)
        }
        else {
            outputProjectURL = projectURL
        }
    }
    
    private func run() {
        do {
            if outputProjectURL != projectURL {
                try cloneProject()
            }
            try addSourceFileToProject()
        }
        catch {
            cleanUpOnFailure()
            exit(1)
        }
    }
    
    private func cloneProject() throws {
        do {
            if FileManager.default.fileExists(atPath: outputProjectURL.path) {
                try FileManager.default.removeItem(at: outputProjectURL)
            }
            try FileManager.default.copyItem(at: projectURL, to: outputProjectURL)
        }
        catch {
            printError("cannot clone project at \(projectURL.path) to \(outputProjectURL.path): \(error)")
            throw error
        }
    }

    private func addSourceFileToProject() throws {
        guard let project = XCProject(filePath: outputProjectURL.path) else {
            printError("cannot load project at \(outputProjectURL.path)")
            throw BridgecraftError.unknown
        }
        
        let data: Data
        do {
            data = try Data(contentsOf: sourceFileURL, options: [])
        }
        catch {
            printError("cannot load bridging source at \(sourceFileURL.path): \(error)")
            throw error
        }
        
        let fileName = sourceFileURL.lastPathComponent
        let sourceFileDef = XCSourceFileDefinition(name: fileName,
                                                   data: data,
                                                   type: .SourceCodeSwift)
        
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
    
    private func cleanUpOnFailure() {
        if outputProjectURL != projectURL {
            _ = try? FileManager.default.removeItem(at: outputProjectURL)
        }
    }
    
}
