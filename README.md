# Bridgecraft

[![CocoaPods compatible](https://img.shields.io/cocoapods/v/Bridgecraft.svg)](https://cocoapods.org/pods/Bridgecraft)

Bridgecraft (homophone for "witchcraft") is a command line tool for generating the Swift interface for ObjC bridging headers. This comes handy if you have a mixed Swift-ObjC codebase and you want to use code generation tools (e.g. [Sourcery](https://github.com/krzysztofzablocki/Sourcery)) that only support Swift.

### How it works

Xcode already supports generating a Swift interface for any ObjC source file:

![](doc/xcode_generate_interface.png)

Unfortunately, this functionality tends to be flaky to the point that one cannot rely on it. Another disadvantage is that it is not exposed on the CLI and so it's rather difficult to use it in an automated manner.

Bridgecraft reproduces the steps needed for the interface generation with some additional safeguards to provide a reliable output, namely:

1. creates a copy of the given project
2. extracts the bridging header build setting for the given target
3. modifies the target to include a dummy source that references the bridging header
4. captures the relevant flags for compiling the dummy
5. preprocesses the dummy by expanding macros and includes (this is where the Xcode command usually fails)
6. taps into SourceKit and generates the Swift interface

### Installation

- **Binary distribution**

    Download the latest prebuilt binary (*Bridgecraft-A.B.C.zip*) from [Releases](https://github.com/lvsti/Bridgecraft/releases). Unzip the archive and run `bin/bridgecraft`.

- **Cocoapods**

    Add `pod 'Bridgecraft'` to your Podfile and run `pod update Bridgecraft`. This will download the latest release binary and place it in your project's CocoaPods path so you can run it with `$PODS_ROOT/Bridgecraft/bin/bridgecraft`

- **Manual build**

  - *Using Xcode*

      Open `Bridgecraft.xcodeproj` and build the `Bridgecraft` scheme. This will produce the `Bridgecraft.app` artifact in the derived data folder. The executable is under `Bridgecraft.app/Contents/MacOS/Bridgecraft`
  
  - *Using the Swift package manager*

      In the root folder, run:
      
      ```
      $ swift build -c release -Xswiftc -static-stdlib
      ```
      
      This will create a `.build/release` folder and produce the `bridgecraft` executable.

### Usage

Bridgecraft is a command-line tool without UI, so you can invoke it from the shell:

```
$ Bridgecraft.app/Contents/MacOS/Bridgecraft <command> ...
```

or 

```
$ bridgecraft <command> ...
```

depending on which build method you used.

Available commands:

- `generate`: generates the Swift interface from an ObjC bridging header
- `patch`: injects a Swift source file into an Xcode project

For details and available options run:

```
$ bridgecraft --help
```

### Requirements

To build: Xcode 10, Swift 4.2<br/>
To run: macOS 10.10

### Caveats and known issues

- Preprocessing throws away all `NS_ASSUME_NONNULL` macros which would result in implicitly unwrapped optionals all over the place. To circumvent that, use the `--assume-nonnull` option but make sure all the referenced headers have previously been audited for nullability.
- If your target platform is iOS/tvOS/watchOS, chances are the command will fail because it will try to build for the device instead of the simulator. As a workaround, specify the `-configuration`, `-sdk`, `-destination` or any other options that you want to send to the xcodebuild with the usual values, e.g. 

    ```
    $ bridgecraft generate <path_to_xcodeproj> <target_name> -- \
        -configuration Debug \
        -sdk iphonesimulator \
        -destination 'platform=iOS Simulator,name=iPhone 6,OS=latest'
    ```

### License

MIT
