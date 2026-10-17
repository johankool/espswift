import Foundation

/// ESP-IDF installations made by Espressif's ESP-IDF Installation Manager
/// (EIM, `eim`), which espswift setup uses to install ESP-IDF. EIM records
/// them in eim_idf.json, in ~/.espressif/tools by default.
public struct EIM: Sendable {
    public var system: System

    public init(system: System) {
        self.system = system
    }

    /// One ESP-IDF installation in eim_idf.json.
    public struct Installation: Equatable, Sendable {
        /// EIM's name for it, such as "v6.1", which its commands take.
        public var name: String
        /// The ESP-IDF folder (IDF_PATH).
        public var path: String
        /// The script that sets up its environment; with -e, it prints it.
        public var activationScript: String
    }

    /// eim_idf.json's location.
    public var recordPath: String {
        "\(system.homeDirectory)/.espressif/tools/eim_idf.json"
    }

    /// The installations in eim_idf.json, the selected one first. Fields
    /// espswift doesn't use are ignored, so a newer EIM's file still reads.
    public func installations() -> [Installation] {
        guard let data = system.readData(recordPath),
              let record = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = record["idfInstalled"] as? [[String: Any]] else { return [] }
        let selected = record["idfSelectedId"] as? String
        let sorted = entries.filter { $0["id"] as? String == selected } + entries.filter { $0["id"] as? String != selected }
        return sorted.compactMap { entry in
            guard let path = entry["path"] as? String, let script = entry["activationScript"] as? String else { return nil }
            return Installation(name: entry["name"] as? String ?? "", path: path, activationScript: script)
        }
    }

    /// The installation of the pinned ESP-IDF version, if EIM installed it.
    public func pinnedInstallation() -> Installation? {
        installations().first { installation in
            system.readFile("\(installation.path)/tools/cmake/version.cmake")
                .flatMap(VersionParser.espIDF(versionCMake:))?.satisfies(Pins.espIDF) == true
        }
    }

    /// The environment an activation script sets up, from what it prints
    /// with -e: one NAME=value per line. PATH is ESP-IDF's tools only.
    public func environment(of installation: Installation) -> [String: String]? {
        guard let output = system.run("/bin/bash", [installation.activationScript, "-e"]), output.status == 0 else {
            return nil
        }
        var environment: [String: String] = [:]
        for line in output.output.split(separator: "\n") {
            guard let equals = line.firstIndex(of: "=") else { continue }
            environment[String(line[..<equals])] = String(line[line.index(after: equals)...])
        }
        // SYSTEM_PATH is the PATH when EIM installed it, not today's.
        environment["SYSTEM_PATH"] = nil
        return environment["IDF_PATH"] == nil ? nil : environment
    }
}
