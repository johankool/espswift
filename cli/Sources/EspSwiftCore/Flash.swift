/// The build Cmd+R flashes: `espswift build` records the source folder and
/// the build folder of the last build, of any project in
/// ~/.espswift/last-build, and of the project in its source folder's
/// .espswift/last-build.
public struct LastBuild: Equatable, Sendable {
    public var sourceFolder: String
    public var buildFolder: String

    public init(sourceFolder: String, buildFolder: String) {
        self.sourceFolder = sourceFolder
        self.buildFolder = buildFolder
    }

    /// The last build of any project.
    public static func read(system: System) -> LastBuild? {
        read(file: "\(Locations(system: system).espswiftHome)/last-build", system: system)
    }

    /// The last build of a project.
    public static func read(of project: Project, system: System) -> LastBuild? {
        read(file: file(of: project), system: system)
    }

    /// Where a project's last build is recorded.
    static func file(of project: Project) -> String {
        "\(project.sourceFolder)/.espswift/last-build"
    }

    static func read(file: String, system: System) -> LastBuild? {
        let lines = (system.readFile(file) ?? "").split(separator: "\n").map(String.init)
        guard lines.count >= 2 else { return nil }
        return LastBuild(sourceFolder: lines[0], buildFolder: lines[1])
    }

    /// Records this as the last build, of any project and of its project.
    func record(for project: Project, system: System) throws {
        let text = "\(sourceFolder)\n\(buildFolder)\n"
        try system.writeFile("\(Locations(system: system).espswiftHome)/last-build", text)
        try system.createDirectory(Resources.parent(of: Self.file(of: project)))
        try system.writeFile(Self.file(of: project), text)
    }
}

/// Flashes a build to the board: `espswift flash`, and part of `espswift run`.
public struct Flash: Sendable {
    public var system: System

    public init(system: System) {
        self.system = system
    }

    /// The build folder to flash for a project: its last build (which may
    /// be in Xcode's DerivedData), else ./build.
    public static func buildFolder(for project: Project, system: System) -> String {
        if let last = LastBuild.read(of: project, system: system), last.sourceFolder == project.sourceFolder {
            return last.buildFolder
        }
        if let last = LastBuild.read(system: system), last.sourceFolder == project.sourceFolder {
            return last.buildFolder
        }
        return "\(project.sourceFolder)/build"
    }

    public func run(sourceFolder: String, buildFolder: String, port: String) throws {
        // idf.py writes flasher_args.json in a successful build.
        guard system.fileExists("\(buildFolder)/flasher_args.json") else {
            throw EspSwiftError("There's no build to flash in \(buildFolder). Build the project first (espswift build, or Cmd+B in Xcode).")
        }
        let environment = try ESPIDF(system: system).environment()
        system.report("=================================================")
        system.report(" Flashing \(sourceFolder.split(separator: "/").last ?? "") to \(port)")
        system.report("=================================================")
        // esptool redraws its progress bars in place, with carriage returns
        // and color codes, which Xcode's console shows as text: show each
        // line as it ends up.
        let status = system.runStreaming(ESPIDF.python(environment), [
            ESPIDF.idfPy(Locations(system: system)), "-C", sourceFolder, "-B", buildFolder, "-p", port, "flash",
        ], environment: environment) { line in
            let last = line.split(separator: "\r", omittingEmptySubsequences: true).last.map(String.init) ?? ""
            system.report(BuildOutputFilter.removingEscapeCodes(last))
        }
        guard status == 0 else {
            throw EspSwiftError("Flashing failed; see above. Is the board connected to \(port)?")
        }
        system.report("Flash complete.")
        system.report("")
    }
}
