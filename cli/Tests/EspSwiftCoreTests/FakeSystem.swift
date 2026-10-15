import EspSwiftCore

/// A system made of a few files, folders and commands, for tests.
struct FakeSystem: System {
    var operatingSystem: OperatingSystem = .macOS
    var homeDirectory = "/Users/test"
    var environment: [String: String] = ["PATH": "/usr/bin:/bin"]
    /// Files and their contents.
    var files: [String: String] = [:]
    var directories: Set<String> = []
    /// The output of commands, by executable path.
    var commands: [String: CommandResult] = [:]

    func fileExists(_ path: String) -> Bool {
        files[path] != nil || directories.contains(path) || commands[path] != nil
    }

    func isDirectory(_ path: String) -> Bool {
        directories.contains(path)
    }

    func contentsOfDirectory(_ path: String) -> [String] {
        let prefix = path.hasSuffix("/") ? path : path + "/"
        let entries = Array(files.keys) + directories + Array(commands.keys)
        return entries.filter { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count).prefix(while: { $0 != "/" })) }
    }

    func readFile(_ path: String) -> String? {
        files[path]
    }

    func run(_ executable: String, _ arguments: [String]) -> CommandResult? {
        commands[executable]
    }

    /// A Mac with everything ESPSwift needs installed and a board connected.
    static var workingMac: FakeSystem {
        let toolchain = "/Users/test/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain"
        return FakeSystem(
            files: [
                "/Users/test/.espswift/swift-toolchain": toolchain + "\n",
                "/Users/test/.espswift/esp-idf/tools/cmake/version.cmake": """
                    set(IDF_VERSION_MAJOR 6)
                    set(IDF_VERSION_MINOR 1)
                    set(IDF_VERSION_PATCH 0)
                    """,
                "/Users/test/Library/Developer/Xcode/Templates/Project Templates/Other/ESP32 RISC-V.xctemplate/TemplateInfo.plist":
                    "<string>org.swift.640202609131a</string>",
                "/dev/cu.usbmodem21101": "",
                "/dev/cu.Bluetooth-Incoming-Port": "",
            ],
            directories: [
                "/Users/test/.espressif/python_env/idf6.1_py3.14_env",
                "\(toolchain)/usr/lib/swift/embedded/riscv32-none-none-eabi",
                "/Users/test/Library/Developer/Xcode/Templates/Project Templates/Other/ESP32 RISC-V.xctemplate",
            ],
            commands: [
                "/Users/test/.espswift/python/bin/python3": CommandResult(status: 0, output: "Python 3.14.8\n"),
                "/opt/homebrew/bin/cmake": CommandResult(status: 0, output: "cmake version 4.4.4\n"),
                "/opt/homebrew/bin/ninja": CommandResult(status: 0, output: "1.13.2\n"),
                "\(toolchain)/usr/bin/swiftc": CommandResult(
                    status: 0, output: "Apple Swift version 6.4 (swift-6.4-RELEASE)\nTarget: arm64-apple-macosx27.0.0\n"),
            ]
        )
    }
}
