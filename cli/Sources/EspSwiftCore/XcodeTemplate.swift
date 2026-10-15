import Foundation

/// The Xcode project template, ESP32 RISC-V (macOS only).
public struct XcodeTemplate: Sendable {
    public var system: System
    public var locations: Locations

    /// The folder Xcode looks for project templates in.
    var templatesFolder: String {
        "\(system.homeDirectory)/Library/Developer/Xcode/Templates/Project Templates/Other"
    }
    /// The template's old name, from when it supported only the ESP32-C6.
    var oldTemplate: String { "\(templatesFolder)/ESP32-C6.xctemplate" }

    public init(system: System) {
        self.system = system
        locations = Locations(system: system)
    }

    /// Installs (or updates) the template, for the Swift toolchain at
    /// `swiftToolchain`.
    public func install(from resources: Resources, swiftToolchain: String) throws {
        guard system.operatingSystem == .macOS, let template = locations.xcodeTemplate else {
            throw EspSwiftError("The Xcode template is only for macOS.")
        }
        guard let builtIn = builtInTemplate() else {
            throw EspSwiftError("Xcode wasn't found. Install it from the App Store, then run: espswift xcode install-template")
        }
        system.report("Installing the Xcode template...")
        try system.createDirectory(templatesFolder)
        try system.removeItem(oldTemplate)
        // Replaced as a whole, so no files of an earlier version stay behind.
        try system.removeItem(template)
        // Start from Xcode's External Build System template, which has the
        // keys Xcode expects, and put ESPSwift's files over it.
        try system.copyContents(of: builtIn, to: template)
        try system.copyContents(of: resources.xcodeTemplate, to: template)
        try system.makeExecutable("\(template)/build.sh")

        // The Indexing target, which code completion uses, names the Swift
        // toolchain by its identifier, which includes the build date.
        // (An extra toolchain whose usr/ links to another, which would have a
        // fixed identifier, breaks Xcode's code completion.)
        guard let toolchainID = Self.bundleIdentifier(ofToolchain: swiftToolchain, system: system) else {
            throw EspSwiftError("Can't read the identifier of the Swift toolchain at \(swiftToolchain).")
        }
        try fillInToolchain(toolchainID, in: "\(template)/TemplateInfo.plist")

        // The Run scheme (Cmd+R) starts `espswift run --last-build`, which
        // needs an absolute path.
        let scheme = "\(template)/scheme.xcscheme"
        if let text = system.readFile(scheme) {
            try system.writeFile(scheme, text.replacingOccurrences(of: "ESPSWIFT_COMMAND_PATH", with: locations.command))
        }
        system.report("Installed the Xcode template ESP32 RISC-V. Restart Xcode to see it in File ▸ New ▸ Project.")
    }

    /// Removes the template (also under its old name); whether there was one.
    @discardableResult
    public func uninstall() throws -> Bool {
        var removed = false
        for template in [locations.xcodeTemplate, oldTemplate].compactMap({ $0 }) where system.isDirectory(template) {
            try system.removeItem(template)
            removed = true
        }
        return removed
    }

    /// Xcode's External Build System template, in the selected Xcode.
    func builtInTemplate() -> String? {
        let developer = system.run("/usr/bin/xcode-select", ["-p"])?.output
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let candidates = [developer, "/Applications/Xcode.app/Contents/Developer"].filter { !$0.isEmpty }
        return candidates
            .map { "\($0)/Library/Xcode/Templates/Project Templates/Other/External Build System.xctemplate" }
            .first(where: system.isDirectory)
    }

    func fillInToolchain(_ toolchainID: String, in plistPath: String) throws {
        guard let data = system.readData(plistPath),
              var plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              var targets = plist["Targets"] as? [[String: Any]] else {
            throw EspSwiftError("Can't read the template's TemplateInfo.plist.")
        }
        for index in targets.indices {
            if var settings = targets[index]["SharedSettings"] as? [String: Any],
               settings["TOOLCHAINS"] as? String == "ESPSWIFT_SWIFT_TOOLCHAIN_ID" {
                settings["TOOLCHAINS"] = toolchainID
                targets[index]["SharedSettings"] = settings
            }
        }
        plist["Targets"] = targets
        try system.writeFile(plistPath, PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0))
    }

    /// The CFBundleIdentifier of a .xctoolchain, such as org.swift.640202609131a.
    static func bundleIdentifier(ofToolchain toolchain: String, system: System) -> String? {
        guard let data = system.readData("\(toolchain)/Info.plist"),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        return plist["CFBundleIdentifier"] as? String
    }
}
