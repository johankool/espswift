/// The result of one of the doctor's checks.
public struct Check: Equatable, Sendable {
    public enum Status: Sendable {
        /// In working order.
        case ok
        /// Works, but needs attention (e.g. no board connected).
        case warning
        /// Building, flashing or code completion won't work until it's fixed.
        case failed
    }

    public var name: String
    public var status: Status
    /// What was found, or what's wrong.
    public var detail: String
    /// How to fix it; nil if it's in order.
    public var fix: String?

    public init(_ name: String, _ status: Status, _ detail: String, fix: String? = nil) {
        self.name = name
        self.status = status
        self.detail = detail
        self.fix = fix
    }
}

/// Checks whether the system is in working order for ESPSwift: `espswift
/// doctor`.
public struct Doctor: Sendable {
    public var system: System
    public var locations: Locations

    /// What to run to install what's missing, until `espswift setup` exists.
    static let setupFix = "Run install.sh from the Embedded Swift Xcode Template repository."

    public init(system: System) {
        self.system = system
        locations = Locations(system: system)
    }

    /// All checks, in the order they're shown.
    public func checks() -> [Check] {
        var checks = [
            checkPython(),
            checkTool("CMake", "cmake", ["--version"]),
            checkTool("Ninja", "ninja", ["--version"]),
            checkESPIDF(),
            checkESPIDFEnvironment(),
            checkSwift(),
        ]
        if system.operatingSystem == .macOS {
            checks.append(checkXcodeTemplate())
        }
        checks.append(checkBoards())
        return checks
    }

    /// Whether all checks passed (warnings allowed).
    public static func passed(_ checks: [Check]) -> Bool {
        !checks.contains { $0.status == .failed }
    }

    // ── Checks ───────────────────────────────────────────────────────

    func checkPython() -> Check {
        let name = "Python \(Pins.python)"
        guard system.fileExists(locations.python) else {
            return Check(name, .failed, "not found at \(display(locations.python))", fix: Self.setupFix)
        }
        guard let output = system.run(locations.python, ["--version"])?.output,
              let version = VersionParser.python(versionOutput: output) else {
            return Check(name, .failed, "\(display(locations.python)) doesn't run", fix: Self.setupFix)
        }
        guard version.satisfies(Pins.python) else {
            return Check(name, .failed, "\(display(locations.python)) is Python \(version)", fix: Self.setupFix)
        }
        return Check(name, .ok, "Python \(version)")
    }

    func checkTool(_ name: String, _ executable: String, _ arguments: [String]) -> Check {
        let fix = system.operatingSystem == .macOS
            ? "Run: brew install \(executable)"
            : "Install \(executable) with your package manager."
        guard let path = system.findExecutable(executable) else {
            return Check(name, .failed, "not found", fix: fix)
        }
        let version = system.run(path, arguments).flatMap { VersionParser.firstVersion(in: $0.output) }
        return Check(name, .ok, version.map { "\($0) (\(display(path)))" } ?? display(path))
    }

    func checkESPIDF() -> Check {
        let name = "ESP-IDF \(Pins.espIDF)"
        guard let text = system.readFile("\(locations.idfPath)/tools/cmake/version.cmake") else {
            return Check(name, .failed, "not found at \(display(locations.idfPath))", fix: Self.setupFix)
        }
        guard let version = VersionParser.espIDF(versionCMake: text) else {
            return Check(name, .failed, "can't read the version of \(display(locations.idfPath))", fix: Self.setupFix)
        }
        guard version.satisfies(Pins.espIDF) else {
            return Check(name, .failed, "\(display(locations.idfPath)) is ESP-IDF \(version)", fix: Self.setupFix)
        }
        return Check(name, .ok, "\(version) (\(display(locations.idfPath)))")
    }

    /// ESP-IDF's tools install a Python environment per ESP-IDF and Python
    /// version, such as idf6.1_py3.14_env.
    func checkESPIDFEnvironment() -> Check {
        let idf = Pins.espIDF.components
        let python = Pins.python.components
        let environment = "\(locations.idfToolsPath)/python_env/idf\(idf[0]).\(idf[1])_py\(python[0]).\(python[1])_env"
        guard system.isDirectory(environment) else {
            return Check("ESP-IDF tools", .failed, "no Python environment at \(display(environment))", fix: Self.setupFix)
        }
        return Check("ESP-IDF tools", .ok, display(environment))
    }

    func checkSwift() -> Check {
        let name = "Swift \(Pins.swift)"
        // The toolchain setup installed; on Linux, else the swiftc on PATH
        // (installed with swiftly).
        let recorded = system.readFile(locations.swiftToolchainRecord)?
            .split(separator: "\n").first.map { "\($0)/usr/bin/swiftc" }
        let fallback = system.operatingSystem == .linux ? system.findExecutable("swiftc") : nil
        guard let swiftc = recorded ?? fallback, system.fileExists(swiftc) else {
            return Check(name, .failed, "no Swift toolchain for Embedded Swift found", fix: Self.setupFix)
        }
        guard let output = system.run(swiftc, ["--version"])?.output,
              let version = VersionParser.swift(versionOutput: output) else {
            return Check(name, .failed, "\(display(swiftc)) doesn't run", fix: Self.setupFix)
        }
        guard version.satisfies(Pins.swift) else {
            return Check(name, .failed, "\(display(swiftc)) is Swift \(version)", fix: Self.setupFix)
        }
        // usr/bin/swiftc → usr/lib/swift/embedded/riscv32-none-none-eabi
        let usr = String(swiftc.dropLast("/bin/swiftc".count))
        guard system.isDirectory("\(usr)/lib/swift/embedded/riscv32-none-none-eabi") else {
            return Check(name, .failed, "\(display(swiftc)) has no Embedded Swift for RISC-V", fix: Self.setupFix)
        }
        return Check(name, .ok, "\(version) (\(display(swiftc)))")
    }

    func checkXcodeTemplate() -> Check {
        guard let template = locations.xcodeTemplate, system.isDirectory(template) else {
            return Check("Xcode template", .warning, "not installed",
                         fix: "Run install.sh to use ESPSwift from Xcode.")
        }
        // install.sh fills in the identifier of the Swift toolchain, which the
        // template's Indexing target uses for code completion.
        if let plist = system.readFile("\(template)/TemplateInfo.plist"), plist.contains("ESPSWIFT_SWIFT_TOOLCHAIN_ID") {
            return Check("Xcode template", .failed, "installed without a Swift toolchain for code completion",
                         fix: Self.setupFix)
        }
        return Check("Xcode template", .ok, "ESP32 RISC-V")
    }

    func checkBoards() -> Check {
        let ports = SerialPorts.connected(system: system)
        guard !ports.isEmpty else {
            return Check("Boards", .warning, "none connected", fix: "Connect a board over USB to flash it.")
        }
        return Check("Boards", .ok, ports.joined(separator: ", "))
    }

    private func display(_ path: String) -> String {
        locations.display(path, home: system.homeDirectory)
    }
}

extension Check {
    /// The check as lines for the terminal.
    public var formatted: String {
        let symbol = switch status {
        case .ok: "✓"
        case .warning: "!"
        case .failed: "✗"
        }
        var text = "\(symbol) \(name): \(detail)"
        if let fix {
            text += "\n    \(fix)"
        }
        return text
    }
}
