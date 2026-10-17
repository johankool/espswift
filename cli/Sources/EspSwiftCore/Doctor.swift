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

    /// What to run to install what's missing.
    static let setupFix = "Run: espswift setup"

    public init(system: System) {
        self.system = system
        locations = Locations(system: system)
    }

    /// All checks, in the order they're shown.
    public func checks() -> [Check] {
        var checks = [
            checkPython(),
            checkEIM(),
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

    /// The Python version ESPSwift uses, if it runs.
    func pythonVersion() -> Version? {
        system.run(locations.python, ["--version"]).flatMap { VersionParser.python(versionOutput: $0.output) }
    }

    func checkPython() -> Check {
        // macOS: the pinned version; Linux: the system's, if new enough.
        let pinned = system.operatingSystem == .macOS
        let name = pinned ? "Python \(Pins.python)" : "Python"
        guard system.fileExists(locations.python) else {
            return Check(name, .failed, "not found at \(display(locations.python))", fix: Self.setupFix)
        }
        guard let version = pythonVersion() else {
            return Check(name, .failed, "\(display(locations.python)) doesn't run", fix: Self.setupFix)
        }
        guard pinned ? version.satisfies(Pins.python) : version >= Pins.minimumPython else {
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

    /// EIM, which installs ESP-IDF; only needed for espswift setup.
    func checkEIM() -> Check {
        guard let eim = system.findExecutable("eim") else {
            return Check("EIM", .warning, "not found; espswift setup needs it to install ESP-IDF",
                         fix: Setup.eimInstructions(system.operatingSystem))
        }
        let version = system.run(eim, ["--version"]).flatMap { VersionParser.firstVersion(in: $0.output) }
        return Check("EIM", .ok, version.map { "\($0) (\(display(eim)))" } ?? display(eim))
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

    /// ESP-IDF's environment (EIM's activation script, or export.sh) and
    /// the Python environment in it, which runs idf.py.
    func checkESPIDFEnvironment() -> Check {
        let name = "ESP-IDF tools"
        guard let environment = try? ESPIDF(system: system).environment() else {
            let fix = EIM(system: system).pinnedInstallation().map { "Run: eim fix \($0.name)" } ?? Self.setupFix
            return Check(name, .failed, "ESP-IDF's environment can't be set up", fix: fix)
        }
        let python = ESPIDF.python(environment)
        guard let version = system.run(python, ["--version"]).flatMap({ VersionParser.python(versionOutput: $0.output) }) else {
            // A Python environment breaks when the Python it was made with
            // is removed, e.g. by a Homebrew upgrade.
            let fix = EIM(system: system).pinnedInstallation().map { "Run: eim fix \($0.name)" } ?? Self.setupFix
            return Check(name, .failed, "\(display(python)) doesn't run", fix: fix)
        }
        return Check(name, .ok, "Python \(version) (\(display(environment["IDF_PYTHON_ENV_PATH"] ?? python)))")
    }

    func checkSwift() -> Check {
        let name = "Swift \(Pins.swiftSeries)"
        // The toolchain setup installed; on Linux, else the swiftc on PATH
        // (installed with swiftly).
        let recorded = system.readFile(locations.swiftToolchainRecord)?
            .split(separator: "\n").first.map { Setup.path(String($0), "usr/bin/swiftc") }
        let fallback = system.operatingSystem == .linux ? system.findExecutable("swiftc") : nil
        guard let swiftc = recorded ?? fallback, system.fileExists(swiftc) else {
            return Check(name, .failed, "no Swift toolchain for Embedded Swift found", fix: Self.setupFix)
        }
        guard let output = system.run(swiftc, ["--version"])?.output,
              let version = VersionParser.swift(versionOutput: output) else {
            return Check(name, .failed, "\(display(swiftc)) doesn't run", fix: Self.setupFix)
        }
        guard version.satisfies(Pins.swiftSeries) else {
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
                         fix: "To use ESPSwift from Xcode, run: espswift xcode install-template")
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
