import ArgumentParser
import EspSwiftCore
import Foundation

@main
struct EspSwift: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "espswift",
        abstract: "Embedded Swift for RISC-V based ESP32 chips.",
        version: espswiftVersion,
        subcommands: [
            Setup.self, Build.self, Flash.self, Monitor.self, Run.self, Doctor.self, Ports.self,
            Xcode.self, Uninstall.self, Internal.self,
        ]
    )
}

/// Runs a step, printing an EspSwiftError's message instead of a stack of
/// details, and exiting with a failure.
func reportingErrors(_ body: () throws -> Void) throws {
    do {
        try body()
    } catch let error as EspSwiftError {
        printError("Error: \(error)")
        throw ExitCode.failure
    }
}

extension EspSwift {
    struct Setup: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Installs ESP-IDF, the Swift toolchain and the tools they need.",
            discussion: """
                Running it again installs only what's missing, and updates the Xcode \
                template and the helper scripts.
                """
        )

        @Flag(inversion: .prefixedNo,
              help: "Install the Xcode template (macOS). Without this option, espswift asks.")
        var xcodeTemplate: Bool?

        func run() throws {
            let system = LiveSystem()
            try reportingErrors {
                let resources = try Resources.find(system: system)
                var installTemplate = false
                if system.operatingSystem == .macOS {
                    installTemplate = xcodeTemplate
                        ?? system.confirm("Install the Xcode template, to create ESP32 projects in Xcode?", default: true)
                } else if xcodeTemplate == true {
                    throw EspSwiftError("The Xcode template is only for macOS.")
                }
                try EspSwiftCore.Setup(system: system, resources: resources).run(installXcodeTemplate: installTemplate)
            }
        }
    }

    struct Build: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Builds the project with ESP-IDF.",
            discussion: """
                Shows the errors and warnings, in the form Xcode lists in its Issue \
                navigator, and keeps ESP-IDF's full output in the build folder \
                (log/build-output.log). Xcode runs it through the project's build.sh.
                """
        )

        @Argument(help: "build or clean (Xcode passes its action).")
        var action: String = "build"

        @Flag(help: "Clean instead of build.")
        var clean = false

        @Flag(help: "Show all of ESP-IDF's output.")
        var verbose = false

        @Option(help: "The project's folder; by default, the one espswift runs in.")
        var project: String?

        func run() throws {
            let system = LiveSystem()
            let action: EspSwiftCore.Build.Action = clean ? .clean
                : EspSwiftCore.Build.Action(rawValue: self.action.isEmpty ? "build" : self.action) ?? .build
            do {
                let project = try Project.find(system: system, start: self.project)
                try EspSwiftCore.Build(system: system, project: project, verbose: verbose).run(action)
            } catch let error as EspSwiftError {
                // As a line Xcode lists in the Issue navigator.
                print("error: \(error)")
                throw ExitCode.failure
            } catch is EspSwiftCore.Build.Failed {
                throw ExitCode.failure
            }
        }
    }

    struct Flash: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Flashes the project's last build to the board."
        )

        @Option(help: "The board's serial port; by default, the first one found.")
        var port: String?

        @Option(help: "The project's folder; by default, the one espswift runs in.")
        var project: String?

        @Flag(help: "Flash the last build of any project (what Cmd+R flashes).")
        var lastBuild = false

        func run() throws {
            let system = LiveSystem()
            try reportingErrors {
                let (source, build) = try buildToFlash(system: system, project: project, lastBuild: lastBuild)
                try EspSwiftCore.Flash(system: system).run(
                    sourceFolder: source, buildFolder: build, port: try SerialPorts.choose(port, system: system))
            }
        }
    }

    struct Monitor: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Shows the board's serial output.",
            discussion: """
                Waits for the board when it resets or is unplugged. Stop it with Ctrl+C. \
                With --idf, ESP-IDF's own monitor runs instead, in a terminal: it decodes \
                crash backtraces and sends what you type to the board.
                """
        )

        @Option(help: "The board's serial port; by default, the first one found.")
        var port: String?

        @Flag(help: "Use ESP-IDF's monitor (idf.py monitor), for a terminal.")
        var idf = false

        @Option(help: "The project's folder, for --idf; by default, the one espswift runs in.")
        var project: String?

        func run() throws {
            let system = LiveSystem()
            try reportingErrors {
                let port = try SerialPorts.choose(port, system: system)
                if idf {
                    let project = try Project.find(system: system, start: self.project)
                    try EspSwiftCore.Monitor.idfMonitor(system: system, port: port, project: project,
                                                        buildFolder: EspSwiftCore.Flash.buildFolder(for: project, system: system))
                } else {
                    try EspSwiftCore.Monitor(system: system, port: port).run()
                }
            }
        }
    }

    struct Run: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Builds the project, flashes it to the board and shows its serial output.",
            discussion: """
                Cmd+R in Xcode runs `espswift run --last-build`: Xcode has just built the \
                project, so it flashes that build.
                """
        )

        @Option(help: "The board's serial port; by default, the first one found.")
        var port: String?

        @Option(help: "The project's folder; by default, the one espswift runs in.")
        var project: String?

        @Flag(help: "Don't build; flash the last build of any project (for Cmd+R in Xcode).")
        var lastBuild = false

        func run() throws {
            let system = LiveSystem()
            do {
                if !lastBuild {
                    let project = try Project.find(system: system, start: self.project)
                    try EspSwiftCore.Build(system: system, project: project, verbose: false).run(.build)
                }
                let (source, build) = try buildToFlash(system: system, project: project, lastBuild: lastBuild)
                let port = try SerialPorts.choose(port, system: system)
                try EspSwiftCore.Flash(system: system).run(sourceFolder: source, buildFolder: build, port: port)
                try EspSwiftCore.Monitor(system: system, port: port).run()
            } catch let error as EspSwiftError {
                printError("Error: \(error)")
                throw ExitCode.failure
            } catch is EspSwiftCore.Build.Failed {
                throw ExitCode.failure
            }
        }
    }

    struct Uninstall: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Removes what espswift setup installed.",
            discussion: """
                Removes ~/.espswift and the Xcode template. Asks before removing the \
                Swift toolchain, ESP-IDF's tools and its download cache, which other \
                projects may use.
                """
        )

        @Flag(name: [.short, .long], help: "Don't ask before removing ESPSwift's own files.")
        var yes = false

        @Flag(help: "Also remove the Swift toolchain, ESP-IDF's tools and its download cache, without asking.")
        var all = false

        func run() throws {
            try reportingErrors {
                try EspSwiftCore.Uninstall(system: LiveSystem()).run(assumeYes: yes, all: all)
            }
        }
    }

    struct Xcode: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Installs or removes the Xcode template (macOS).",
            subcommands: [InstallTemplate.self, UninstallTemplate.self]
        )

        struct InstallTemplate: ParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Installs or updates the Xcode template, ESP32 RISC-V."
            )

            func run() throws {
                let system = LiveSystem()
                try reportingErrors {
                    let resources = try Resources.find(system: system)
                    let setup = EspSwiftCore.Setup(system: system, resources: resources)
                    guard let toolchain = setup.installedSwiftToolchain() else {
                        throw EspSwiftError("The Swift toolchain isn't installed. Run: espswift setup")
                    }
                    try XcodeTemplate(system: system).install(from: resources, swiftToolchain: toolchain)
                }
            }
        }

        struct UninstallTemplate: ParsableCommand {
            static let configuration = CommandConfiguration(abstract: "Removes the Xcode template.")

            func run() throws {
                let system = LiveSystem()
                try reportingErrors {
                    let removed = try XcodeTemplate(system: system).uninstall()
                    system.report(removed ? "Removed the Xcode template." : "The Xcode template isn't installed.")
                }
            }
        }
    }

    struct Doctor: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Checks whether ESP-IDF, Swift and the other tools are in working order."
        )

        func run() throws {
            let checks = EspSwiftCore.Doctor(system: LiveSystem()).checks()
            for check in checks {
                print(check.formatted)
            }
            print()
            if EspSwiftCore.Doctor.passed(checks) {
                print("Everything is in working order.")
            } else {
                print("Some checks failed; see above for how to fix them.")
                throw ExitCode.failure
            }
        }
    }

    struct Ports: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Lists the serial ports of connected boards."
        )

        @Flag(help: "Print only the port that flashing and monitoring use.")
        var first = false

        func run() throws {
            let ports = SerialPorts.connected(system: LiveSystem())
            guard !ports.isEmpty else {
                printError("No board found. Connect one over USB.")
                throw ExitCode.failure
            }
            for port in first ? [ports[0]] : ports {
                print(port)
            }
        }
    }
}

