/// An ESPSwift project: the project folder (with the Xcode project, the
/// Firmware and Kit packages) and its source folder, the ESP-IDF project
/// inside it (with CMakeLists.txt, main/ and sdkconfig.defaults).
public struct Project: Equatable, Sendable {
    /// The project folder.
    public var folder: String
    /// The ESP-IDF project, named after the project.
    public var sourceFolder: String

    public var name: String { String(sourceFolder.split(separator: "/").last ?? "") }

    public init(folder: String, sourceFolder: String) {
        self.folder = folder
        self.sourceFolder = sourceFolder
    }

    /// Whether a folder is an ESP-IDF project made from the template.
    static func isSourceFolder(_ path: String, system: System) -> Bool {
        system.fileExists("\(path)/CMakeLists.txt")
            && system.fileExists("\(path)/main/CMakeLists.txt")
            && system.fileExists("\(path)/sdkconfig.defaults")
    }

    /// Finds the project: from Xcode's PROJECT_DIR and PROJECT_NAME when Xcode
    /// runs the build, else from `start` (or the current folder) and the
    /// folders above it, like git finds its repository. A folder counts when
    /// it's the source folder, or the project folder that has one.
    public static func find(system: System, start: String? = nil) throws -> Project {
        let environment = system.environment
        if start == nil, let folder = environment["PROJECT_DIR"], let name = environment["PROJECT_NAME"],
           isSourceFolder("\(folder)/\(name)", system: system) {
            return Project(folder: folder, sourceFolder: "\(folder)/\(name)")
        }
        var folder = start ?? system.currentDirectory
        while !folder.isEmpty {
            if isSourceFolder(folder, system: system) {
                return Project(folder: Resources.parent(of: folder), sourceFolder: folder)
            }
            // The source folder is named after the project; prefer that one.
            let children = system.contentsOfDirectory(folder).sorted()
            let preferred = children.filter { system.fileExists("\(folder)/\($0).xcodeproj") } + children
            if let child = preferred.first(where: { isSourceFolder("\(folder)/\($0)", system: system) }) {
                return Project(folder: folder, sourceFolder: "\(folder)/\(child)")
            }
            if folder == "/" { break }
            folder = Resources.parent(of: folder)
        }
        throw EspSwiftError("""
            No ESPSwift project found in \(start ?? system.currentDirectory) or the folders above it. \
            Run espswift in a project's folder, or use --project.
            """)
    }

    /// The chip in a sdkconfig file (CONFIG_IDF_TARGET="esp32c6").
    static func chip(inConfig text: String?) -> String? {
        let prefix = "CONFIG_IDF_TARGET=\""
        for line in (text ?? "").split(separator: "\n") where line.hasPrefix(prefix) && line.hasSuffix("\"") {
            return String(line.dropFirst(prefix.count).dropLast())
        }
        return nil
    }
}
