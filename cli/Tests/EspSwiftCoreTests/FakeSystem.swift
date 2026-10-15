import EspSwiftCore
import Foundation

/// A system made of a few files, folders and commands, for tests. It records
/// what commands do to it in `actions`.
final class FakeSystem: System, @unchecked Sendable {
    var operatingSystem: OperatingSystem = .macOS
    var homeDirectory = "/Users/test"
    var environment: [String: String] = ["PATH": "/usr/bin:/bin"]
    var executablePath: String? = "/opt/homebrew/Cellar/espswift/0.1.0/bin/espswift"
    /// Files and their contents.
    var files: [String: Data] = [:]
    var directories: Set<String> = []
    /// The output of commands, by executable path.
    var commands: [String: CommandResult] = [:]
    /// What visible commands do when run (e.g. create the files they install),
    /// by executable path; they succeed unless it returns another status.
    var effects: [String: (FakeSystem, [String]) -> Int32] = [:]
    var isInteractive = false
    /// Answers to questions, in order.
    var answers: [String] = []
    /// Changes and commands, in order: "mkdir path", "rm path", "copy a -> b",
    /// "link a -> b", "write path", "chmod path", "run tool args".
    var actions: [String] = []
    var reports: [String] = []

    init() {}

    func fileExists(_ path: String) -> Bool {
        files[path] != nil || directories.contains(path) || commands[path] != nil || effects[path] != nil
    }

    func isDirectory(_ path: String) -> Bool { directories.contains(path) }