func printError(_ message: String) {
    var standardError = StandardError()
    print(message, to: &standardError)
}

struct StandardError: TextOutputStream {
    mutating func write(_ string: String) {
        FileHandle.standardError.write(Data(string.utf8))
    }
}

extension EspSwift {
    /// Commands for espswift's own use, such as from the build.
    struct Internal: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Commands espswift uses itself.",
            shouldDisplay: false,
            subcommands: [FilterBuildOutput.self]
        )

        struct FilterBuildOutput: ParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Filters ESP-IDF's build output on standard input for Xcode."
            )

            @Argument(help: "The project's source folder (with CMakeLists.txt).")
            var sourceFolder: String

            func run() throws {
                let system = LiveSystem()
                var filter = BuildOutputFilter(sourceFolder: sourceFolder, readFile: system.readFile)
                while let line = readLine(strippingNewline: true) {
                    for output in filter.process(line) { print(output) }
                }
                for output in filter.finish() { print(output) }
            }
        }
    }
}

/// The source and build folders to flash: the last build of any project
/// (--last-build), else the project's latest build.
func buildToFlash(system: System, project: String?, lastBuild: Bool) throws -> (String, String) {
    if lastBuild {
        guard let last = LastBuild.read(system: system) else {
            throw EspSwiftError("Nothing to flash yet. Build the project first (Cmd+B in Xcode, or espswift build).")
        }
        return (last.sourceFolder, last.buildFolder)
    }
    let project = try Project.find(system: system, start: project)
    return (project.sourceFolder, Flash.buildFolder(for: project, system: system))
}
