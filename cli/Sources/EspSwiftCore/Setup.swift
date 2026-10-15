/// Sets up everything ESPSwift needs: `espswift setup`. Running it again
/// installs only what's missing, and updates the Xcode template and helper
/// scripts.
///
/// 1. Python, CMake, Ninja and Git (with Homebrew on macOS, if missing)
/// 2. The pinned Python as ~/.espswift/python/bin/python3, for ESP-IDF
/// 3. ESP-IDF (in ~/.espswift/esp-idf) and its tools for the RISC-V chips
/// 4. The Swift toolchain, with swiftly, or on macOS swift.org's installer
/// 5. The Xcode template (macOS, optional)
/// 6. The helper scripts projects use, in ~/.espswift/scripts
public struct Setup: Sendable {
    public var system: System
    public var locations: Locations
    public var resources: Resources

    public init(system: System, resources: Resources) {
        self.system = system
        self.resources = resources
        locations = Locations(system: system)
    }

    /// Where the pinned Swift toolchain is installed.
    public var swiftToolchain: String {
        switch system.operatingSystem {
        case .macOS:
            return "\(system.homeDirectory)/Library/Developer/Toolchains/swift-\(Pins.swift)-RELEASE.xctoolchain"
        case .linux:
            // swiftly's toolchains folder (SWIFTLY_TOOLCHAINS_DIR, by default
            // in the XDG data folder).
            let environment = system.environment
            let data = environment["XDG_DATA_HOME"] ?? "\(system.homeDirectory)/.local/share"
            let toolchains = environment["SWIFTLY_TOOLCHAINS_DIR"] ?? "\(data)/swiftly/toolchains"
            return "\(toolchains)/\(Pins.swift)"
        }
    }

    public func run(installXcodeTemplate: Bool) throws {
        try system.createDirectory(locations.espswiftHome)
        try installPrerequisites()
        try linkPython()
        try installESPIDF()
        try installSwift()
        // build.sh and the projects' CMakeLists.txt read which toolchain to use.
        try system.writeFile(locations.swiftToolchainRecord, swiftToolchain + "\n")
        if installXcodeTemplate {
            try XcodeTemplate(system: system).install(from: resources, swiftToolchain: swiftToolchain)
        }
        try installScripts()
        system.report("")
        system.report("ESPSwift is set up. Check it with: espswift doctor")
    }

    // ── 1. Prerequisites ─────────────────────────────────────────────

