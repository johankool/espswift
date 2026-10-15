import Foundation

/// Builds a project with ESP-IDF: `espswift build`, which Xcode runs (through
/// the project's build.sh) when you press Build (Cmd+B) or Clean.
///
/// ESP-IDF builds the firmware: its C code, the bootloader, and (through
/// main/CMakeLists.txt) the Swift package. The build doesn't flash the
/// board; Cmd+R does.
public struct Build: Sendable {
    /// The build failed, and its errors were shown already.
    public struct Failed: Error {}

    public enum Action: String, Sendable {
        case build
        case clean
    }

    public var system: System
    public var project: Project
    public var locations: Locations
    /// Show all of ESP-IDF's output, not just the errors and warnings.
    public var verbose: Bool

    /// The version of the template a project's files must match; projects
    /// older than this get a warning.
    static let currentProjectVersion = 1

    public init(system: System, project: Project, verbose: Bool) {
        self.system = system
        self.project = project
        self.verbose = verbose
        locations = Locations(system: system)
    }

    /// ESP-IDF's build folder: in Xcode's DerivedData (this target's
    /// intermediates, TARGET_TEMP_DIR), so Clean Build Folder and deleting
    /// DerivedData remove it; outside Xcode, ESP-IDF's usual ./build.
    public var buildFolder: String {
        if let temp = system.environment["TARGET_TEMP_DIR"], !temp.isEmpty {
            return "\(temp)/esp-idf"
        }
        return "\(project.sourceFolder)/build"
    }

    /// The helper scripts (code completion; the Swift package build, which
    /// main/CMakeLists.txt runs): ESPSWIFT_SCRIPTS, or the installed ones.
    var scripts: String {
        system.environment["ESPSWIFT_SCRIPTS"] ?? "\(locations.espswiftHome)/scripts"
    }

    public func run(_ action: Action) throws {
        system.report("=================================================")
        system.report(" ESP32 Embedded Swift Build")
        system.report("=================================================")

        let toolchain = try swiftToolchain()
        system.report("Using toolchain: \(toolchain)")
        let environment = try buildEnvironment(toolchain: toolchain)
        checkProject(environment: environment)
        system.report("Build directory: \(buildFolder)")

        try setTargetIfNeeded(environment: environment)

        switch action {
        case .clean:
            system.report("Cleaning project...")
            try idf(["fullclean"], environment: environment)
        case .build:
            system.report("Building project...")
            try idf(["build"], environment: environment)
            setUpCodeCompletion()
            // Cmd+R builds, then flashes the firmware this records: the
            // source folder and the build folder. ESPSWIFT_BUILD_ONLY=1 (for
            // tests) leaves it as it is.
            if system.environment["ESPSWIFT_BUILD_ONLY"] != "1" {
                try system.writeFile("\(locations.espswiftHome)/last-build", "\(project.sourceFolder)\n\(buildFolder)\n")
            }
        }

        system.report("=================================================")
        system.report(action == .clean ? " Clean Complete" : " Build Complete")
        system.report("=================================================")
    }

    // ── Environment ──────────────────────────────────────────────────

    /// The Swift toolchain setup installed (or ESPSWIFT_TOOLCHAIN).
    func swiftToolchain() throws -> String {
        let toolchain = system.environment["ESPSWIFT_TOOLCHAIN"]
            ?? system.readFile(locations.swiftToolchainRecord)?.split(separator: "\n").first.map(String.init)
        guard let toolchain, system.fileExists(Setup.path(toolchain, "usr/bin/swiftc")) else {
            throw EspSwiftError("The Swift toolchain wasn't found. Run: espswift setup")
        }
        return toolchain
    }

