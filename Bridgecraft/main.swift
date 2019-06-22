//
//  main.swift
//  Bridgecraft
//
//  Created by Tamas Lustyik on 2018. 01. 12..
//  Copyright © 2018. Tamas Lustyik. All rights reserved.
//

import Commander
import Foundation

let version = "0.5.0"

let generate = command(
    Flag("assume-nonnull", description: "assume that all headers have been audited for nullability"),
    Flag("keep-defaults", description: "do not strip default values (typically in the form of '= nil') from the generated header"),
    Flag("verbose", description: "outputs all terminal commands and their results"),
    Options<String>("output", default: [], flag: "o", count: 1, description: "write the generated interface into the given file instead of the standard output"),
    Argument<String>("project", description: "path to the project file"),
    Argument<String>("target", description: "name of the target to use"),
    Argument<[String]>("xcflags", description: "additional parameters to pass to xcodebuild"),
    GenerateCommand.execute
)

let patch = command(
    Options<String>("output", default: [], flag: "o", count: 1, description: "instead of overwriting, write the modified project to the given path"),
    Argument<String>("project", description: "path to the project file"),
    Argument<String>("target", description: "name of the target to use"),
    Argument<String>("source-file", description: "the Swift source file to add to the build"),
    PatchCommand.execute
)

let group = Group()
group.addCommand("generate", "Generates the Swift interface from ObjC bridging headers", generate)
group.addCommand("patch", "Adds a Swift source file to an existing project", patch)
group.run(version)

