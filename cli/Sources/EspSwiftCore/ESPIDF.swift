import Foundation

/// Running ESP-IDF's tools (idf.py) in ESP-IDF's environment: the one
/// EIM's activation script sets up, or for an ESP-IDF elsewhere (IDF_PATH),
/// its export.sh's.
public struct ESPIDF: Sendable {
    public var system: System
    public var locations: Locations

    public init(system: System) {
        self.system = system
        locations = Locations(system: system)
    }

    /// ESP-IDF's environment: its tools and Python environment first on
    /// PATH. Xcode's PATH doesn't include Homebrew, which the search path
    /// adds.
    public func environment() throws -> [String: String] {
        if system.environment["IDF_PATH"] == nil {
            let eim = EIM(system: system)
            guard let installation = eim.pinnedInstallation() else {
                throw EspSwiftError("ESP-IDF \(Pins.espIDF) wasn't found among EIM's installations (eim list). Run: espswift setup")
            }
            guard let idf = eim.environment(of: installation) else {
                throw EspSwiftError("Setting up ESP-IDF's environment (EIM's \(installation.activationScript)) failed. Run: eim fix \(installation.name)")
            }
            var environment = system.environment.merging(idf) { $1 }
            environment["PATH"] = ((idf["PATH"].map { [$0] } ?? []) + system.searchPath).joined(separator: ":")
            return environment
        }
        return try exportEnvironment()
    }

    /// The environment ESP-IDF's export.sh sets up, for an ESP-IDF that EIM
    /// didn't install (IDF_PATH). It finds its Python environment by the
    /// first python3 on PATH, ESPSwift's.
    func exportEnvironment() throws -> [String: String] {
        guard system.isDirectory(locations.idfPath) else {
            throw EspSwiftError("ESP-IDF wasn't found at \(locations.idfPath). Run: espswift setup")
        }
        var base = system.environment
        base["IDF_PATH"] = locations.idfPath
        base["PATH"] = ([Resources.parent(of: locations.python)] + system.searchPath).joined(separator: ":")
        let script = "set -e; . \"$IDF_PATH/export.sh\" > /dev/null 2>&1; env -0"
        var output = Data()
        let status = system.runStreaming("/bin/bash", ["-c", script], environment: base) { line in
            output.append(contentsOf: Array(line.utf8) + [10])
        }
        guard status == 0 else {
            throw EspSwiftError("Setting up ESP-IDF's environment (its export.sh) failed. Run: espswift doctor")
        }
        // env -0 separates the variables with NUL. Joining the lines again
        // gives its output back, plus a newline at the end.
        var environment: [String: String] = [:]
        let text = String(decoding: output.dropLast(), as: UTF8.self)
        for entry in text.split(separator: "\0") {
            guard let equals = entry.firstIndex(of: "=") else { continue }
            environment[String(entry[..<equals])] = String(entry[entry.index(after: equals)...])
        }
        guard environment["IDF_PYTHON_ENV_PATH"] != nil else {
            throw EspSwiftError("ESP-IDF's environment wasn't set up. Run: espswift doctor")
        }
        return environment
    }

    /// The Python of ESP-IDF's environment, which runs idf.py.
    public static func python(_ environment: [String: String]) -> String {
        "\(environment["IDF_PYTHON_ENV_PATH"] ?? "")/bin/python"
    }

    public static func idfPy(_ locations: Locations) -> String {
        "\(locations.idfPath)/tools/idf.py"
    }
}
