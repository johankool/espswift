/// Sets up everything ESPSwift needs: `espswift setup`. Running it again
/// installs only what's missing, and updates the Xcode template.
///
/// 1. Python, CMake and Git (with Homebrew on macOS, if missing), and EIM, Espressif's
///    ESP-IDF Installation Manager
/// 2. Python as ~/.espswift/python/bin/python3, for ESP-IDF (the pinned one
///    on macOS, the system's on Linux)
/// 3. ESP-IDF and its tools for the RISC-V chips, with EIM (in ~/.espressif)
/// 4. The Swift toolchain, with swiftly, or on macOS swift.org's installer
/// 5. The Xcode template (macOS, optional)
/// 6. espswift as ~/.espswift/bin/espswift, which projects run
public struct Setup: Sendable {
    public var system: System
    public var locations: Locations
    public var resources: Resources

    public init(system: System, resources: Resources) {
        self.system = system
        self.resources = resources
        locations = Locations(system: system)
    }

    /// The Swift toolchain macOS installs.
    public var macToolchain: String {
        "\(system.homeDirectory)/Library/Developer/Toolchains/swift-\(Pins.swift)-RELEASE.xctoolchain"
    }

    /// swiftly's toolchains folder on Linux (SWIFTLY_TOOLCHAINS_DIR, by
    /// default in the XDG data folder).
    var swiftlyToolchains: String {
        let environment = system.environment
        let data = environment["XDG_DATA_HOME"] ?? "\(system.homeDirectory)/.local/share"
        return environment["SWIFTLY_TOOLCHAINS_DIR"] ?? "\(data)/swiftly/toolchains"
    }

    /// The installed Swift toolchain that works (the folder with usr/bin/swiftc),
    /// if there is one. On Linux: a swiftc on PATH (such as in Swift's Docker
    /// images), or the newest of swiftly's toolchains of the series.
    public func installedSwiftToolchain() -> String? {
        switch system.operatingSystem {
        case .macOS:
            return system.fileExists("\(macToolchain)/usr/bin/swiftc") ? macToolchain : nil
        case .linux:
            var candidates: [String] = []
            if let swiftc = system.findExecutable("swiftc") {
                candidates.append(Self.toolchain(ofSwiftc: swiftc))
            }
            let versions = system.contentsOfDirectory(swiftlyToolchains)
                .compactMap { name in Version(name).map { (name, $0) } }
                .filter { $0.1.satisfies(Pins.swiftSeries) }
                .sorted { $0.1 > $1.1 }
            candidates += versions.map { "\(swiftlyToolchains)/\($0.0)" }
            return candidates.first { toolchain in
                guard let output = system.run(Self.path(toolchain, "usr/bin/swiftc"), ["--version"])?.output,
                      let version = VersionParser.swift(versionOutput: output) else { return false }
                return version.satisfies(Pins.swiftSeries)
                    && system.isDirectory(Self.path(toolchain, "usr/lib/swift/embedded/riscv32-none-none-eabi"))
            }
        }
    }

    /// A path in a toolchain folder, which may be "/".
    public static func path(_ toolchain: String, _ relative: String) -> String {
        toolchain.hasSuffix("/") ? toolchain + relative : "\(toolchain)/\(relative)"
    }

    /// The toolchain folder of a swiftc: /usr/bin/swiftc is in "/".
    static func toolchain(ofSwiftc swiftc: String) -> String {
        let toolchain = String(swiftc.dropLast("/usr/bin/swiftc".count))
        return toolchain.isEmpty ? "/" : toolchain
    }

    public func run(installXcodeTemplate: Bool) throws {
        try system.createDirectory(locations.espswiftHome)
        try installPrerequisites()
        try linkPython()
        try installESPIDF()
        let swiftToolchain = try installSwift()
        // build.sh and the projects' CMakeLists.txt read which toolchain to use.
        try system.writeFile(locations.swiftToolchainRecord, swiftToolchain + "\n")
        if installXcodeTemplate {
            try XcodeTemplate(system: system).install(from: resources, swiftToolchain: swiftToolchain)
        }
        try removeOldScripts()
        try linkCommand()
        system.report("")
        system.report("ESPSwift is set up. Check it with: espswift doctor")
    }

    // ── 1. Prerequisites ─────────────────────────────────────────────

    /// The Python program: the pinned version on macOS, python3 on Linux.
    var pythonProgram: String {
        system.operatingSystem == .macOS ? "python\(Pins.python)" : "python3"
    }

    /// The packages ESP-IDF's tools need on Ubuntu and Debian, from ESP-IDF's
    /// Linux setup guide (OpenOCD, for debugging, needs libusb), but Ninja,
    /// which EIM installs.
    static let linuxPackages = "git wget flex bison gperf python3 python3-pip python3-venv cmake ccache libffi-dev libssl-dev dfu-util libusb-1.0-0"

