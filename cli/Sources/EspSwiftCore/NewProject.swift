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

    /// The template's definitions and its pop-ups, Board and Example.
    struct TemplateInfo {
        var nodes: [String]
        var definitions: [String: [String: Any]]
        var options: [[String: Any]]

        var boardOption: [String: Any]? { option("board") }
        var exampleOption: [String: Any]? { option("example") }

        func option(_ identifier: String) -> [String: Any]? {
            options.first { $0["Identifier"] as? String == identifier }
        }

        /// The boards, in the pop-up's order, with their titles and chips
        /// (each board's chip variable).
        var boards: [Board] {
            guard let option = boardOption else { return [] }
            let values = option["Values"] as? [String] ?? []
            let titles = option["ValueTitles"] as? [String] ?? values
            let variables = option["Variables"] as? [String: [String: String]] ?? [:]
            return zip(values, titles).map { Board(value: $0, title: $1, chip: variables[$0]?["chip"] ?? "") }
        }

        /// The examples, in the pop-up's order, with their titles.
        var examples: [Example] {
            guard let option = exampleOption else { return [] }
            let values = option["Values"] as? [String] ?? []
            let titles = option["ValueTitles"] as? [String] ?? values
            return zip(values, titles).map { Example(value: $0, title: $1) }
        }
    }

    /// A board the template offers.
    public struct Board: Sendable, Equatable {
        public var value: String
        public var title: String
        public var chip: String
    }

    /// An example the template starts projects from.
    public struct Example: Sendable, Equatable {
        public var value: String
        public var title: String
    }

    func templateInfo() throws -> TemplateInfo {
        guard let data = system.readData("\(template)/TemplateInfo.plist"),
              let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let nodes = plist["Nodes"] as? [String],
              let definitions = plist["Definitions"] as? [String: [String: Any]] else {
            throw EspSwiftError("Can't read the template's TemplateInfo.plist in \(template).")
        }
        return TemplateInfo(nodes: nodes, definitions: definitions, options: plist["Options"] as? [[String: Any]] ?? [])
    }

    /// The boards the template offers, in its Board pop-up's order.
    public func boards() throws -> [Board] {
        try templateInfo().boards
    }

    /// The examples the template offers, in its Example pop-up's order.
    public func examples() throws -> [Example] {
        try templateInfo().examples
    }

    /// The board the template's Board pop-up starts with.
    public func defaultBoard() throws -> String {
        try board(nil, chip: nil)
    }

    /// The example to use: the given one, if the template has it, else the
    /// pop-up's default.
    public func example(_ example: String?) throws -> String {
        let info = try templateInfo()
        let examples = info.examples
        if let example {
            guard examples.contains(where: { $0.value == example }) else {
                throw EspSwiftError("The template has no example \(example); see espswift new --list-examples.")
            }
            return example
        }
        guard let fallback = info.exampleOption?["Default"] as? String ?? examples.first?.value else {
            throw EspSwiftError("The template has no examples to choose from.")
        }
        return fallback
    }

    /// The board to use for a chip and a board, either of which can be
    /// missing: the board, if it has that chip; else the chip's first board;
    /// else the pop-up's default.
    public func board(_ board: String?, chip: String?) throws -> String {
        let info = try templateInfo()
        let boards = info.boards
        let chips = boards.map(\.chip).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        if let chip, !chips.contains(chip) {
            throw EspSwiftError("The template has no \(chip); choose one of \(chips.joined(separator: ", ")).")
        }
        if let board {
            guard let found = boards.first(where: { $0.value == board }) else {
                throw EspSwiftError("The template has no board \(board); see espswift new --list-boards.")
            }
            if let chip, found.chip != chip {
                throw EspSwiftError("\(found.title) has an \(found.chip), not an \(chip).")
            }
            return board
        }
        if let chip, let first = boards.first(where: { $0.chip == chip }) {
            return first.value
        }
        guard let fallback = info.boardOption?["Default"] as? String ?? boards.first?.value else {
            throw EspSwiftError("The template has no boards to choose from.")
        }
        return fallback
    }

    /// Creates the project `name` for `board`, from `example` (else the
    /// template's defaults) in `parent` (the project folder is parent/name);
    /// returns the project folder.
    @discardableResult
    public func run(name: String, board: String? = nil, example: String? = nil, in parent: String,
                    author: String, date: String) throws -> String {
        guard !name.isEmpty, !name.contains("/"), !name.hasPrefix("."), name.allSatisfy({ !$0.isWhitespace }) else {
            throw EspSwiftError("\"\(name)\" can't be a project name: use letters, digits, - or _, without spaces.")
        }
        let info = try templateInfo()
        let board = try self.board(board, chip: nil)
        let example = try self.example(example)
        let root = "\(parent)/\(name)"
        guard !system.fileExists(root) else {
            throw EspSwiftError("\(root) exists already.")
        }
        var placeholders = [
            "___PROJECTNAME___": name,
            "___FULLUSERNAME___": author,
            "___DATE___": date,
        ]
        // Each pop-up's value (the board, the example, or its default) and
        // the variables that value sets (Variables, such as the board's
        // chip), as ___VARIABLE_<name>___; and the files that value adds
        // (its Units: the example's files).
        var nodes = info.nodes
        var definitions = info.definitions
        for option in info.options {
            guard let identifier = option["Identifier"] as? String else { continue }
            let values = option["Values"] as? [String] ?? []
            let chosen = ["board": board, "example": example][identifier]
            guard let value = chosen ?? option["Default"] as? String ?? values.first else { continue }
            placeholders["___VARIABLE_\(identifier)___"] = value
            for (variable, text) in (option["Variables"] as? [String: [String: String]])?[value] ?? [:] {
                placeholders["___VARIABLE_\(variable)___"] = text
            }
            if let unit = (option["Units"] as? [String: [String: Any]])?[value] {
                nodes += unit["Nodes"] as? [String] ?? []
                definitions.merge(unit["Definitions"] as? [String: [String: Any]] ?? [:]) { $1 }
            }
        }
        func fillIn(_ text: String) -> String {
            placeholders.reduce(text) { $0.replacingOccurrences(of: $1.key, with: $1.value) }
        }

        for node in nodes {
            // The Xcode project's files (its scheme) are only for Xcode.
            guard !node.contains(".xcodeproj/"), let definition = definitions[node],
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
        let exampleTitle = placeholders["___VARIABLE_exampleTitle___"].map { ", from the \($0) example" } ?? ""
        system.report("Created \(name) in \(root), for \(placeholders["___VARIABLE_boardName___"] ?? board)\(exampleTitle).")
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
