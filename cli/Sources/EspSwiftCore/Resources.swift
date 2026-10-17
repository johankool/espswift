/// The files espswift installs: the Xcode template.
public struct Resources: Sendable {
    /// The folder with "Xcode Template".
    public var root: String

    public var xcodeTemplate: String { "\(root)/Xcode Template/ESP32 RISC-V.xctemplate" }

    public init(root: String) {
        self.root = root
    }

    /// Finds the resources, in order:
    /// 1. ESPSWIFT_RESOURCES, if set.
    /// 2. share/espswift next to the bin folder espswift is in, where an
    ///    installation (such as Homebrew's) puts them.
    /// 3. The repository espswift was built in, for development: a parent
    ///    folder of espswift that has them.
    /// 4. The repository recorded by espswift setup, for its copy of a
    ///    development build in ~/.espswift/libexec (install.sh).
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
        if let recorded = system.readFile(Locations(system: system).resourcesRecord)?
            .split(separator: "\n").first {
            candidates.append(String(recorded))
        }
        for candidate in candidates {
            let resources = Resources(root: candidate)
            if system.isDirectory(resources.xcodeTemplate) {
                return resources
            }
        }
        throw EspSwiftError("""
            espswift's files (the Xcode template) weren't found. \
            Set ESPSWIFT_RESOURCES to the folder that has them.
            """)
    }

    static func parent(of path: String) -> String {
        guard let slash = path.lastIndex(of: "/") else { return "" }
        return slash == path.startIndex ? "/" : String(path[..<slash])
    }
}