    /// ESP-IDF's environment, as its export.sh sets it up, with the Swift
    /// toolchain first on PATH and CMake pointed at it.
    func buildEnvironment(toolchain: String) throws -> [String: String] {
        guard system.isDirectory(locations.idfPath) else {
            throw EspSwiftError("ESP-IDF wasn't found at \(locations.idfPath). Run: espswift setup")
        }
        // Xcode's PATH doesn't include Homebrew; ESP-IDF finds its Python
        // environment by the first python3 on PATH, ESPSwift's.
        var base = system.environment
        base["IDF_PATH"] = locations.idfPath
        base["PATH"] = ([Resources.parent(of: locations.python)] + system.searchPath).joined(separator: ":")
        let script = "set -e; . \"$IDF_PATH/export.sh\" > /dev/null 2>&1; env -0"
        var output = Data()
        let status = system.runStreaming("/bin/bash", ["-c", script], environment: base) { line in
            output.append(contentsOf: Array(line.utf8) + [10])
        }
        guard status == 0 else {
            let messages = system.run("/bin/bash", ["-c", ". \"\(locations.idfPath)/export.sh\""])?.output ?? ""
            throw EspSwiftError("Setting up ESP-IDF failed. Run: espswift doctor\n\(messages)")
        }
        // env -0 separates the variables with NUL. Joining the lines again
        // gives its output back, plus a newline at the end.
        var environment: [String: String] = [:]
        let text = String(decoding: output.dropLast(), as: UTF8.self)
        for entry in text.split(separator: "\0") {
            guard let equals = entry.firstIndex(of: "=") else { continue }
            environment[String(entry[..<equals])] = String(entry[entry.index(after: equals)...])
        }
        guard environment["IDF_PYTHON_ENV_PATH"] != nil else {
            throw EspSwiftError("ESP-IDF's environment wasn't set up. Run: espswift doctor")
        }

        let bin = Setup.path(toolchain, "usr/bin")
        environment["PATH"] = bin + ":" + (environment["PATH"] ?? "")
        environment["CMAKE_Swift_COMPILER"] = "\(bin)/swiftc"
        if system.operatingSystem == .macOS,
           let identifier = XcodeTemplate.bundleIdentifier(ofToolchain: toolchain, system: system) {
            environment["TOOLCHAINS"] = identifier
        }
        // main/CMakeLists.txt runs the Swift package build from here.
        environment["ESPSWIFT_SCRIPTS"] = scripts
        return environment
    }

    // ── Project checks ───────────────────────────────────────────────

