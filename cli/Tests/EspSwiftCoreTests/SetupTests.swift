@testable import EspSwiftCore
import Foundation
import Testing

@Suite struct SetupTests {
    let resources = Resources(root: "/opt/homebrew/Cellar/espswift/0.1.0/share/espswift")

    @Test func setsUpAFreshMac() throws {
        let system = FakeSystem.freshMac
        try Setup(system: system, resources: resources).run(installXcodeTemplate: true)
        let runs = system.actions.filter { $0.hasPrefix("run ") }
        #expect(runs == [
            "run /opt/homebrew/bin/brew install python@3.14 cmake",
            "run /opt/homebrew/bin/eim install --idf-versions v6.1 --target esp32c2,esp32c3,esp32c5,esp32c6,esp32c61,esp32h2,esp32p4 --non-interactive true --do-not-track true --cleanup true",
            "run /usr/bin/curl -fL https://download.swift.org/swift-6.4.0-release/xcode/swift-6.4.0-RELEASE/swift-6.4.0-RELEASE-osx.pkg -o /Users/test/.espswift/swift-6.4.0-RELEASE-osx.pkg",
            "run /usr/sbin/installer -pkg /Users/test/.espswift/swift-6.4.0-RELEASE-osx.pkg -target CurrentUserHomeDirectory",
        ])
        #expect(system.actions.contains("link /Users/test/.espswift/python/bin/python3 -> /opt/homebrew/bin/python3.14"))
        #expect(system.readFile("/Users/test/.espswift/swift-toolchain") == FakeSystem.toolchain + "\n")

        // The template, with the toolchain and the monitor filled in.
        let plist = try #require(system.readFile("\(FakeSystem.template)/TemplateInfo.plist"))
        #expect(plist.contains("org.swift.640202609131a") && !plist.contains("ESPSWIFT_SWIFT_TOOLCHAIN_ID"))
        #expect(system.readFile("\(FakeSystem.template)/scheme.xcscheme") == "FilePath = \"/Users/test/.espswift/bin/espswift\"")
        #expect(system.actions.contains("chmod \(FakeSystem.template)/build.sh"))

        #expect(!system.isDirectory("/Users/test/.espswift/scripts"))
    }

    @Test func removesEarlierVersionsScripts() throws {
        let system = FakeSystem.workingMac
        system.file("/Users/test/.espswift/scripts/build.sh", "")
        system.directories.insert("/Users/test/.espswift/scripts")
        try Setup(system: system, resources: resources).run(installXcodeTemplate: false)
        #expect(system.actions.contains("rm /Users/test/.espswift/scripts"))
    }

    @Test func leavesOutTheTemplateWhenAsked() throws {
        let system = FakeSystem.freshMac
        try Setup(system: system, resources: resources).run(installXcodeTemplate: false)
        #expect(!system.isDirectory(FakeSystem.template))
    }

    @Test func installsOnlyWhatsMissing() throws {
        let system = FakeSystem.workingMac
        try Setup(system: system, resources: resources).run(installXcodeTemplate: false)
        // No Homebrew, EIM, download or Swift installer.
        #expect(!system.actions.contains { $0.hasPrefix("run ") })
    }

    @Test func explainsHowToInstallEIM() {
        let system = FakeSystem.freshMac
        system.commands["/opt/homebrew/bin/eim"] = nil
        system.effects["/opt/homebrew/bin/eim"] = nil
        let error = #expect(throws: EspSwiftError.self) {
            try Setup(system: system, resources: resources).run(installXcodeTemplate: false)
        }
        #expect(error?.description.contains("brew install eim") == true)
    }

    @Test func usesSwiftlyWhenInstalled() throws {
        let system = FakeSystem.freshMac
        system.commands["/opt/homebrew/bin/swiftly"] = CommandResult(status: 0, output: "")
        system.effects["/opt/homebrew/bin/swiftly"] = { system, _ in
            system.commands["\(FakeSystem.toolchain)/usr/bin/swiftc"] = CommandResult(status: 0, output: "")
            return 0
        }
        try Setup(system: system, resources: resources).run(installXcodeTemplate: false)
        #expect(system.actions.contains("run /opt/homebrew/bin/swiftly install 6.4.0 --assume-yes"))
        #expect(!system.actions.contains { $0.hasPrefix("run /usr/sbin/installer") })
    }

    @Test func explainsMissingToolsWithoutHomebrew() {
        let system = FakeSystem.freshMac
        system.commands["/opt/homebrew/bin/brew"] = nil
        system.effects["/opt/homebrew/bin/brew"] = nil
        #expect(throws: EspSwiftError.self) {
            try Setup(system: system, resources: resources).run(installXcodeTemplate: false)
        }
        #expect(!system.actions.contains { $0.hasPrefix("run ") })
    }

    /// Linux with Python, CMake, Git and EIM, but no Swift.
    static func linux() -> FakeSystem {
        let system = FakeSystem.freshMac
        system.operatingSystem = .linux
        system.homeDirectory = "/home/test"
        system.commands["/usr/bin/python3"] = CommandResult(status: 0, output: "Python 3.12.3\n")
        system.commands["/usr/bin/cmake"] = CommandResult(status: 0, output: "")
        return system
    }

    @Test func needsSwiftlyOnLinux() throws {
        let system = Self.linux()
        let error = #expect(throws: EspSwiftError.self) {
            try Setup(system: system, resources: resources).run(installXcodeTemplate: false)
        }
        #expect(error?.description.contains("swiftly") == true)
        #expect(system.actions.contains("link /home/test/.espswift/python/bin/python3 -> /usr/bin/python3"))
    }

    @Test func usesTheSwiftOnPathOnLinux() throws {
        // As in Swift's Docker images: Swift 6.4.1 in /usr.
        let system = Self.linux()
        system.commands["/usr/bin/swiftc"] = CommandResult(status: 0, output: "Swift version 6.4.1 (swift-6.4.1-RELEASE)\n")
        system.directories.insert("/usr/lib/swift/embedded/riscv32-none-none-eabi")
        try Setup(system: system, resources: resources).run(installXcodeTemplate: false)
        #expect(system.readFile("/home/test/.espswift/swift-toolchain") == "/\n")
        #expect(!system.actions.contains { $0.contains("swiftly") })
    }

    @Test func findsSwiftlysNewestToolchainOnLinux() throws {
        let system = Self.linux()
        for version in ["6.3.2", "6.4.0", "6.4.1"] {
            let toolchain = "/home/test/.local/share/swiftly/toolchains/\(version)"
            system.commands["\(toolchain)/usr/bin/swiftc"] = CommandResult(status: 0, output: "Swift version \(version)\n")
            system.directories.insert("\(toolchain)/usr/lib/swift/embedded/riscv32-none-none-eabi")
        }
        #expect(Setup(system: system, resources: resources).installedSwiftToolchain()
                == "/home/test/.local/share/swiftly/toolchains/6.4.1")
    }

    @Test func needsANewEnoughPythonOnLinux() {
        let system = Self.linux()
        system.commands["/usr/bin/python3"] = CommandResult(status: 0, output: "Python 3.9.2\n")
        let error = #expect(throws: EspSwiftError.self) {
            try Setup(system: system, resources: resources).run(installXcodeTemplate: false)
        }
        #expect(error?.description.contains("3.10") == true)
    }
}

