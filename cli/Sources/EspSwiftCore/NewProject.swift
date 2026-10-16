import Foundation

/// Creates a project from the template, without Xcode: `espswift new`. It
/// lays out the files as Xcode does, from the template's TemplateInfo.plist,
/// and fills in the placeholders Xcode would (___PROJECTNAME___ and so on),
/// in file contents and paths. It doesn't create the Xcode project, which
/// only Xcode can make from a template; the project builds with
/// `espswift build`.
public struct NewProject: Sendable {
    public var system: System
    /// The template folder (ESP32 RISC-V.xctemplate).
    public var template: String

    public init(system: System, template: String) {
        self.system = system
        self.template = template
    }

    /// The template's definitions and the chips of its Chip pop-up.
    struct TemplateInfo {
        var nodes: [String]
        var definitions: [String: [String: Any]]
        var chips: [String]
    }

    func templateInfo() throws -> TemplateInfo {
        guard let data = system.readData("\(template)/TemplateInfo.plist"),
              let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let nodes = plist["Nodes"] as? [String],
              let definitions = plist["Definitions"] as? [String: [String: Any]] else {
            throw EspSwiftError("Can't read the template's TemplateInfo.plist in \(template).")
        }
        let options = plist["Options"] as? [[String: Any]] ?? []
        let chips = options.first { $0["Identifier"] as? String == "chip" }?["Values"] as? [String] ?? Pins.chips
        return TemplateInfo(nodes: nodes, definitions: definitions, chips: chips)
    }

    /// Creates the project `name` for `chip` in `parent` (the project folder
    /// is parent/name); returns the project folder.
    @discardableResult
    public func run(name: String, chip: String, in parent: String, author: String, date: String) throws -> String {
        guard !name.isEmpty, !name.contains("/"), !name.hasPrefix("."), name.allSatisfy({ !$0.isWhitespace }) else {
            throw EspSwiftError("\"\(name)\" can't be a project name: use letters, digits, - or _, without spaces.")
        }
        let info = try templateInfo()
        guard info.chips.contains(chip) else {
            throw EspSwiftError("The template has no \(chip); choose one of \(info.chips.joined(separator: ", ")).")
        }
        let root = "\(parent)/\(name)"
        guard !system.fileExists(root) else {
            throw EspSwiftError("\(root) exists already.")
        }
        let placeholders = [
            "___PROJECTNAME___": name,
            "___FULLUSERNAME___": author,
            "___DATE___": date,
            "___VARIABLE_chip___": chip,
        ]
        func fillIn(_ text: String) -> String {
            placeholders.reduce(text) { $0.replacingOccurrences(of: $1.key, with: $1.value) }
        }

        for node in info.nodes {
            // The Xcode project's files (its scheme) are only for Xcode.
            guard !node.contains(".xcodeproj/"), let definition = info.definitions[node],
                  let path = definition["Path"] as? String else { continue }
            // Files go in the source folder (named after the project), except
            // top-level ones, which go next to the Xcode project.
            let base = definition["IsTopLevel"] as? Bool == true ? root : "\(root)/\(name)"
            let destination = Self.normalized("\(base)/\(fillIn(node))")
            let source = "\(template)/\(path)"
            for (from, to) in files(from: source, to: destination) {
                guard let data = system.readData(from) else {
                    throw EspSwiftError("The template's \(from) can't be read.")
                }
                let text = fillIn(String(decoding: data, as: UTF8.self))
                if let range = text.range(of: #"___[A-Za-z_:]+___"#, options: .regularExpression) {
                    throw EspSwiftError("The template's \(from) has a placeholder espswift doesn't know: \(text[range]).")
                }
                try system.createDirectory(Resources.parent(of: to))
                try system.writeFile(to, text)
                if to.hasSuffix(".sh") { try system.makeExecutable(to) }
            }
        }
        system.report("Created \(name) for the \(chip) in \(root).")
        return root
    }

    /// The files to copy: a file, or every file in a folder (such as the Kit
    /// package), with their destinations.
    func files(from source: String, to destination: String) -> [(String, String)] {
        guard system.isDirectory(source) else { return [(source, destination)] }
        return system.contentsOfDirectory(source).sorted().flatMap { entry in
            files(from: "\(source)/\(entry)", to: "\(destination)/\(entry)")
        }
    }

    /// A path without "." and ".." components (the template places
    /// .gitignore at "../.gitignore", relative to the source folder).
    static func normalized(_ path: String) -> String {
        var components: [Substring] = []
        for component in path.split(separator: "/") {
            if component == ".." { _ = components.popLast() } else if component != "." { components.append(component) }
        }
        return "/" + components.joined(separator: "/")
    }
}