    /// Warns (in Xcode's Issue navigator) when the project needs updating:
    /// its files are older than the template (ESPSWIFT_PROJECT_VERSION, set
    /// by the project's build.sh), or code completion uses another Swift
    /// toolchain than the build, e.g. after a Swift upgrade.
    func checkProject(environment: [String: String]) {
        let update = "~/.espswift/scripts/update_project.sh \"\(project.folder)\""
        let version = Int(system.environment["ESPSWIFT_PROJECT_VERSION"] ?? "") ?? 0
        if version < Self.currentProjectVersion {
            system.report("warning: This project was created with an older version of the ESPSwift template. To update it, run in Terminal: \(update)")
        }
        let pbxproj = "\(project.folder)/\(project.name).xcodeproj/project.pbxproj"
        if let text = system.readFile(pbxproj), let toolchain = environment["TOOLCHAINS"] {
            let used = Set(text.split(separator: "\n").compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("TOOLCHAINS = "), trimmed.hasSuffix(";") else { return nil }
                return String(trimmed.dropFirst("TOOLCHAINS = ".count).dropLast())
            })
            if let other = used.first(where: { $0 != toolchain }) {
                system.report("warning: Code completion uses another Swift toolchain (\(other)) than the build (\(toolchain)). To update the project, run in Terminal: \(update)")
            }
        }
    }

    // ── Chip ─────────────────────────────────────────────────────────

    /// Sets ESP-IDF's target on the first build (which creates sdkconfig)
    /// and whenever the chip in sdkconfig.defaults changed. Setting the
    /// target recreates sdkconfig from sdkconfig.defaults; the previous one
    /// is kept as sdkconfig.old.
    func setTargetIfNeeded(environment: [String: String]) throws {
        let chip = Project.chip(inConfig: system.readFile("\(project.sourceFolder)/sdkconfig.defaults")) ?? "esp32c6"
        let configured = Project.chip(inConfig: system.readFile("\(project.sourceFolder)/sdkconfig"))
        guard configured != chip else { return }
        // Setting the target first cleans the build folder, which idf.py
        // refuses to do if it isn't a CMake build folder. A build that failed
        // before CMake configured the project leaves one behind, holding only
        // idf.py's logs; remove it, so the build doesn't stay stuck.
        if system.isDirectory(buildFolder), !system.fileExists("\(buildFolder)/CMakeCache.txt"),
           system.contentsOfDirectory(buildFolder).allSatisfy({ $0 == "log" }) {
            system.report("Removing an unconfigured build directory left by a failed build...")
            try system.removeItem(buildFolder)
        }
        system.report("Setting target to \(chip)...")
        try idf(["set-target", chip], environment: environment)
    }

    // ── idf.py ───────────────────────────────────────────────────────

    /// Runs idf.py on the build folder. Its output is filtered for Xcode
    /// (BuildOutputFilter): errors and warnings show in the Issue navigator,
    /// and the rest is mostly left out. The full output is kept in the build
    /// folder, in log/build-output.log. With --verbose (or ESPSWIFT_VERBOSE=1,
    /// e.g. a user-defined build setting of the project's target) it's all
    /// shown.
    ///
    /// Colored output is turned off: idf.py removes the escape codes when not
    /// writing to a terminal, which leaves part of them behind in some
    /// compiler messages.
    func idf(_ arguments: [String], environment: [String: String]) throws {
        let python = "\(environment["IDF_PYTHON_ENV_PATH"] ?? "")/bin/python"
        let command = ["\(locations.idfPath)/tools/idf.py", "-C", project.sourceFolder, "-B", buildFolder,
                       "-D", "CMAKE_COLOR_DIAGNOSTICS=OFF"] + arguments
        if verbose || system.environment["ESPSWIFT_VERBOSE"] == "1" {
            guard system.runVisibly(python, command, environment: environment) == 0 else {
                throw EspSwiftError("idf.py \(arguments[0]) failed.")
            }
            return
        }

        var filter = BuildOutputFilter(sourceFolder: project.sourceFolder, readFile: system.readFile)
        var log = ""
        let status = system.runStreaming(python, command, environment: environment) { line in
            log += line + "\n"
            filter.process(line).forEach(system.report)
        }
        filter.finish().forEach(system.report)

        // The full output goes into the build folder, if there is one (after
        // a clean, there isn't).
        var logFile: String?
        if system.isDirectory(buildFolder) {
            try system.createDirectory("\(buildFolder)/log")
            try system.writeFile("\(buildFolder)/log/build-output.log", log)
            logFile = "\(buildFolder)/log/build-output.log"
        }
        guard status == 0 else {
            let place = logFile.map { " See its full output in \($0)" } ?? ""
            // An error Xcode lists, if the filter passed on none.
            guard filter.errorCount > 0 else {
                throw EspSwiftError("idf.py \(arguments[0]) failed.\(place)")
            }
            if let logFile { system.report("The full output of idf.py is in \(logFile)") }
            throw Failed()
        }
    }

    // ── Code completion ──────────────────────────────────────────────

    /// Gives the project's Indexing target, which Xcode uses for code
    /// completion, the compiler settings of this build (setup_indexing.sh).
    /// A failure here doesn't fail the build.
    func setUpCodeCompletion() {
        let script = "\(scripts)/setup_indexing.sh"
        guard system.fileExists(script) else { return }
        let result = system.run("/bin/bash", [script, project.sourceFolder, buildFolder])
        if result?.status != 0 {
            system.report("warning: Could not set up code completion. \(result?.output ?? "")")
        }
    }
}