@Suite struct UninstallTests {
    @Test func removesEverythingWithAll() throws {
        let system = FakeSystem.workingMac
        system.directories.insert(FakeSystem.toolchain)
        try Uninstall(system: system).run(assumeYes: true, all: true)
        #expect(system.actions == [
            "rm /Users/test/.espswift",
            "rm \(FakeSystem.template)",
            "rm \(FakeSystem.toolchain)",
            "run /opt/homebrew/bin/eim remove v6.1",
        ])
    }

    @Test func keepsSharedItemsWithoutConfirmation() throws {
        let system = FakeSystem.workingMac
        system.directories.insert(FakeSystem.toolchain)
        try Uninstall(system: system).run(assumeYes: true, all: false)
        #expect(system.actions == ["rm /Users/test/.espswift", "rm \(FakeSystem.template)"])
    }

    @Test func asksFirstInATerminal() throws {
        let system = FakeSystem.workingMac
        system.isInteractive = true
        system.answers = ["n"]
        try Uninstall(system: system).run(assumeYes: false, all: false)
        #expect(system.actions.isEmpty)
    }

    @Test func needsYesOutsideATerminal() {
        #expect(throws: EspSwiftError.self) {
            try Uninstall(system: FakeSystem.workingMac).run(assumeYes: false, all: false)
        }
    }
}

@Suite struct ResourcesTests {
    @Test func findsHomebrewsShareFolder() throws {
        let system = FakeSystem.freshMac
        #expect(try Resources.find(system: system).root == "/opt/homebrew/Cellar/espswift/0.1.0/share/espswift")
    }

    @Test func findsTheRepositoryInDevelopment() throws {
        let system = FakeSystem()
        system.executablePath = "/Users/test/repo/cli/.build/debug/espswift"
        system.directories = ["/Users/test/repo/Xcode Template/ESP32 RISC-V.xctemplate", "/Users/test/repo/scripts"]
        #expect(try Resources.find(system: system).root == "/Users/test/repo")
    }

    @Test func findsTheRepositoryFromSetupsCopy() throws {
        // install.sh: setup copies a development build to ~/.espswift/libexec
        // and records the repository, where the copy finds the template.
        let system = FakeSystem.workingMac
        system.executablePath = "/Users/test/repo/cli/.build/release/espswift"
        system.file("/Users/test/repo/cli/.build/release/espswift", "binary")
        system.directories.insert("/Users/test/repo/Xcode Template/ESP32 RISC-V.xctemplate")
        try Setup(system: system, resources: Resources(root: "/Users/test/repo")).linkCommand()
        #expect(system.readFile("/Users/test/.espswift/libexec/espswift") == "binary")

        system.executablePath = "/Users/test/.espswift/libexec/espswift"
        #expect(try Resources.find(system: system).root == "/Users/test/repo")
    }

    @Test func prefersTheEnvironment() throws {
        let system = FakeSystem.freshMac
        system.environment["ESPSWIFT_RESOURCES"] = "/custom"
        system.directories.formUnion(["/custom/Xcode Template/ESP32 RISC-V.xctemplate", "/custom/scripts"])
        #expect(try Resources.find(system: system).root == "/custom")
    }
}
