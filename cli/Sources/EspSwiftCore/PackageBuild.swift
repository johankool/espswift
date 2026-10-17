import Foundation

/// Builds a project's firmware package (Firmware/Package.swift, next to the
/// Xcode project) for the ESP32 with SwiftPM, as a step of the ESP-IDF build:
/// `espswift internal build-package`, which the project's main/CMakeLists.txt
/// runs on every build (SwiftPM itself decides what to rebuild). CMake then
/// links the library it produces into the firmware.
///
/// Swift needs ESP-IDF's headers, as the C code sees them. They're taken from
/// the compile command of an empty C file in the main component
/// (compile_commands.json, which CMake writes before the build starts), and
/// go into a SwiftPM toolset file together with the flags Embedded Swift needs.
/// The ESP-IDF settings enabled in sdkconfig become Swift compilation
/// conditions (CONFIG_SOC_RMT_SUPPORTED, CONFIG_IDF_TARGET_ESP32C6, ...), so
/// Swift code can check them with #if, as C code does.
public struct PackageBuild: Sendable {
    public var system: System
    /// ESP-IDF's build folder.
    public var buildFolder: String
    /// The C file whose compile command provides ESP-IDF's flags.
    public var flagsSource: String
    /// The project folder, with the Xcode project.
    public var projectFolder: String
    /// The folder with the firmware's Package.swift.
    public var packageFolder: String
    /// The usr/bin folder of the Swift toolchain.
    public var swiftBin: String
    /// Where to put the built library (libFirmware.a).
    public var output: String
    /// The C compiler's own include folders, such as picolibc's; CMake leaves
    /// them out of compile commands.
    public var implicitIncludes: [String]

    public static let triple = "riscv32-none-none-eabi"

    public init(system: System, buildFolder: String, flagsSource: String, projectFolder: String, packageFolder: String,
                swiftBin: String, output: String, implicitIncludes: [String]) {
        self.system = system
        self.buildFolder = buildFolder
        self.flagsSource = flagsSource
        self.projectFolder = projectFolder
        self.packageFolder = packageFolder
        self.swiftBin = swiftBin
        self.output = output
        self.implicitIncludes = implicitIncludes
    }

    /// Where SwiftPM works: in ESP-IDF's build folder, which Xcode builds put
    /// in DerivedData. A build folder inside the project (idf.py's ./build,
    /// for builds in Terminal) is in the source folder that Xcode keeps in
    /// sync, and Xcode would take the Package.swift files of the dependencies
    /// SwiftPM downloads there for packages of the project. So then SwiftPM
    /// works in .build/esp-idf in the project folder instead.
    public static func scratchFolder(buildFolder: String, projectFolder: String, system: System) -> String {
        let build = system.resolvingSymlinks(buildFolder)
        let project = system.resolvingSymlinks(projectFolder)
        return build.hasPrefix(project + "/") ? "\(projectFolder)/.build/esp-idf" : "\(buildFolder)/swiftpm"
    }

    public func run() throws {
        let scratch = Self.scratchFolder(buildFolder: buildFolder, projectFolder: projectFolder, system: system)
        try system.createDirectory(scratch)
        let toolset = "\(scratch)/toolset.json"
        try system.writeFile(toolset, try toolsetJSON())

        let status = system.runVisibly("\(swiftBin)/swift", [
            "build",
            "--package-path", packageFolder,
            "--scratch-path", scratch,
            "--triple", Self.triple,
            "--configuration", "release",
            "--toolset", toolset,
            "--disable-local-rpath",
            // SwiftPM's own build system. Swift Build, the default since Swift
            // 6.4, links C targets with Apple's linker, which can't link
            // ESP32 code.
            "--build-system", "native",
            "--product", "Firmware",
        ], environment: system.environment)
        guard status == 0 else {
            throw EspSwiftError("Building the Swift package failed.")
        }
        try system.copyContents(of: "\(scratch)/\(Self.triple)/release/libFirmware.a", to: output)
    }

    /// ESP-IDF's C flags, from the compile command of the flags source.
    func cFlags() throws -> [String] {
        guard let data = system.readData("\(buildFolder)/compile_commands.json"),
              let commands = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw EspSwiftError("Can't read \(buildFolder)/compile_commands.json.")
        }
        let source = system.resolvingSymlinks(flagsSource)
        guard let entry = commands.first(where: { ($0["file"] as? String).map(system.resolvingSymlinks) == source }) else {
            throw EspSwiftError("compile_commands.json has no compile command for \(flagsSource).")
        }
        let arguments = entry["arguments"] as? [String] ?? ShellWords.split(entry["command"] as? String ?? "")

