@testable import EspSwiftCore
import Foundation
import Testing

@Suite struct NewProjectTests {
    static func system() -> FakeSystem {
        let system = FakeSystem()
        let template = "/t"
        system.file("\(template)/TemplateInfo.plist", """
            <?xml version="1.0" encoding="UTF-8"?>
            <plist version="1.0"><dict>
            <key>Nodes</key><array>
              <string>README.md</string><string>build.sh</string><string>../.gitignore</string>
              <string>Firmware/Firmware.swift</string><string>Packages/___PROJECTNAME___Kit</string>
              <string>../___PROJECTNAME___.xcodeproj/xcshareddata/xcschemes/___PROJECTNAME___.xcscheme</string>
            </array>
            <key>Definitions</key><dict>
              <key>README.md</key><dict><key>Path</key><string>README.md</string><key>IsTopLevel</key><true/></dict>
              <key>build.sh</key><dict><key>Path</key><string>build.sh</string></dict>
              <key>../.gitignore</key><dict><key>Path</key><string>gitignore</string></dict>
              <key>Firmware/Firmware.swift</key><dict><key>Path</key><string>Firmware_Firmware.swift</string><key>IsTopLevel</key><true/></dict>
              <key>Packages/___PROJECTNAME___Kit</key><dict><key>Path</key><string>Kit</string><key>IsTopLevel</key><true/></dict>
              <key>../___PROJECTNAME___.xcodeproj/xcshareddata/xcschemes/___PROJECTNAME___.xcscheme</key><dict><key>Path</key><string>scheme.xcscheme</string></dict>
            </dict>
            <key>Options</key><array><dict><key>Identifier</key><string>board</string>
              <key>Default</key><string>c6-devkit</string>
              <key>Values</key><array><string>c3-devkit</string><string>c6-devkit</string><string>c6-mini</string><string>other-esp32c6</string></array>
              <key>ValueTitles</key><array><string>C3 DevKit</string><string>C6 DevKit</string><string>C6 Mini</string><string>Other ESP32-C6 board</string></array>
              <key>Variables</key><dict>
                <key>c3-devkit</key><dict><key>chip</key><string>esp32c3</string><key>boardName</key><string>C3 DevKit</string></dict>
                <key>c6-devkit</key><dict><key>chip</key><string>esp32c6</string><key>boardName</key><string>C6 DevKit</string></dict>
                <key>c6-mini</key><dict><key>chip</key><string>esp32c6</string><key>boardName</key><string>C6 Mini</string></dict>
                <key>other-esp32c6</key><dict><key>chip</key><string>esp32c6</string><key>boardName</key><string>another board</string></dict>
              </dict></dict></array>
            </dict></plist>
            """)
        system.file("\(template)/README.md", "# ___PROJECTNAME___ for ___VARIABLE_chip___\n")
        system.file("\(template)/build.sh", "#!/bin/bash\n")
        system.file("\(template)/gitignore", "build/\n")
        system.file("\(template)/Firmware_Firmware.swift", "//  Created by ___FULLUSERNAME___ on ___DATE___.\n")
        system.file("\(template)/Kit/Package.swift", "name: \"___PROJECTNAME___Kit\"\n")
        system.directories.insert("\(template)/Kit")
        system.file("\(template)/scheme.xcscheme", "")
        return system
    }

    @Test func laysOutTheProjectAsXcodeDoes() throws {
        let system = Self.system()
        let root = try NewProject(system: system, template: "/t")
            .run(name: "Blinky", board: "c3-devkit", in: "/w", author: "Ada", date: "17/10/2026")
        #expect(root == "/w/Blinky")
        #expect(system.readFile("/w/Blinky/README.md") == "# Blinky for esp32c3\n")
        #expect(system.readFile("/w/Blinky/Blinky/build.sh") == "#!/bin/bash\n")
        #expect(system.actions.contains("chmod /w/Blinky/Blinky/build.sh"))
        #expect(system.readFile("/w/Blinky/.gitignore") == "build/\n")
        #expect(system.readFile("/w/Blinky/Firmware/Firmware.swift") == "//  Created by Ada on 17/10/2026.\n")
        #expect(system.readFile("/w/Blinky/Packages/BlinkyKit/Package.swift") == "name: \"BlinkyKit\"\n")
        // No Xcode project.
        #expect(!system.files.keys.contains { $0.contains(".xcodeproj") })
    }

    @Test func checksTheNameBoardAndFolder() {
        let system = Self.system()
        let new = NewProject(system: system, template: "/t")
        #expect(throws: EspSwiftError.self) { try new.run(name: "My Project", in: "/w", author: "", date: "") }
        #expect(throws: EspSwiftError.self) { try new.run(name: "Blinky", board: "esp32-devkit", in: "/w", author: "", date: "") }
        system.directories.insert("/w/Blinky")
        #expect(throws: EspSwiftError.self) { try new.run(name: "Blinky", in: "/w", author: "", date: "") }
    }

    @Test func failsOnUnknownPlaceholders() {
        let system = Self.system()
        system.file("/t/README.md", "___ORGANIZATIONNAME___\n")
        #expect(throws: EspSwiftError.self) {
            try NewProject(system: system, template: "/t").run(name: "Blinky", in: "/w", author: "", date: "")
        }
    }
}

@Suite struct BoardOptionTests {
    @Test func fillsInTheBoardsVariables() throws {
        let system = NewProjectTests.system()
        system.file("/t/README.md", "___VARIABLE_boardName___ (___VARIABLE_chip___)\n")
        let new = NewProject(system: system, template: "/t")
        // The pop-up's default.
        try new.run(name: "A", in: "/w", author: "", date: "")
        #expect(system.readFile("/w/A/README.md") == "C6 DevKit (esp32c6)\n")
        try new.run(name: "B", board: "c6-mini", in: "/w", author: "", date: "")
        #expect(system.readFile("/w/B/README.md") == "C6 Mini (esp32c6)\n")
    }

    @Test func picksTheBoardForAChip() throws {
        let new = NewProject(system: NewProjectTests.system(), template: "/t")
        #expect(try new.board(nil, chip: nil) == "c6-devkit")
        #expect(try new.board(nil, chip: "esp32c3") == "c3-devkit")
        #expect(try new.board("c6-mini", chip: "esp32c6") == "c6-mini")
        #expect(throws: EspSwiftError.self) { try new.board("c6-mini", chip: "esp32c3") }
        #expect(throws: EspSwiftError.self) { try new.board(nil, chip: "esp32") }
        #expect(throws: EspSwiftError.self) { try new.board("esp32-devkit", chip: nil) }
        #expect(try new.boards().map(\.chip) == ["esp32c3", "esp32c6", "esp32c6", "esp32c6"])
    }
}
