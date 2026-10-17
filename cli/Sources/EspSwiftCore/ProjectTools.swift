import Foundation

/// Adds an ESP-IDF library (a component from the ESP-IDF Component Registry,
/// https://components.espressif.com) to a project: `espswift add`.
///
/// It adds the component to main/idf_component.yml, which ESP-IDF's
/// component manager downloads on the next build, and its header to
/// Firmware/ESPIDF/include/ESPIDF.h, so Swift code sees it with
/// `import ESPIDF`.
public struct AddLibrary: Sendable {
    public var system: System
    public var project: Project

    public init(system: System, project: Project) {
        self.system = system
        self.project = project
    }

    /// The header a component's name suggests: espressif/led_strip → led_strip.h.
    public static func header(for component: String) -> String {
        "\(component.split(separator: "/").last ?? Substring(component)).h"
    }

    public func run(component: String, header: String?) throws {
        let header = header ?? Self.header(for: component)
        let manifest = "\(project.sourceFolder)/main/idf_component.yml"
        guard let yaml = system.readFile(manifest) else {
            throw EspSwiftError("\(manifest) wasn't found.")
        }
        if yaml.split(separator: "\n").contains(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("\(component):") }) {
            system.report("\(component) is in main/idf_component.yml already.")
        } else {
            let separator = yaml.hasSuffix("\n") || yaml.isEmpty ? "" : "\n"
            try system.writeFile(manifest, yaml + separator + "  \(component): \"*\"\n")
            system.report("Added \(component) to main/idf_component.yml.")
        }

        let espidf = "\(project.folder)/Firmware/ESPIDF/include/ESPIDF.h"
        guard let text = system.readFile(espidf) else {
            throw EspSwiftError("\(espidf) wasn't found.")
        }
        let include = "#include \"\(header)\""
        if text.contains(include) {
            system.report("ESPIDF.h includes \(header) already.")
        } else {
            let end = "#endif /* ESPIDF_h */"
            guard let range = text.range(of: end, options: .backwards) else {
                throw EspSwiftError("ESPIDF.h has no \"\(end)\" to add the #include before.")
            }
            try system.writeFile(espidf, text.replacingCharacters(in: range, with: "\(include)\n\n\(end)"))
            system.report("Added \(include) to Firmware/ESPIDF/include/ESPIDF.h.")
        }
        system.report("")
        system.report("Build the project (Cmd+B) to download and build \(component); then use its functions in Swift.")
    }
}

/// Brings a project created from an older template up to date: `espswift
/// update`. The build warns when a project needs it. Each step checks first,
/// so running it again changes nothing.
///
/// 1. Replaces the project's build.sh with the template's, which carries the
///    template version.
/// 2. Points the Indexing target, which code completion uses, at the Swift
///    toolchain setup installed, e.g. after a Swift upgrade.
public struct UpdateProject: Sendable {
    public var system: System
    public var project: Project

    public init(system: System, project: Project) {
        self.system = system
        self.project = project
    }

    /// The template to update from: ESPSWIFT_TEMPLATE, the installed Xcode
    /// template, or espswift's own copy.
    func template() throws -> String {
        if let template = system.environment["ESPSWIFT_TEMPLATE"] { return template }
        if let installed = Locations(system: system).xcodeTemplate, system.isDirectory(installed) { return installed }
        return try Resources.find(system: system).xcodeTemplate
    }

    @discardableResult
    public func run() throws -> Bool {
        system.report("Updating \(project.name)...")
        var changed = false

        // ── 1. build.sh ──
        let templateBuild = "\(try template())/build.sh"
        guard let newBuild = system.readData(templateBuild) else {
            throw EspSwiftError("The template's build.sh wasn't found at \(templateBuild).")
        }
        let build = "\(project.sourceFolder)/build.sh"
        if system.readData(build) != newBuild {
            try system.writeFile(build, newBuild)
            try system.makeExecutable(build)
            system.report("  Replaced build.sh with the template's.")
            changed = true
        }

        // ── 2. The Swift toolchain for code completion (macOS) ──
        let pbxproj = "\(project.folder)/\(project.name).xcodeproj/project.pbxproj"
        if let text = system.readFile(pbxproj),
           let toolchain = system.readFile(Locations(system: system).swiftToolchainRecord)?.split(separator: "\n").first,
           let identifier = XcodeTemplate.bundleIdentifier(ofToolchain: String(toolchain), system: system) {
            var updated = false
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
                guard let range = line.range(of: "TOOLCHAINS = "), line.hasSuffix(";"),
                      line[range.upperBound...] != "\(identifier);" else { return String(line) }
                updated = true
                return line[..<range.upperBound] + "\(identifier);"
            }
            if updated {
                try system.writeFile(pbxproj, lines.joined(separator: "\n"))
                system.report("  Pointed the Indexing target (code completion) at \(toolchain.split(separator: "/").last ?? "").")
                changed = true
            } else if !text.contains("TOOLCHAINS = ") {
                system.report("  Note: This project has no Indexing target, so it doesn't get code completion.")
            }
        }

        system.report(changed ? "Done. If the project is open in Xcode, it reloads it." : "Already up to date.")
        return changed
    }
}

/// ESP-IDF's settings menu (idf.py menuconfig), in a terminal: `espswift
/// settings`. It saves the settings in the project's sdkconfig.
public struct Settings: Sendable {
    public var system: System
    public var project: Project

    public init(system: System, project: Project) {
        self.system = system
        self.project = project
    }

    public func run() throws {
        let environment = try ESPIDF(system: system).environment()
        let status = system.runVisibly(ESPIDF.python(environment), [
            ESPIDF.idfPy(Locations(system: system)), "-C", project.sourceFolder,
            "-B", Flash.buildFolder(for: project, system: system), "menuconfig",
        ], environment: environment)
        guard status == 0 else { throw EspSwiftError("idf.py menuconfig failed.") }
        system.report("Saved in sdkconfig. Build the project (Cmd+B) to use the new settings.")
    }
}
