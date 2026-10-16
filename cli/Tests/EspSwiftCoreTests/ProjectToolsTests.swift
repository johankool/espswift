@testable import EspSwiftCore
import Foundation
import Testing

@Suite struct ProjectToolsTests {
    static func system() -> FakeSystem {
        let system = ProjectTests.system()
        system.file("/Users/test/Blink/Blink/main/idf_component.yml", "dependencies:\n  espressif/led_strip: \"^3.0.0\"\n")
        system.file("/Users/test/Blink/Firmware/ESPIDF/include/ESPIDF.h", "#ifndef ESPIDF_h\n#include \"led_strip.h\"\n\n#endif /* ESPIDF_h */\n")
        return system
    }

    @Test func addsALibraryAndItsHeader() throws {
        let system = Self.system()
        let add = AddLibrary(system: system, project: try Project.find(system: system, start: "/Users/test/Blink"))
        try add.run(component: "espressif/button", header: "iot_button.h")
        #expect(system.readFile("/Users/test/Blink/Blink/main/idf_component.yml")
                == "dependencies:\n  espressif/led_strip: \"^3.0.0\"\n  espressif/button: \"*\"\n")
        #expect(system.readFile("/Users/test/Blink/Firmware/ESPIDF/include/ESPIDF.h")
                == "#ifndef ESPIDF_h\n#include \"led_strip.h\"\n\n#include \"iot_button.h\"\n\n#endif /* ESPIDF_h */\n")
        // Again: nothing changes.
        system.actions.removeAll()
        try add.run(component: "espressif/button", header: "iot_button.h")
        #expect(!system.actions.contains { $0.hasPrefix("write") })
        #expect(AddLibrary.header(for: "espressif/led_strip") == "led_strip.h")
    }

    @Test func updatesBuildShAndTheToolchain() throws {
        let system = Self.system()
        system.environment["ESPSWIFT_TEMPLATE"] = "/template"
        system.file("/template/build.sh", "new build.sh")
        system.file("/Users/test/Blink/Blink/build.sh", "old build.sh")
        system.file("\(FakeSystem.toolchain)/Info.plist", """
            <?xml version="1.0" encoding="UTF-8"?>
            <plist version="1.0"><dict><key>CFBundleIdentifier</key><string>org.swift.640202609131a</string></dict></plist>
            """)
        system.file("/Users/test/Blink/Blink.xcodeproj/project.pbxproj", "\t\t\t\tSWIFT_VERSION = 6.0;\n\t\t\t\tTOOLCHAINS = ESPSWIFT_SWIFT_TOOLCHAIN_ID;\n")
        let update = UpdateProject(system: system, project: try Project.find(system: system, start: "/Users/test/Blink"))
        #expect(try update.run())
        #expect(system.readFile("/Users/test/Blink/Blink/build.sh") == "new build.sh")
        #expect(system.readFile("/Users/test/Blink/Blink.xcodeproj/project.pbxproj")
                == "\t\t\t\tSWIFT_VERSION = 6.0;\n\t\t\t\tTOOLCHAINS = org.swift.640202609131a;\n")
        #expect(try !update.run())
        #expect(system.reports.last == "Already up to date.")
    }
}

@Suite struct DebugTests {
    static func system() -> FakeSystem {
        let system = BuildTests.system()
        system.streams["/bin/bash"] = ["PATH=/idf/openocd/bin\0IDF_PYTHON_ENV_PATH=/env\0OPENOCD_SCRIPTS=/idf/openocd/share\0"]
        system.file("/idf/openocd/bin/openocd", "")
        system.file("/idf/openocd/share/board/esp32c6-builtin.cfg", "")
        system.file("/b/project_description.json", #"{"app_elf": "Blink.elf"}"#)
        system.file("/b/Blink.elf", "")
        system.file("/Users/test/Blink/Blink/sdkconfig", "CONFIG_IDF_TARGET=\"esp32c6\"\n")
        system.file("\(FakeSystem.toolchain)/usr/bin/lldb", "")
        system.backgroundOutput["/idf/openocd/bin/openocd"] = "Info : Listening on port 3333 for gdb connections\n"
        return system
    }

    @Test func runsOpenOCDAndLLDB() throws {
        let system = Self.system()
        try Debug(system: system).run(build: LastBuild(sourceFolder: "/Users/test/Blink/Blink", buildFolder: "/b"))
        let steps = system.actions.filter { !$0.hasPrefix("mkdir") && !$0.hasPrefix("write") && !$0.hasPrefix("rm") }
        #expect(steps.first == "run /bin/bash -c set -e; . \"$IDF_PATH/export.sh\" > /dev/null 2>&1; env -0")
        #expect(Array(steps.dropFirst()) == [
            "ignore Ctrl+C",
            "start /idf/openocd/bin/openocd -f board/esp32c6-builtin.cfg",
            steps[3],
            "terminate",
            "allow Ctrl+C",
        ])
        #expect(steps[3].hasPrefix("run \(FakeSystem.toolchain)/usr/bin/lldb -o settings set target.require-hardware-breakpoint true -o target create \"/b/Blink.elf\""))
    }

    @Test func explainsChipsWithoutBuiltInJTAG() {
        let system = Self.system()
        system.file("/Users/test/Blink/Blink/sdkconfig", "CONFIG_IDF_TARGET=\"esp32c2\"\n")
        let error = #expect(throws: EspSwiftError.self) {
            try Debug(system: system).run(build: LastBuild(sourceFolder: "/Users/test/Blink/Blink", buildFolder: "/b"))
        }
        #expect(error?.description.contains("external JTAG") == true)
    }
}
