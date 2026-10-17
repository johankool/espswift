import Foundation

/// Gives Xcode what it needs for code completion, jump to definition and
/// inline errors in the firmware's Swift code.
///
/// Xcode doesn't index the project's build target, because ESP-IDF builds it.
/// Instead, projects have an "Indexing" target that Xcode only indexes. Its
/// fixed settings are in the project (including the Swift toolchain, which
/// setup writes into the template); `espswift build` writes the parts that
/// depend on the build to .espswift/include-paths.rsp in the source folder:
/// the flags SwiftPM compiled the Firmware target with (PackageBuild), from
/// its build manifest. These are ESP-IDF's include paths and definitions, the
/// ESPIDF module, the modules of the package's dependencies (such as the
/// project's Kit package), the macro plugins those use, and the compilation
/// conditions for ESP-IDF's settings.
///
/// The Indexing target passes the file to the Swift frontend with
/// -Xfrontend @file, which only accepts the joined form of -I (-I<path>)
/// there. (A bare @file in OTHER_SWIFT_FLAGS is taken as an input file by
/// Xcode 26, and with -Xcc @file Xcode 26's C importer compiles the file
/// instead of reading it.)
public struct CodeCompletion: Sendable {
    public var system: System
    public var project: Project
    public var buildFolder: String

    public init(system: System, project: Project, buildFolder: String) {
        self.system = system
        self.project = project
        self.buildFolder = buildFolder
    }

    public var responseFile: String { "\(project.sourceFolder)/.espswift/include-paths.rsp" }

    public func update() throws {
        let flags = Self.flags(fromSwiftPMArguments: try firmwareArguments())
        try system.createDirectory("\(project.sourceFolder)/.espswift")
        try system.writeFile(responseFile, Self.responseFileText(flags))
    }

    /// SwiftPM's compile command for the Firmware target. Its build manifest
    /// (llbuild YAML) has each command on one line, as a JSON array:
    /// "args: [...]".
    func firmwareArguments() throws -> [String] {
        let scratch = PackageBuild.scratchFolder(buildFolder: buildFolder, projectFolder: project.folder, system: system)
        guard let manifest = system.readFile("\(scratch)/release.yaml") else {
            throw EspSwiftError("SwiftPM's build manifest wasn't found in \(scratch).")
        }
        let lines = manifest.split(separator: "\n", omittingEmptySubsequences: false)
        let header = "  \"C.Firmware-\(PackageBuild.triple)-release.module\":"
        guard let start = lines.firstIndex(where: { $0 == header }),
              let line = lines[start...].first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("args:") }),
              let colon = line.firstIndex(of: ":"),
              let arguments = try JSONSerialization.jsonObject(with: Data(line[line.index(after: colon)...].utf8)) as? [String]
        else {
            throw EspSwiftError("SwiftPM's build manifest has no compile command for the Firmware target.")
        }
        return arguments
    }

    /// The flags with which the Swift code finds what it imports.
    static func flags(fromSwiftPMArguments arguments: [String]) -> [String] {
        // Paths SwiftPM adds for the Mac (Xcode's SDK and testing plugins).
        func forTheMac(_ path: String) -> Bool {
            path.contains("/Applications/") || path.contains(".sdk") || path.contains("/host/plugins/testing")
        }
        var flags: [String] = []
        var i = 0
        while i < arguments.count {
            let argument = arguments[i]
            let value = i + 1 < arguments.count ? arguments[i + 1] : ""
            if argument == "-I" && !forTheMac(value) {
                flags.append("-I" + value)  // Swift modules of the package's dependencies
                i += 2
            } else if argument == "-Xcc" && value == "-I" && i + 3 < arguments.count {
                flags.append("-I" + arguments[i + 3])  // -Xcc -I -Xcc <path>
                i += 4
            } else if argument == "-Xcc" && value.hasPrefix("-I") {
                flags.append(value)
                i += 2
            } else if argument == "-Xcc" && value == "-isystem" && i + 3 < arguments.count {
                flags += ["-Xcc", "-isystem" + arguments[i + 3]]  // -Xcc -isystem -Xcc <path>
                i += 4
            } else if argument == "-Xcc" && (value.hasPrefix("-D") || value.hasPrefix("-fmodule-map-file=")) && !forTheMac(value) {
                flags += ["-Xcc", value]
                i += 2
            } else if argument == "-D" && !value.isEmpty {
                flags.append("-D" + value)  // Compilation conditions, such as CONFIG_SOC_RMT_SUPPORTED
                i += 2
            } else if argument.hasPrefix("-D") && argument.count > 2 {
                flags.append(argument)
                i += 1
            } else if argument == "-Xfrontend" && ["-load-plugin-executable", "-load-plugin-library"].contains(value)
                        && i + 3 < arguments.count && arguments[i + 2] == "-Xfrontend" {
                // Macros, such as swift-mmio's: -Xfrontend <flag> -Xfrontend <path>.
                if !forTheMac(arguments[i + 3]) { flags += [value, arguments[i + 3]] }
                i += 4
            } else {
                i += 1
            }
        }
        return flags
    }

    /// One argument per line, quoted so paths with spaces survive; each
    /// include path once.
    static func responseFileText(_ flags: [String]) -> String {
        var written = Set<String>()
        var text = ""
        for flag in flags {
            if flag.hasPrefix("-I") && written.contains(flag) { continue }
            written.insert(flag)
            text += "\"" + flag.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\"\n"
        }
        return text
    }
}