    /// The programs ESP-IDF needs, checked before downloading anything.
    func missingPrerequisites() -> [(program: String, package: String)] {
        let linux = system.operatingSystem == .linux
        return [
            (pythonProgram, linux ? "python3 python3-venv" : "python@\(Pins.python)"),
            // EIM checks for CMake, though it installs its own (and Ninja).
            ("cmake", "cmake"),
            ("git", "git"),
        ].filter { system.findExecutable($0.0) == nil }
    }

    func installPrerequisites() throws {
        let missing = missingPrerequisites()
        guard !missing.isEmpty else { return }
        let packages = missing.map(\.package)
        if system.operatingSystem == .macOS, let brew = system.findExecutable("brew") {
            system.report("Installing \(packages.joined(separator: ", ")) with Homebrew...")
            guard system.runVisibly(brew, ["install"] + packages, environment: system.environment) == 0 else {
                throw EspSwiftError("Homebrew couldn't install \(packages.joined(separator: ", ")).")
            }
            return
        }
        let how = system.operatingSystem == .macOS
            ? "Install Homebrew from https://brew.sh and run espswift setup again, or install them yourself."
            : "Install them, with the other packages ESP-IDF's tools need, with your package manager (on Ubuntu or Debian: sudo apt install \(Self.linuxPackages)), then run espswift setup again."
        throw EspSwiftError("ESP-IDF needs \(missing.map(\.program).joined(separator: ", ")), which weren't found. \(how)")
    }

    // ── 2. Python ────────────────────────────────────────────────────

    /// ESP-IDF finds its Python environment by the version of the first
    /// python3 on PATH, so ESPSwift puts its own first: the pinned one on
    /// macOS, the system's (\(Pins.minimumPython) or newer) on Linux.
    func linkPython() throws {
        guard let python = system.findExecutable(pythonProgram) else {
            throw EspSwiftError("\(pythonProgram) wasn't found.")
        }
        if system.operatingSystem == .linux {
            let version = system.run(python, ["--version"]).flatMap { VersionParser.python(versionOutput: $0.output) }
            guard let version, version >= Pins.minimumPython else {
                throw EspSwiftError("ESP-IDF needs Python \(Pins.minimumPython) or newer; \(python) is \(version.map { "\($0)" } ?? "of an unknown version").")
            }
        }
        try system.createDirectory(Resources.parent(of: locations.python))
        try system.createSymbolicLink(at: locations.python, to: python)
    }

    /// The environment for ESP-IDF's scripts: the pinned python3 first.
    var idfEnvironment: [String: String] {
        var environment = system.environment
        let pythonFolder = Resources.parent(of: locations.python)
        environment["PATH"] = ([pythonFolder] + system.searchPath).joined(separator: ":")
        return environment
    }

    // ── 3. ESP-IDF ───────────────────────────────────────────────────

    /// The pinned ESP-IDF version as EIM names it, such as v6.1 (v6.1.2 for
    /// a patch release).
    static var eimVersion: String {
        let idf = Pins.espIDF.components
        return idf[2] == 0 ? "v\(idf[0]).\(idf[1])" : "v\(idf[0]).\(idf[1]).\(idf[2])"
    }

    /// How to install EIM, which ESPSwift doesn't do itself: Homebrew asks
    /// you to trust Espressif's tap first.
    static func eimInstructions(_ operatingSystem: OperatingSystem) -> String {
        operatingSystem == .macOS
            ? "Install it with Homebrew: brew tap espressif/eim && brew trust --formula espressif/eim/eim && brew install eim"
            : "Install it from Espressif's package repository (see https://docs.espressif.com/projects/idf-im-ui/en/latest/), or with Homebrew on Linux: brew tap espressif/eim && brew install eim"
    }

    func installESPIDF() throws {
        if let installation = EIM(system: system).pinnedInstallation() {
            system.report("ESP-IDF \(Pins.espIDF) is installed (\(locations.display(installation.path, home: system.homeDirectory))).")
            return
        }
        guard let eim = system.findExecutable("eim") else {
            throw EspSwiftError("ESPSwift installs ESP-IDF with EIM, Espressif's ESP-IDF Installation Manager, which wasn't found. \(Self.eimInstructions(system.operatingSystem)) Then run espswift setup again.")
        }
        // Only the RISC-V chips' tools, which share one compiler. EIM checks
        // Python by the first python3 on PATH: ESPSwift's.
        system.report("Installing ESP-IDF \(Self.eimVersion) and its tools with EIM...")
        let status = system.runVisibly(eim, [
            "install", "--idf-versions", Self.eimVersion, "--target", Pins.chips.joined(separator: ","),
            "--non-interactive", "true", "--do-not-track", "true", "--cleanup", "true",
        ], environment: idfEnvironment)
        guard status == 0 else { throw EspSwiftError("EIM couldn't install ESP-IDF \(Self.eimVersion).") }
    }

