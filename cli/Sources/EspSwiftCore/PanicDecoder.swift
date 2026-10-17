import Foundation

/// Finds crash dumps in a board's serial output. On a crash (a panic), ESP-IDF
/// prints the registers ("Core  0 register dump:"), the stack ("Stack
/// memory:") and ends with "ELF file SHA256:". RISC-V chips don't print a
/// backtrace; PanicDecoder works it out from the dump.
struct PanicDumpWatcher {
    /// Leave out the stack dump's lines (hex, for the decoder only).
    var hidesStack = false

    /// The current line, and how much of it was written already.
    private var line = Data()
    private var written = 0
    private var dump: [String]?
    private var inStack = false

    /// A dump longer than this didn't end as expected; stop collecting.
    static let maximumLines = 400

    /// What the board's output holds, in order.
    enum Event: Equatable {
        /// Output to show.
        case output(Data)
        /// A dump that just ended (after its output).
        case dump(String)
    }

    /// Takes output from the board; returns what to show and the dumps that
    /// ended in it, in order. Output is shown as it arrives, except the
    /// stack dump's lines.
    mutating func process(_ data: Data) -> [Event] {
        var events: [Event] = []
        var output = Data()
        for byte in data {
            line.append(byte)
            guard byte == 10 else { continue }
            let (show, ended) = handle(String(decoding: line, as: UTF8.self))
            if show && line.count > written { output.append(line[(line.startIndex + written)...]) }
            line.removeAll(keepingCapacity: true)
            written = 0
            if let ended {
                if !output.isEmpty { events.append(.output(output)) }
                output = Data()
                events.append(.dump(ended))
            }
        }
        // The start of a line (such as a prompt) is shown before its end
        // arrives, except within a dump, whose stack may be left out.
        if !(hidesStack && dump != nil) && line.count > written {
            output.append(line[(line.startIndex + written)...])
            written = line.count
        }
        if !output.isEmpty { events.append(.output(output)) }
        return events
    }

    /// Follows a dump; returns whether to show the line, and the dump if it
    /// ended.
    private mutating func handle(_ text: String) -> (show: Bool, ended: String?) {
        if dump == nil {
            guard text.range(of: #"Core\s*\d+ register dump:"#, options: .regularExpression) != nil else {
                return (true, nil)
            }
            dump = []
        }
        dump!.append(text)
        if text.contains("ELF file SHA256:") {
            let ended = dump!.joined()
            dump = nil
            inStack = false
            return (true, ended)
        }
        if dump!.count > Self.maximumLines {
            dump = nil
            inStack = false
            return (true, nil)
        }
        if text.hasPrefix("Stack memory:") {
            inStack = true
            return (!hidesStack, nil)
        }
        return (!(hidesStack && inStack), nil)
    }
}

/// Turns a crash dump into a backtrace with function names, files and
/// lines, as ESP-IDF's monitor does: ESP-IDF's GDB reads the firmware's
/// symbols and unwinds the stack in the dump, which ESP-IDF's panic decoder
/// serves to it as if it were the board. Swift names are demangled.
public struct PanicDecoder: Sendable {
    public var system: System
    /// The firmware, with its symbols.
    public var elf: String
    /// The project folder, for showing its files' paths.
    public var projectFolder: String
    public var gdb: String
    /// The Python of ESP-IDF's environment, which has the panic decoder.
    public var python: String
    public var demangler: String?

    public init(system: System, elf: String, projectFolder: String, gdb: String, python: String, demangler: String?) {
        self.system = system
        self.elf = elf
        self.projectFolder = projectFolder
        self.gdb = gdb
        self.python = python
        self.demangler = demangler
    }

