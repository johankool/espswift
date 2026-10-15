/// The files espswift installs: the Xcode template and the helper scripts
/// that projects use (until espswift's own commands replace them).
public struct Resources: Sendable {
    /// The folder with "Xcode Template" and "scripts".
    public var root: String

    public var xcodeTemplate: String { "\(root)/Xcode Template/ESP32 RISC-V.xctemplate" }
    public var scripts: String { "\(root)/scripts" }

    public init(root: String) {
        self.root = root
    }

    /// Finds the resources, in order:
    /// 1. ESPSWIFT_RESOURCES, if set.
    /// 2. share/espswift next to the bin folder espswift is in, where an
    ///    installation (such as Homebrew's) puts them.
    /// 3. The repository espswift was built in, for development: a parent
    ///    folder of espswift that has them.
    public static func find(system: System) throws -> Resources {
        var candidates: [String] = []
        if let path = system.environment["ESPSWIFT_RESOURCES"] {
            candidates.append(path)
        }
        if let executable = system.executablePath {
            var folder = parent(of: executable)
            candidates.append("\(parent(of: folder))/share/espswift")
            while folder != "/" && !folder.isEmpty {
                candidates.append(folder)
                folder = parent(of: folder)
            }
        }
        for candidate in candidates {
            let resources = Resources(root: candidate)
            if system.isDirectory(resources.xcodeTemplate) && system.isDirectory(resources.scripts) {
                return resources
            }
        }
        throw EspSwiftError("""
            espswift's files (the Xcode template and scripts) weren't found. \
            Set ESPSWIFT_RESOURCES to the folder that has them.
            """)
    }

    static func parent(of path: String) -> String {
        guard let slash = path.lastIndex(of: "/") else { return "" }
        return slash == path.startIndex ? "/" : String(path[..<slash])
    }
}
