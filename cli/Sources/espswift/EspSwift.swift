import ArgumentParser
import EspSwiftCore
import Foundation

@main
struct EspSwift: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "espswift",
        abstract: "Embedded Swift for RISC-V based ESP32 chips.",
        version: espswiftVersion,
        subcommands: [Setup.self, Doctor.self, Ports.self, Xcode.self, Uninstall.self]
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
