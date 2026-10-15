import ArgumentParser
import EspSwiftCore
import Foundation

@main
struct EspSwift: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "espswift",
        abstract: "Embedded Swift for RISC-V based ESP32 chips.",
        version: espswiftVersion,
        subcommands: [Doctor.self, Ports.self]
    )
}

extension EspSwift {
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
