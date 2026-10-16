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

    /// ESP-IDF's environment, with the Swift toolchain first on PATH and
    /// CMake pointed at it.
    func buildEnvironment(toolchain: String) throws -> [String: String] {
        var environment = try ESPIDF(system: system).environment()
        let bin = Setup.path(toolchain, "usr/bin")
        environment["PATH"] = bin + ":" + (environment["PATH"] ?? "")
        environment["CMAKE_Swift_COMPILER"] = "\(bin)/swiftc"
        if system.operatingSystem == .macOS,
           let identifier = XcodeTemplate.bundleIdentifier(ofToolchain: toolchain, system: system) {
            environment["TOOLCHAINS"] = identifier
        }
        // main/CMakeLists.txt runs the Swift package build with espswift.
        environment["ESPSWIFT_BIN"] = system.executablePath ?? locations.command
        return environment
    }

    // ── Project checks ───────────────────────────────────────────────

    /// Warns (in Xcode's Issue navigator) when the project needs updating:
    /// its files are older than the template (ESPSWIFT_PROJECT_VERSION, set
    /// by the project's build.sh), or code completion uses another Swift
    /// toolchain than the build, e.g. after a Swift upgrade.
    func checkProject(environment: [String: String]) {
        let update = "~/.espswift/bin/espswift update --project \"\(project.folder)\""
        let version = projectVersion()
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

    /// The template version the project's files match, from the project's
    /// build.sh (`export ESPSWIFT_PROJECT_VERSION=1`), so it's known however
    /// the build is started; ESPSWIFT_PROJECT_VERSION if build.sh has none.
    func projectVersion() -> Int {
        let prefix = "export ESPSWIFT_PROJECT_VERSION="
        let line = system.readFile("\(project.sourceFolder)/build.sh")?
            .split(separator: "\n").first { $0.hasPrefix(prefix) }
        return line.flatMap { Int($0.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)) }
            ?? Int(system.environment["ESPSWIFT_PROJECT_VERSION"] ?? "") ?? 0
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
        let python = ESPIDF.python(environment)
        let command = [ESPIDF.idfPy(locations), "-C", project.sourceFolder, "-B", buildFolder,
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
    /// completion, the compiler settings of this build (CodeCompletion). A
    /// failure here doesn't fail the build.
    func setUpCodeCompletion() {
        do {
            try CodeCompletion(system: system, project: project, buildFolder: buildFolder).update()
        } catch {
            system.report("warning: Could not set up code completion. \(error)")
        }
    }
}