    // ── 4. Swift ─────────────────────────────────────────────────────

    /// Installs Swift if there's no toolchain of the series yet; returns the
    /// toolchain.
    func installSwift() throws -> String {
        if let toolchain = installedSwiftToolchain() {
            system.report("Swift \(Pins.swiftSeries) is installed (\(locations.display(toolchain, home: system.homeDirectory))).")
            return toolchain
        }
        // On macOS the exact version, whose toolchain identifier the Xcode
        // template uses; on Linux, swiftly's latest of the series.
        let version = system.operatingSystem == .macOS ? "\(Pins.swift)" : "\(Pins.swiftSeries)"
        system.report("Installing Swift \(version)...")
        // swiftly, if installed (with Homebrew, or swift.org's installer in
        // ~/.swiftly), so the toolchain shows up in `swiftly list`. Without
        // --use, it doesn't change the user's active toolchain.
        let swiftly = system.findExecutable("swiftly")
            ?? ["\(system.homeDirectory)/.swiftly/bin/swiftly", "\(system.homeDirectory)/.local/share/swiftly/bin/swiftly"]
                .first(where: system.fileExists)
        if let swiftly {
            guard system.runVisibly(swiftly, ["install", version, "--assume-yes"],
                                    environment: system.environment) == 0 else {
                throw EspSwiftError("swiftly couldn't install Swift \(version).")
            }
        } else if system.operatingSystem == .macOS {
            try installSwiftPackage()
        } else {
            throw EspSwiftError("""
                Swift \(Pins.swiftSeries) is installed with swiftly, which wasn't found. \
                Install it from https://www.swift.org/install/linux/ and run espswift setup again.
                """)
        }
        guard let toolchain = installedSwiftToolchain() else {
            throw EspSwiftError("Swift \(version) was installed, but its toolchain wasn't found.")
        }
        return toolchain
    }

    /// swift.org's installer, into ~/Library/Developer/Toolchains (no
    /// administrator password needed).
    func installSwiftPackage() throws {
        let name = "swift-\(Pins.swift)-RELEASE"
        let url = "https://download.swift.org/swift-\(Pins.swift)-release/xcode/\(name)/\(name)-osx.pkg"
        let package = "\(locations.espswiftHome)/\(name)-osx.pkg"
        defer { try? system.removeItem(package) }
        guard system.runVisibly("/usr/bin/curl", ["-fL", url, "-o", package], environment: system.environment) == 0 else {
            throw EspSwiftError("Downloading Swift \(Pins.swift) from swift.org failed.")
        }
        guard system.runVisibly("/usr/sbin/installer", ["-pkg", package, "-target", "CurrentUserHomeDirectory"],
                                environment: system.environment) == 0 else {
            throw EspSwiftError("Installing Swift \(Pins.swift) failed.")
        }
    }

    // ── 7. espswift ──────────────────────────────────────────────────

    /// Where projects find espswift: their build.sh runs
    /// ~/.espswift/bin/espswift, which Xcode can find without a PATH.
    public var commandLink: String { locations.command }

    /// Links ~/.espswift/bin/espswift to the espswift that runs. For one
    /// installed with Homebrew, to Homebrew's bin/espswift, which stays the
    /// same when Homebrew updates it (the Cellar folder doesn't). One built
    /// from the repository (install.sh) is copied to ~/.espswift/libexec
    /// first, so projects don't depend on the repository.
    func linkCommand() throws {
        guard let executable = system.executablePath else { return }
        var destination = executable
        if let cellar = executable.range(of: "/Cellar/espswift/") {
            let homebrewBin = "\(executable[..<cellar.lowerBound])/bin/espswift"
            if system.fileExists(homebrewBin) { destination = homebrewBin }
        } else if executable.contains("/.build/") {
            destination = "\(locations.espswiftHome)/libexec/espswift"
            try system.createDirectory(Resources.parent(of: destination))
            try system.copyContents(of: executable, to: destination)
            try system.makeExecutable(destination)
            // The copy isn't in the repository, so it finds the template there
            // through this record.
            try system.writeFile(locations.resourcesRecord, resources.root + "\n")
        }
        try system.createDirectory(Resources.parent(of: commandLink))
        try system.createSymbolicLink(at: commandLink, to: destination)
    }

    // ── 6. Earlier versions' helper scripts ──────────────────────────

    /// espswift does what the helper scripts did; remove them.
    func removeOldScripts() throws {
        let scripts = "\(locations.espswiftHome)/scripts"
        if system.isDirectory(scripts) {
            try system.removeItem(scripts)
            system.report("Removed the helper scripts of earlier versions (espswift does what they did).")
        }
    }
}
