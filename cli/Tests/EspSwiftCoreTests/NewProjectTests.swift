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
            <key>Options</key><array><dict><key>Identifier</key><string>chip</string>
              <key>Values</key><array><string>esp32c3</string><string>esp32c6</string></array></dict></array>
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
            .run(name: "Blinky", chip: "esp32c3", in: "/w", author: "Ada", date: "17/10/2026")
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

    @Test func checksTheNameChipAndFolder() {
        let system = Self.system()
        let new = NewProject(system: system, template: "/t")
        #expect(throws: EspSwiftError.self) { try new.run(name: "My Project", chip: "esp32c6", in: "/w", author: "", date: "") }
        #expect(throws: EspSwiftError.self) { try new.run(name: "Blinky", chip: "esp32", in: "/w", author: "", date: "") }
        system.directories.insert("/w/Blinky")
        #expect(throws: EspSwiftError.self) { try new.run(name: "Blinky", chip: "esp32c6", in: "/w", author: "", date: "") }
    }

    @Test func failsOnUnknownPlaceholders() {
        let system = Self.system()
        system.file("/t/README.md", "___ORGANIZATIONNAME___\n")
        #expect(throws: EspSwiftError.self) {
            try NewProject(system: system, template: "/t").run(name: "Blinky", chip: "esp32c6", in: "/w", author: "", date: "")
        }
    }
}
