@testable import EspSwiftCore
import Testing

@Suite struct VersionTests {
    @Test func readsVersions() {
        #expect(Version("6.4.0") == Version(6, 4, 0))
        #expect(Version("v6.1")?.components == [6, 1])
        #expect(Version("3.14.8rc1")?.components == [3, 14, 8])
        #expect(Version("release") == nil)
    }

    @Test func satisfiesPinsUpToTheirPrecision() {
        #expect(Version(3, 14, 8).satisfies(Pins.python))
        #expect(!Version(3, 15, 0).satisfies(Pins.python))
        #expect(Version(6, 4).satisfies(Pins.swift))  // swiftc reports 6.4 for 6.4.0
        #expect(!Version(6, 4, 1).satisfies(Pins.swift))
        #expect(Version(6, 4, 1).satisfies(Pins.swiftSeries))
        #expect(!Version(6, 5).satisfies(Pins.swiftSeries))
    }

    @Test func comparesVersions() {
        #expect(Version(6, 1) < Version(6, 2))
        #expect(Version(6, 4) == Version(6, 4, 0))
    }

    @Test func readsToolOutput() {
        let cmake = """
            set(IDF_VERSION_MAJOR 6)
            set(IDF_VERSION_MINOR 1)
            set(IDF_VERSION_PATCH 2)

            set(ENV{IDF_VERSION} "${IDF_VERSION_MAJOR}.${IDF_VERSION_MINOR}.${IDF_VERSION_PATCH}")
            """
        #expect(VersionParser.espIDF(versionCMake: cmake) == Version(6, 1, 2))
        #expect(VersionParser.swift(versionOutput: "Apple Swift version 6.4 (swift-6.4-RELEASE)") == Version(6, 4))
        #expect(VersionParser.swift(versionOutput: "Swift version 6.4.1 (swift-6.4.1-RELEASE)\nTarget: x86_64-unknown-linux-gnu")
                == Version(6, 4, 1))
        #expect(VersionParser.python(versionOutput: "Python 3.14.8\n") == Version(3, 14, 8))
        #expect(VersionParser.firstVersion(in: "cmake version 4.4.4\n\nCMake suite maintained") == Version(4, 4, 4))
        #expect(VersionParser.firstVersion(in: "1.13.2\n") == Version(1, 13, 2))
    }
}

@Suite struct SerialPortTests {
    @Test func findsBoardsOnMacOS() {
        let devices = ["cu.Bluetooth-Incoming-Port", "cu.usbserial-0001", "tty.usbmodem21101", "cu.usbmodem21101", "null"]
        #expect(SerialPorts.ports(in: devices, on: .macOS) == ["/dev/cu.usbmodem21101", "/dev/cu.usbserial-0001"])
    }

    @Test func findsBoardsOnLinux() {
        let devices = ["ttyS0", "ttyUSB0", "ttyACM1", "ttyACM0", "tty"]
        #expect(SerialPorts.ports(in: devices, on: .linux) == ["/dev/ttyACM0", "/dev/ttyACM1", "/dev/ttyUSB0"])
    }
}

@Suite struct DoctorTests {
    @Test func passesOnAWorkingMac() {
        let checks = Doctor(system: FakeSystem.workingMac).checks()
        #expect(checks.allSatisfy { $0.status == .ok }, "\(checks.filter { $0.status != .ok })")
        #expect(checks.map(\.name) == [
            "Python 3.14", "CMake", "Ninja", "ESP-IDF 6.1.0", "ESP-IDF tools", "Swift 6.4", "Xcode template", "Boards",
        ])
        #expect(checks.last?.detail == "/dev/cu.usbmodem21101")
    }

    @Test func failsWithoutESPIDF() {
        let system = FakeSystem.workingMac
        system.files["/Users/test/.espswift/esp-idf/tools/cmake/version.cmake"] = nil
        let checks = Doctor(system: system).checks()
        let check = checks.first { $0.name.hasPrefix("ESP-IDF 6") }
        #expect(check?.status == .failed)
        #expect(check?.detail == "not found at ~/.espswift/esp-idf")
        #expect(check?.fix != nil)
        #expect(!Doctor.passed(checks))
    }

    @Test func failsOnANewerPython() {
        let system = FakeSystem.workingMac
        system.commands["/Users/test/.espswift/python/bin/python3"] = CommandResult(status: 0, output: "Python 3.15.0\n")
        let check = Doctor(system: system).checks().first { $0.name.hasPrefix("Python") }
        #expect(check?.status == .failed)
        #expect(check?.detail == "~/.espswift/python/bin/python3 is Python 3.15.0")
    }

    @Test func failsWithoutEmbeddedSwiftForRISCV() {
        let system = FakeSystem.workingMac
        system.directories = system.directories.filter { !$0.hasSuffix("riscv32-none-none-eabi") }
        let check = Doctor(system: system).checks().first { $0.name.hasPrefix("Swift") }
        #expect(check?.status == .failed)
    }

    @Test func warnsWithoutABoard() {
        let system = FakeSystem.workingMac
        system.files["/dev/cu.usbmodem21101"] = nil
        let checks = Doctor(system: system).checks()
        #expect(checks.last?.status == .warning)
        #expect(Doctor.passed(checks))
    }

    @Test func skipsTheXcodeTemplateOnLinux() {
        let system = FakeSystem.workingMac
        system.operatingSystem = .linux
        #expect(!Doctor(system: system).checks().contains { $0.name == "Xcode template" })
    }

    @Test func formatsChecks() {
        #expect(Check("CMake", .ok, "4.4.4").formatted == "✓ CMake: 4.4.4")
        #expect(Check("CMake", .failed, "not found", fix: "Run: brew install cmake").formatted
                == "✗ CMake: not found\n    Run: brew install cmake")
    }
}
