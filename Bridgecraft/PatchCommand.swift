//
//  PatchCommand.swift
//  Bridgecraft
//
//  Created by Tamas Lustyik on 2018. 01. 23..
//  Copyright © 2018. Tamas Lustyik. All rights reserved.
//

import Foundation
import XcodeEdit

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
        let projectFile: XCProjectFile
        do {
            projectFile = try XCProjectFile(xcodeprojURL: outputProjectURL)
        }
        catch {
            printError("cannot load project at \(outputProjectURL.path)")
            throw BridgecraftError.unknown
        }

        guard let target = projectFile.project.targets.first(where: { $0.value?.name == targetName })?.value else {
            printError("cannot find target \(targetName)")
            throw BridgecraftError.unknown
        }

        let fileName = sourceFileURL.lastPathComponent
        let fileType = sourceFileURL.pathExtension == "swift" ? "public.swift-source" : "public.objective-c-source"
        
        guard
            let mainGroup = projectFile.project.mainGroup.value,
            let fileRef = try? projectFile.createFileReference(path: sourceFileURL.path,
                                                               name: fileName,
                                                               sourceTree: .group,
                                                               lastKnownFileType: fileType)
        else {
            printError("cannot add source file to project")
            throw BridgecraftError.unknown
        }
        
        let xcFileRef = projectFile.addReference(value: fileRef)
        mainGroup.insertFileReference(xcFileRef, at: 0)

        let buildFile: PBXBuildFile
        do {
            buildFile = try projectFile.createBuildFile(fileReference: xcFileRef)
        }
        catch {
            printError("cannot add build file to project")
            throw BridgecraftError.unknown
        }

        guard let sources = target.buildPhases.compactMap({ $0.value as? PBXSourcesBuildPhase }).first else {
            printError("compile sources build phase not found")
            throw BridgecraftError.unknown
        }

        let xcBuildFileRef = projectFile.addReference(value: buildFile)
        sources.insertFile(xcBuildFileRef, at: 0)
        
        do {
            try projectFile.write(to: outputProjectURL)
        }
        catch {
            printError("cannot save project")
            throw BridgecraftError.unknown
        }
    }
    
    private func cleanUpOnFailure() {
        if outputProjectURL != projectURL {
            _ = try? FileManager.default.removeItem(at: outputProjectURL)
        }
    }
    
}