    func contentsOfDirectory(_ path: String) -> [String] {
        let prefix = path.hasSuffix("/") ? path : path + "/"
        let entries = Array(files.keys) + directories + Array(commands.keys)
        return Array(Set(entries.filter { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count).prefix(while: { $0 != "/" })) }))
    }

    func readFile(_ path: String) -> String? { files[path].map { String(decoding: $0, as: UTF8.self) } }
    func readData(_ path: String) -> Data? { files[path] }

    func createDirectory(_ path: String) throws {
        actions.append("mkdir \(path)")
        var folder = path
        while folder.count > 1 {
            directories.insert(folder)
            folder = String(folder[..<(folder.lastIndex(of: "/") ?? folder.startIndex)])
        }
    }

    func removeItem(_ path: String) throws {
        guard fileExists(path) else { return }
        actions.append("rm \(path)")
        files = files.filter { !($0.key == path || $0.key.hasPrefix(path + "/")) }
        directories = directories.filter { !($0 == path || $0.hasPrefix(path + "/")) }
    }

    func copyContents(of source: String, to destination: String) throws {
        actions.append("copy \(source) -> \(destination)")
        for (path, data) in files where path == source || path.hasPrefix(source + "/") {
            files[destination + path.dropFirst(source.count)] = data
        }
        for path in directories where path == source || path.hasPrefix(source + "/") {
            directories.insert(destination + path.dropFirst(source.count))
        }
    }

    func createSymbolicLink(at path: String, to destination: String) throws {
        actions.append("link \(path) -> \(destination)")
        files[path] = Data()
        commands[path] = commands[destination]
    }

    func writeFile(_ path: String, _ data: Data) throws {
        actions.append("write \(path)")
        files[path] = data
    }

    func makeExecutable(_ path: String) throws { actions.append("chmod \(path)") }

    func run(_ executable: String, _ arguments: [String]) -> CommandResult? { commands[executable] }

    func runVisibly(_ executable: String, _ arguments: [String], environment: [String: String]) -> Int32 {
        actions.append((["run", executable] + arguments).joined(separator: " "))
        return effects[executable]?(self, arguments) ?? 0
    }

    func report(_ message: String) { reports.append(message) }

    func ask(_ question: String) -> String? { answers.isEmpty ? nil : answers.removeFirst() }

    func file(_ path: String, _ text: String) { files[path] = Data(text.utf8) }

    // ── Systems ──────────────────────────────────────────────────────

    static let toolchain = "/Users/test/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain"
    static let template = "/Users/test/Library/Developer/Xcode/Templates/Project Templates/Other/ESP32 RISC-V.xctemplate"

    /// A Mac with everything ESPSwift needs installed and a board connected.
    static var workingMac: FakeSystem {
        let system = FakeSystem()
        system.file("/Users/test/.espswift/swift-toolchain", toolchain + "\n")
        system.file("/Users/test/.espswift/esp-idf/tools/cmake/version.cmake", """
            set(IDF_VERSION_MAJOR 6)
            set(IDF_VERSION_MINOR 1)
            set(IDF_VERSION_PATCH 0)
            """)
        system.file("\(template)/TemplateInfo.plist", "<string>org.swift.640202609131a</string>")
        system.file("/dev/cu.usbmodem21101", "")
        system.file("/dev/cu.Bluetooth-Incoming-Port", "")
        system.directories = [
            "/Users/test/.espswift",
            "/Users/test/.espswift/esp-idf",
            "/Users/test/.espressif/python_env/idf6.1_py3.14_env",
            "\(toolchain)/usr/lib/swift/embedded/riscv32-none-none-eabi",
            template,
        ]
        system.commands = [
            "/Users/test/.espswift/python/bin/python3": CommandResult(status: 0, output: "Python 3.14.8\n"),
            "/opt/homebrew/bin/python3.14": CommandResult(status: 0, output: "Python 3.14.8\n"),
            "/opt/homebrew/bin/cmake": CommandResult(status: 0, output: "cmake version 4.4.4\n"),
            "/opt/homebrew/bin/ninja": CommandResult(status: 0, output: "1.13.2\n"),
            "/usr/bin/git": CommandResult(status: 0, output: ""),
            "\(toolchain)/usr/bin/swiftc": CommandResult(
                status: 0, output: "Apple Swift version 6.4 (swift-6.4-RELEASE)\nTarget: arm64-apple-macosx27.0.0\n"),
        ]
        return system
    }

    /// A Mac with Homebrew and Xcode, but nothing for ESPSwift yet. ESP-IDF's
    /// and swift.org's installers create what they install when run.
    static var freshMac: FakeSystem {
        let system = FakeSystem()
        system.commands = [
            "/opt/homebrew/bin/brew": CommandResult(status: 0, output: ""),
            "/usr/bin/git": CommandResult(status: 0, output: ""),
            "/usr/bin/xcode-select": CommandResult(status: 0, output: "/Applications/Xcode.app/Contents/Developer\n"),
        ]
        system.directories = [
            "/Applications/Xcode.app/Contents/Developer/Library/Xcode/Templates/Project Templates/Other/External Build System.xctemplate",
        ]
        // The repository's files, which espswift installs.
        let resources = "/opt/homebrew/Cellar/espswift/0.1.0/share/espswift"
        system.directories.formUnion(["\(resources)/Xcode Template/ESP32 RISC-V.xctemplate", "\(resources)/scripts"])
        system.file("\(resources)/Xcode Template/ESP32 RISC-V.xctemplate/build.sh", "")
        system.file("\(resources)/Xcode Template/ESP32 RISC-V.xctemplate/TemplateInfo.plist", Self.templatePlist)
        system.file("\(resources)/Xcode Template/ESP32 RISC-V.xctemplate/scheme.xcscheme", "FilePath = \"ESPSWIFT_MONITOR_PATH\"")
        system.file("\(resources)/scripts/build.sh", "")
        system.file("\(resources)/scripts/indexing_flags.py", "")
        system.file("\(resources)/scripts/monitor_wrapper.c", "")
        system.effects["/opt/homebrew/bin/brew"] = { system, _ in
            for tool in ["python3.14", "cmake", "ninja"] {
                system.commands["/opt/homebrew/bin/\(tool)"] = CommandResult(status: 0, output: "Python 3.14.8\n")
            }
            return 0
        }
        system.effects["/usr/bin/git"] = { system, arguments in
            try? system.createDirectory(arguments.last!)
            system.file("\(arguments.last!)/tools/cmake/version.cmake",
                        "set(IDF_VERSION_MAJOR 6)\nset(IDF_VERSION_MINOR 1)\nset(IDF_VERSION_PATCH 0)\n")
            return 0
        }
        system.effects["/usr/sbin/installer"] = { system, _ in
            system.commands["\(toolchain)/usr/bin/swiftc"] = CommandResult(status: 0, output: "Swift version 6.4")
            system.file("\(toolchain)/Info.plist", """
                <?xml version="1.0" encoding="UTF-8"?>
                <plist version="1.0"><dict><key>CFBundleIdentifier</key><string>org.swift.640202609131a</string></dict></plist>
                """)
            return 0
        }
        return system
    }

    static let templatePlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict><key>Targets</key><array>
        <dict><key>Name</key><string>Indexing</string><key>SharedSettings</key><dict>
        <key>TOOLCHAINS</key><string>ESPSWIFT_SWIFT_TOOLCHAIN_ID</string></dict></dict>
        </array></dict></plist>
        """
}
