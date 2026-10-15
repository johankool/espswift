@testable import EspSwiftCore
import Testing

@Suite struct ProjectTests {
    /// A project folder with its source folder, Blink/Blink.
    static func system() -> FakeSystem {
        let system = FakeSystem.workingMac
        for file in ["CMakeLists.txt", "main/CMakeLists.txt", "sdkconfig.defaults"] {
            system.file("/Users/test/Blink/Blink/\(file)", "")
        }
        system.file("/Users/test/Blink/Firmware/Firmware.swift", "")
        system.directories.formUnion(["/Users/test/Blink", "/Users/test/Blink/Blink", "/Users/test/Blink/Firmware"])
        return system
    }

    @Test func findsTheProjectFromItsFolders() throws {
        let system = Self.system()
        let expected = Project(folder: "/Users/test/Blink", sourceFolder: "/Users/test/Blink/Blink")
        for folder in ["/Users/test/Blink", "/Users/test/Blink/Blink", "/Users/test/Blink/Blink/main", "/Users/test/Blink/Firmware"] {
            #expect(try Project.find(system: system, start: folder) == expected)
        }
        #expect(throws: EspSwiftError.self) { try Project.find(system: system, start: "/Users/test") }
    }

    @Test func usesXcodesSettings() throws {
        let system = Self.system()
        system.environment["PROJECT_DIR"] = "/Users/test/Blink"
        system.environment["PROJECT_NAME"] = "Blink"
        #expect(try Project.find(system: system).sourceFolder == "/Users/test/Blink/Blink")
    }

    @Test func readsTheChip() {
        #expect(Project.chip(inConfig: "# Chip\nCONFIG_IDF_TARGET=\"esp32c3\"\nCONFIG_X=y\n") == "esp32c3")
        #expect(Project.chip(inConfig: nil) == nil)
    }
}

@Suite struct BuildTests {
    /// The test project, with ESP-IDF's environment (export.sh's) and a build
    /// whose output has an error.
    static func system() -> FakeSystem {
        let system = ProjectTests.system()
        system.file("/Users/test/Blink/Blink/sdkconfig.defaults", "CONFIG_IDF_TARGET=\"esp32c6\"\n")
        system.streams["/bin/bash"] = ["PATH=/idf/tools\0IDF_PYTHON_ENV_PATH=/Users/test/.espressif/python_env/idf6.1_py3.14_env\0"]
        system.streams["/Users/test/.espressif/python_env/idf6.1_py3.14_env/bin/python"] = [
            "-- Configuring done",
            "/Users/test/Blink/Firmware/Firmware.swift:3:1: error: oops",
        ]
        // idf.py creates the build folder (-B).
        system.effects["/Users/test/.espressif/python_env/idf6.1_py3.14_env/bin/python"] = { system, arguments in
            try? system.createDirectory(arguments[arguments.firstIndex(of: "-B")! + 1])
            return 0
        }
        return system
    }

    @Test func setsTheTargetBuildsAndRecordsTheBuild() throws {
        let system = Self.system()
        let project = try Project.find(system: system, start: "/Users/test/Blink")
        try Build(system: system, project: project, verbose: false).run(.build)

        let idf = "run /Users/test/.espressif/python_env/idf6.1_py3.14_env/bin/python /Users/test/.espswift/esp-idf/tools/idf.py -C /Users/test/Blink/Blink -B /Users/test/Blink/Blink/build -D CMAKE_COLOR_DIAGNOSTICS=OFF"
        #expect(system.actions.filter { $0.hasPrefix("run ") } == [
            "run /bin/bash -c set -e; . \"$IDF_PATH/export.sh\" > /dev/null 2>&1; env -0",
            "\(idf) set-target esp32c6",
            "\(idf) build",
        ])
        // Errors pass the filter; the rest is in the log.
        #expect(system.reports.contains("/Users/test/Blink/Firmware/Firmware.swift:3:1: error: oops"))
        #expect(!system.reports.contains("-- Configuring done"))
        #expect(system.readFile("/Users/test/Blink/Blink/build/log/build-output.log")?.contains("-- Configuring done") == true)
        #expect(system.readFile("/Users/test/.espswift/last-build") == "/Users/test/Blink/Blink\n/Users/test/Blink/Blink/build\n")
        // The project has no version stamp (its build.sh sets it).
        #expect(system.reports.contains { $0.hasPrefix("warning: This project was created with an older version") })
    }

    @Test func buildsInXcodesDerivedData() throws {
        let system = Self.system()
        system.environment["TARGET_TEMP_DIR"] = "/Users/test/DerivedData/Blink.build"
        system.environment["ESPSWIFT_PROJECT_VERSION"] = "1"
        system.file("/Users/test/Blink/Blink/sdkconfig", "CONFIG_IDF_TARGET=\"esp32c6\"\n")
        let build = Build(system: system, project: try Project.find(system: system, start: "/Users/test/Blink"), verbose: false)
        #expect(build.buildFolder == "/Users/test/DerivedData/Blink.build/esp-idf")
        try build.run(.clean)
        // The chip is set already; no warnings.
        #expect(system.actions.filter { $0.hasPrefix("run ") }.last?.hasSuffix(" fullclean") == true)
        #expect(!system.actions.contains { $0.contains("set-target") })
        #expect(!system.reports.contains { $0.hasPrefix("warning:") })
    }

    @Test func failsAfterShowingTheErrors() throws {
        let system = Self.system()
        system.effects["/Users/test/.espressif/python_env/idf6.1_py3.14_env/bin/python"] = { system, arguments in
            try? system.createDirectory(arguments[arguments.firstIndex(of: "-B")! + 1])
            return arguments.last == "build" ? 1 : 0
        }
        let project = try Project.find(system: system, start: "/Users/test/Blink")
        #expect(throws: Build.Failed.self) {
            try Build(system: system, project: project, verbose: false).run(.build)
        }
    }

    @Test func linksItselfForProjects() throws {
        let system = FakeSystem.freshMac
        system.commands["/opt/homebrew/bin/espswift"] = CommandResult(status: 0, output: "")
        let setup = Setup(system: system, resources: Resources(root: "/opt/homebrew/Cellar/espswift/0.1.0/share/espswift"))
        try setup.linkCommand()
        #expect(system.actions.contains("link /Users/test/.espswift/bin/espswift -> /opt/homebrew/bin/espswift"))
    }
}