        var flags: [String] = []
        var march: String?
        var mabi = "-mabi=ilp32"
        for argument in expandingResponseFiles(arguments) {
            if argument.hasPrefix("-I") || argument.hasPrefix("-D") {
                flags.append(argument)
            } else if argument.hasPrefix("-march=") {
                // Espressif's own ISA extensions (_xesp...) aren't known to Clang.
                march = argument.split(separator: "_").filter { !$0.hasPrefix("xesp") }.joined(separator: "_")
            } else if argument.hasPrefix("-mabi=") {
                mabi = argument
            }
        }
        // The C compiler's own include folders are system folders, as for
        // GCC: no warnings from their headers (picolibc redefines some of
        // ESP-IDF's macros).
        for path in implicitIncludes {
            flags += ["-isystem", path]
        }
        return (march.map { [$0] } ?? []) + [mabi, "-fno-pic", "-fno-pie", "-ffunction-sections"] + flags
    }

    /// The arguments, with response files (ESP-IDF's toolchain/cflags) read.
    func expandingResponseFiles(_ arguments: [String]) -> [String] {
        arguments.flatMap { argument -> [String] in
            guard argument.hasPrefix("@"), let text = system.readFile(String(argument.dropFirst())) else {
                return [argument]
            }
            return expandingResponseFiles(ShellWords.split(text))
        }
    }

    /// The settings enabled in sdkconfig, as Swift compilation conditions:
    /// -D CONFIG_<name> for each one that's on. ESP-IDF writes them to
    /// config/sdkconfig.json in the build folder when it configures.
    func swiftConditions() throws -> [String] {
        let file = "\(buildFolder)/config/sdkconfig.json"
        guard let data = system.readData(file),
              let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw EspSwiftError("ESP-IDF's settings weren't found in \(file).")
        }
        return settings.filter { ($0.value as? Bool) == true }.keys.sorted().flatMap { ["-D", "CONFIG_\($0)"] }
    }

    func toolsetJSON() throws -> Data {
        let toolset: [String: Any] = [
            "schemaVersion": "1.0",
            // The flags of ESP-IDF's idf_swift component, which compiled Swift
            // code for ESP-IDF before. SwiftPM passes the C flags on to the
            // Swift compiler's C importer itself.
            "swiftCompiler": ["extraCLIOptions": [
                "-enable-experimental-feature", "Embedded", "-wmo", "-Osize", "-g", "-Xfrontend", "-function-sections",
            ] + (try swiftConditions())],
            "cCompiler": ["extraCLIOptions": try cFlags()],
            // An ELF archiver. SwiftPM would otherwise use Xcode's libtool,
            // which makes Mach-O archives (and Xcode 27's fails SwiftPM's
            // version check).
            "librarian": ["path": "\(swiftBin)/llvm-ar"],
        ]
        return try JSONSerialization.data(withJSONObject: toolset, options: [.prettyPrinted, .sortedKeys])
    }
}

/// Splits a command line into its words, as a POSIX shell does: spaces
/// separate words, quotes group them, and a backslash escapes a character.
public enum ShellWords {
    public static func split(_ text: String) -> [String] {
        var words: [String] = []
        var word = ""
        var inWord = false
        var quote: Character?
        var characters = text.makeIterator()
        while let character = characters.next() {
            if let open = quote {
                if character == open {
                    quote = nil
                } else if character == "\\" && open == "\"", let next = characters.next() {
                    if next != "\"" && next != "\\" && next != "$" && next != "`" { word.append("\\") }
                    word.append(next)
                } else {
                    word.append(character)
                }
            } else if character == "'" || character == "\"" {
                quote = character
                inWord = true
            } else if character == "\\", let next = characters.next() {
                if next != "\n" { word.append(next) }
                inWord = true
            } else if character.isWhitespace {
                if inWord { words.append(word) }
                word = ""
                inWord = false
            } else {
                word.append(character)
                inWord = true
            }
        }
        if inWord { words.append(word) }
        return words
    }
}
