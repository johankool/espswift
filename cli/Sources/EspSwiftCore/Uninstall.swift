/// Removes what `espswift setup` installed: `espswift uninstall`.
///
/// Always removed (used only by ESPSwift): ~/.espswift (ESP-IDF, espswift's
/// link, the toolchain record) and the Xcode template.
///
/// Removed only when confirmed, or with --all, because other projects may
/// use them too: the Swift toolchain, ESP-IDF's tools (~/.espressif) and
/// ESP-IDF's component download cache.
///
/// Never removed: Homebrew and its packages (Python, CMake, Ninja), swiftly,
/// espswift itself (Homebrew removes it), and projects.
public struct Uninstall: Sendable {
    public var system: System
    public var locations: Locations

    public init(system: System) {
        self.system = system
        locations = Locations(system: system)
    }

    /// ESP-IDF's component download cache.
    var componentCache: String {
        system.operatingSystem == .macOS
            ? "\(system.homeDirectory)/Library/Caches/Espressif/ComponentManager"
            : "\(system.environment["XDG_CACHE_HOME"] ?? "\(system.homeDirectory)/.cache")/Espressif/ComponentManager"
    }

    /// - Parameters:
    ///   - assumeYes: Don't ask before removing ESPSwift's own files.
    ///   - all: Also remove the shared items, without asking.
    public func run(assumeYes: Bool, all: Bool) throws {
        let template = XcodeTemplate(system: system)
        let templates = [locations.xcodeTemplate, template.oldTemplate].compactMap { $0 }.filter(system.isDirectory)
        let ownFiles = system.isDirectory(locations.espswiftHome)

        system.report("This removes ESPSwift:")
        if ownFiles { system.report("  \(display(locations.espswiftHome))\(size(locations.espswiftHome))") }
        if !templates.isEmpty { system.report("  the Xcode template") }
        if !ownFiles && templates.isEmpty { system.report("  Nothing found: ESPSwift doesn't seem to be set up.") }

        if (ownFiles || !templates.isEmpty) && !assumeYes {
            guard system.isInteractive else {
                throw EspSwiftError("Not running in a terminal. Use --yes to uninstall without being asked.")
            }
            guard system.confirm("Continue?", default: false) else {
                system.report("Nothing was removed.")
                return
            }
        }

        // The toolchain record goes with ~/.espswift, so read it first.
        let toolchain = system.readFile(locations.swiftToolchainRecord)?
            .split(separator: "\n").first.map(String.init)
            .flatMap { system.isDirectory($0) ? $0 : nil }

        if ownFiles {
            try system.removeItem(locations.espswiftHome)
            system.report("Removed \(display(locations.espswiftHome))")
        }
        if try template.uninstall() {
            system.report("Removed the Xcode template")
        }

        // ── Shared items ──
        if let toolchain {
            let name = String(toolchain.split(separator: "/").last ?? "")
            if all || system.confirm("Remove the Swift toolchain \(name)\(size(toolchain))? Other Swift projects may use it.", default: false) {
                try removeSwift(toolchain)
                system.report("Removed the Swift toolchain \(name)")
            }
        }
        for (path, question) in [
            (locations.idfToolsPath, "Other ESP-IDF installations may use them."),
            (componentCache, "It's downloaded again when needed."),
        ] where system.isDirectory(path) {
            let what = path == componentCache ? "ESP-IDF's component download cache" : "ESP-IDF's tools in \(display(path))"
            if all || system.confirm("Remove \(what)\(size(path))? \(question)", default: false) {
                try system.removeItem(path)
                system.report("Removed \(what)")
            }
        }

        system.report("")
        system.report("""
            Not removed: Homebrew's packages (Python, CMake, Ninja), swiftly, espswift itself \
            (brew uninstall espswift), and your projects.
            """)
    }

    /// Toolchains installed with swiftly are removed with swiftly, so it
    /// stays consistent.
    func removeSwift(_ toolchain: String) throws {
        if let swiftly = system.findExecutable("swiftly"),
           let list = system.run(swiftly, ["list"])?.output,
           list.contains("Swift \(Pins.swift)") {
            guard system.runVisibly(swiftly, ["uninstall", "\(Pins.swift)", "--assume-yes"],
                                    environment: system.environment) == 0 else {
                throw EspSwiftError("swiftly couldn't remove Swift \(Pins.swift).")
            }
        } else {
            try system.removeItem(toolchain)
        }
    }

    /// " (1.7G)", or nothing if du can't tell.
    func size(_ path: String) -> String {
        guard let output = system.run("/usr/bin/du", ["-sh", path])?.output,
              let size = output.split(whereSeparator: { $0 == "\t" || $0 == " " }).first, !size.isEmpty else {
            return ""
        }
        return " (\(size))"
    }

    private func display(_ path: String) -> String {
        locations.display(path, home: system.homeDirectory)
    }
}