    /// The programs ESP-IDF needs, checked before downloading anything.
    func missingPrerequisites() -> [(program: String, package: String)] {
        let python = "python\(Pins.python)"
        let linux = system.operatingSystem == .linux
        return [
            (python, linux ? python : "python@\(Pins.python)"),
            ("cmake", "cmake"),
            ("ninja", linux ? "ninja-build" : "ninja"),
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
            : "Install them with your package manager (for example: sudo apt install \(packages.joined(separator: " "))), then run espswift setup again."
        throw EspSwiftError("ESP-IDF needs \(missing.map(\.program).joined(separator: ", ")), which weren't found. \(how)")
    }

    // ── 2. Python ────────────────────────────────────────────────────

    /// ESP-IDF finds its Python environment by the version of the first
    /// python3 on PATH, so ESPSwift puts the pinned one first.
    func linkPython() throws {
        guard let python = system.findExecutable("python\(Pins.python)") else {
            throw EspSwiftError("Python \(Pins.python) wasn't found.")
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

    func installESPIDF() throws {
        let idf = locations.idfPath
        let tag = "v\(Pins.espIDF.components[0]).\(Pins.espIDF.components[1])"
        if system.isDirectory(idf) {
            // An existing ESP-IDF is never replaced automatically.
            let installed = system.readFile("\(idf)/tools/cmake/version.cmake").flatMap(VersionParser.espIDF)
            if let installed, installed.satisfies(Pins.espIDF) {
                system.report("ESP-IDF \(installed) is installed.")
            } else {
                system.report("""
                    Warning: ESP-IDF in \(idf) is \(installed.map(String.init(describing:)) ?? "of an unknown version"), \
                    not \(Pins.espIDF). To switch, remove that folder and run espswift setup again.
                    """)
            }
        } else {
            system.report("Downloading ESP-IDF \(tag)...")
            guard let git = system.findExecutable("git") else { throw EspSwiftError("Git wasn't found.") }
            // Only the release, without its history, which is much smaller.
            let status = system.runVisibly(git, [
                "clone", "--recursive", "--branch", tag, "--depth", "1", "--shallow-submodules",
                "https://github.com/espressif/esp-idf.git", idf,
            ], environment: system.environment)
            guard status == 0 else { throw EspSwiftError("Downloading ESP-IDF failed.") }
        }

        // ESP-IDF's tools and Python environment. This also runs when ESP-IDF
        // was installed already: it installs only what's missing. Only the
        // RISC-V chips' tools, which share one compiler.
        system.report("Installing ESP-IDF's tools...")
        let status = system.runVisibly("\(idf)/install.sh", [Pins.chips.joined(separator: ",")], environment: idfEnvironment)
        guard status == 0 else { throw EspSwiftError("Installing ESP-IDF's tools failed.") }
    }

    // ── 4. Swift ─────────────────────────────────────────────────────

    func installSwift() throws {
        let swiftc = "\(swiftToolchain)/usr/bin/swiftc"
        guard !system.fileExists(swiftc) else {
            system.report("Swift \(Pins.swift) is installed.")
            return
        }
        system.report("Installing Swift \(Pins.swift)...")
        // swiftly, if installed (with Homebrew, or swift.org's installer in
        // ~/.swiftly), so the toolchain shows up in `swiftly list`. Without
        // --use, it doesn't change the user's active toolchain.
        let swiftly = system.findExecutable("swiftly")
            ?? ["\(system.homeDirectory)/.swiftly/bin/swiftly", "\(system.homeDirectory)/.local/share/swiftly/bin/swiftly"]
                .first(where: system.fileExists)
        if let swiftly {
            guard system.runVisibly(swiftly, ["install", "\(Pins.swift)", "--assume-yes"],
                                    environment: system.environment) == 0 else {
                throw EspSwiftError("swiftly couldn't install Swift \(Pins.swift).")
            }
        } else if system.operatingSystem == .macOS {
            try installSwiftPackage()
        } else {
            throw EspSwiftError("""
                Swift \(Pins.swift) is installed with swiftly, which wasn't found. \
                Install it from https://www.swift.org/install/linux/ and run espswift setup again.
                """)
        }
        guard system.fileExists(swiftc) else {
            throw EspSwiftError("Swift \(Pins.swift) wasn't installed at \(swiftToolchain).")
        }
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

    // ── 6. Helper scripts ────────────────────────────────────────────

    /// The scripts projects use (build.sh calls ~/.espswift/scripts/build.sh),
    /// until espswift's commands replace them.
    func installScripts() throws {
        let destination = "\(locations.espswiftHome)/scripts"
        try system.createDirectory(destination)
        for file in system.contentsOfDirectory(resources.scripts) where file.hasSuffix(".sh") || file.hasSuffix(".py") {
            try system.copyContents(of: "\(resources.scripts)/\(file)", to: "\(destination)/\(file)")
            try system.makeExecutable("\(destination)/\(file)")
        }
        // Xcode's Run scheme can only start a native program, so a small one
        // starts run.sh.
        if system.operatingSystem == .macOS {
            let status = system.runVisibly("/usr/bin/clang", [
                "-o", "\(destination)/monitor", "\(resources.scripts)/monitor_wrapper.c",
            ], environment: system.environment)
            guard status == 0 else { throw EspSwiftError("Compiling the monitor wrapper failed.") }
        }
        system.report("Installed the helper scripts in \(destination).")
    }
}