    /// A decoder for a build, or nil if something it needs is missing (then
    /// crashes are shown as the board prints them).
    public init?(system: System, build: LastBuild) {
        guard let elf = try? Debug(system: system).firmware(of: build),
              let environment = try? ESPIDF(system: system).environment(),
              let gdb = environment["PATH"].flatMap({ path in
                  path.split(separator: ":").map { "\($0)/riscv32-esp-elf-gdb" }.first(where: system.fileExists)
              }) else { return nil }
        let locations = Locations(system: system)
        let demangler = system.readFile(locations.swiftToolchainRecord)?.split(separator: "\n").first
            .map { Setup.path(String($0), "usr/bin/swift-demangle") }
        self.init(system: system, elf: elf, projectFolder: Resources.parent(of: build.sourceFolder), gdb: gdb,
                  python: ESPIDF.python(environment), demangler: demangler.flatMap { system.fileExists($0) ? $0 : nil })
    }

    /// The backtrace of a dump, as lines to show; empty if GDB couldn't
    /// work it out.
    public func decode(_ dump: String) -> [String] {
        let file = "\(system.environment["TMPDIR"] ?? "/tmp")/espswift-panic-\(ProcessInfo.processInfo.processIdentifier).txt"
        guard (try? system.writeFile(file, dump)) != nil else { return [] }
        defer { try? system.removeItem(file) }
        guard let output = system.run(gdb, [
            "--batch", "-n", elf, "-ex", "set width 0",
            "-ex", "target remote | \"\(python)\" -m esp_idf_panic_decoder \"\(file)\"", "-ex", "bt",
        ])?.output else { return [] }
        let frames = Self.frames(inGDBOutput: output)
        guard !frames.isEmpty else { return [] }
        let names = demangled(frames.map(\.name))
        return ["", "Backtrace (decoded by espswift):"] + frames.enumerated().map { index, frame in
            let location = frame.file.map { " at \(display($0)):\(frame.line ?? 0)" } ?? ""
            return "  #\(index) \(names[frame.name] ?? frame.name)\(location)"
        } + [""]
    }

    /// A frame of GDB's backtrace.
    struct Frame: Equatable {
        var name: String
        var file: String?
        var line: Int?
    }

    /// The frames in GDB's output: lines such as
    /// `#3  0x4200013c in $e8Firmware7computeyS2iF (index=...) at /p/Firmware.swift:11`.
    static func frames(inGDBOutput output: String) -> [Frame] {
        output.split(separator: "\n").compactMap { line -> Frame? in
            var text = String(line)
            guard let number = text.range(of: #"^#\d+\s+"#, options: .regularExpression) else { return nil }
            text.removeSubrange(number)
            if let address = text.range(of: #"^0x[0-9a-fA-F]+ in "#, options: .regularExpression) {
                text.removeSubrange(address)
            }
            var file: String?
            var lineNumber: Int?
            if let at = text.range(of: #" at (\S+):(\d+)$"#, options: .regularExpression) {
                let location = text[at].dropFirst(4)
                if let colon = location.lastIndex(of: ":") {
                    file = String(location[..<colon])
                    lineNumber = Int(location[location.index(after: colon)...])
                }
                text.removeSubrange(at)
            }
            // The arguments: "(index=...)" after the name.
            if let arguments = text.range(of: " (", options: .backwards), text.hasSuffix(")") {
                text.removeSubrange(arguments.lowerBound...)
            }
            return Frame(name: text, file: file, line: lineNumber)
        }
    }

    /// Swift's names, demangled (`$e8Firmware7computeyS2iF` is
    /// `compute(_:)`); C names stay as they are.
    func demangled(_ names: [String]) -> [String: String] {
        let mangled = Array(Set(names.filter { $0.hasPrefix("$e") || $0.hasPrefix("$s") || $0.hasPrefix("_$s") })).sorted()
        guard let demangler, !mangled.isEmpty,
              let output = system.run(demangler, ["--simplified", "--compact"] + mangled)?.output else { return [:] }
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count >= mangled.count else { return [:] }
        return Dictionary(uniqueKeysWithValues: zip(mangled, lines.prefix(mangled.count)))
    }

    /// A path relative to the project folder if it's in it, else with ~.
    func display(_ path: String) -> String {
        if path.hasPrefix(projectFolder + "/") { return String(path.dropFirst(projectFolder.count + 1)) }
        return Locations(system: system).display(path, home: system.homeDirectory)
    }
}
