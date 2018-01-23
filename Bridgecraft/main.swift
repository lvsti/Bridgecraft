//
//  main.swift
//  Bridgecraft
//
//  Created by Tamas Lustyik on 2018. 01. 12..
//  Copyright © 2018. Tamas Lustyik. All rights reserved.
//

import Commander
import Foundation

let version = "0.0.5"

command(
    Flag("assume-nonnull", description: "assume that all headers have been audited for nullability"),
    Options<String>("sdk", default: [], count: 1, description: "override the SDK used for the build (see xcodebuild -sdk)"),
    Options<String>("destination", default: [], count: 1, description: "override the destination device used for the build (see xcodebuild -destination)"),
    Options<String>("output", default: [], flag: "o", count: 1, description: "write the generated interface into the given file instead of the standard output"),
    Argument<String>("project", description: "path to the project file"),
    Argument<String>("target", description: "name of the target to use"),
    GenerateCommand.execute
).run(version)


