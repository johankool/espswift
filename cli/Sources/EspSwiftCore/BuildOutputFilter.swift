import Foundation

/// Turns ESP-IDF's build output (idf.py) into what Xcode shows well: the
/// errors and warnings, as lines Xcode lists in the Issue navigator and that
/// jump to the file and line when clicked, and little else. `espswift build`
/// passes idf.py's output through it, line by line, and keeps the full
/// output in a log file.
///
/// - Compiler errors and warnings (Swift, Clang and GCC) are already in the
///   format Xcode recognizes, "/path/file.swift:12:5: error: message", and
///   pass through unchanged, with the source excerpts Swift prints.
/// - CMake errors and warnings ("CMake Error at main/CMakeLists.txt:23")
///   become one line in that format, located at the first line of the
///   project's own files in CMake's call stack. CMake warnings that come
///   from ESP-IDF itself, not from the project, are left out.
/// - Unknown options in sdkconfig.defaults, which ESP-IDF only notes in
///   passing, become warnings on their line.
/// - The rest (CMake's configuration messages, ninja's progress lines and
///   failed commands, idf.py's own messages and flashing instructions,
///   which don't apply here, as Cmd+R flashes) is left out, except for an
///   occasional progress line and the firmware size.
public struct BuildOutputFilter {
    /// The project's source folder (with CMakeLists.txt); CMake names the
    /// project's files relative to it.
    public let sourceFolder: String
    /// The project folder (with the Xcode project). Files in it are the
    /// project's own, except for downloaded libraries and build output.
    public let projectFolder: String
    /// Reads a file (sdkconfig.defaults, to find an option's line).
    let readFile: (String) -> String?

    /// The number of errors passed on, so a failed build without any can be
    /// explained.
    public private(set) var errorCount = 0

    private var skipNext = false
    private var blank = true
    private var done = false
    private var inPartitions = false
    private var partitionRules = 0
    private var progressTotal = 0
    private var progressShown = -1
    private var cmake: CMakeMessage?

    private struct CMakeMessage {
        var isError: Bool
        var message = ""
        var locations: [String] = []
        var inStack = false
    }

    public init(sourceFolder: String, readFile: @escaping (String) -> String?) {
        self.sourceFolder = sourceFolder
        projectFolder = Resources.parent(of: sourceFolder)
        self.readFile = readFile
    }

    /// The lines to show for a line of idf.py's output.
    public mutating func process(_ rawLine: String) -> [String] {
        let line = Self.removingEscapeCodes(rawLine)
        if skipNext {
            // The command ninja prints after "FAILED:"; the errors follow it.
            skipNext = false
            return []
        }

        // ── CMake messages ──
        if var message = cmake {
            if line.hasPrefix("Call Stack") {
                message.inStack = true
                cmake = message
                return []
            }
            if line.hasPrefix("  ") || line.isEmpty {
                if message.inStack {
                    if let location = Self.location(in: line) { message.locations.append(location) }
                } else if !line.isEmpty {
                    message.message += " " + line
                }
                cmake = message
                return []
            }
            return flushCMake() + process(line)
        }
        if let isError = Self.cmakeHeader(line) {
            var message = CMakeMessage(isError: isError)
            if let location = Self.location(in: line) {
                message.locations.append(location)
            } else if let colon = line.range(of: ": ") {
                // "CMake Error: message", without a file.
                message.message = String(line[colon.upperBound...])
            }
            cmake = message
            return []
        }

        // ── ESP-IDF configuration (Kconfig) ──
        // "NOTE: unknown kconfig symbol 'FOO' assigned to 'y' in .../sdkconfig.defaults"
        if line.hasPrefix("NOTE: unknown kconfig symbol '") {
            let rest = line.dropFirst("NOTE: unknown kconfig symbol '".count)
            let symbol = String(rest.prefix(while: { $0 != "'" }))
            let file = line.range(of: " in ", options: .backwards).map { String(line[$0.upperBound...]) } ?? ""
            var lineNumber: Int?
            if let text = readFile(file) {
                lineNumber = text.split(separator: "\n", omittingEmptySubsequences: false)
                    .firstIndex { $0.hasPrefix("CONFIG_\(symbol)=") }.map { $0 + 1 }
            }
            let place = isProjectFile(file) ? "\(file)\(lineNumber.map { ":\($0)" } ?? ""): " : ""
            return output("\(place)warning: Unknown ESP-IDF option CONFIG_\(symbol); it has no effect. Check its name with idf.py menuconfig.")
        }

        // ── Noise ──
        if line.hasPrefix("FAILED: ") {
            skipNext = true
            return []
        }
        if Self.isNoise(line) { return [] }
        if line.hasPrefix("Partition table binary generated") {
            inPartitions = true
            return []
        }
        if inPartitions {
            if !line.isEmpty && line.allSatisfy({ $0 == "*" }) {
                partitionRules += 1
                if partitionRules == 2 { inPartitions = false; partitionRules = 0 }
            }
            return []
        }
        // The flashing instructions idf.py prints last; Cmd+R flashes.
        if line.hasPrefix("Project build complete. To flash") { done = true }
        if done { return [] }

        // ninja: "[12/1103] Building C object ...". Shows one line per tenth
        // of a long build, so it's clear the build is progressing. The
        // bootloader is built by a smaller ninja build within it, whose
        // progress isn't shown.
        if let (step, total) = Self.progress(line) {
            if total > progressTotal { progressTotal = total; progressShown = -1 }
            if total == progressTotal && progressTotal >= 50 {
                let tenth = step * 10 / progressTotal
                if tenth > progressShown {
                    progressShown = tenth
                    blank = false
                    return output("Building... \(tenth * 10)% (\(step) of \(progressTotal) steps)")
                }
            }
            return []
        }

        // ── Everything else ──
        if line.isEmpty {
            // Collapse runs of blank lines.
            if blank { return [] }
            blank = true
        } else {
            blank = false
        }
        return output(line)
    }

    /// The lines still to show at the end of the output.
    public mutating func finish() -> [String] {
        cmake == nil ? [] : flushCMake()
    }

    // ── Helpers ──────────────────────────────────────────────────────

    private mutating func output(_ line: String) -> [String] {
        if Self.isError(line) { errorCount += 1 }
        return [line]
    }

    /// A CMake message as one Xcode issue, located at the first of the
    /// project's own files in its location and call stack.
    private mutating func flushCMake() -> [String] {
        guard let message = cmake else { return [] }
        cmake = nil
        var place = ""
        for location in message.locations {
            guard let colon = location.lastIndex(of: ":") else { continue }
            let path = absolute(String(location[..<colon]))
            if isProjectFile(path) {
                place = "\(path)\(location[colon...]): "
                break
            }
        }
        var text = message.message.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        if text.isEmpty { text = message.isError ? "CMake error" : "CMake warning" }
        if message.isError {
            return output("\(place)error: \(text)")
        }
        // Warnings outside the project come from ESP-IDF or a library.
        return place.isEmpty ? [] : output("\(place)warning: \(text)")
    }

    /// An absolute path for a file CMake names, which may be relative to
    /// the source folder.
    private func absolute(_ path: String) -> String {
        path.hasPrefix("/") ? path : "\(sourceFolder)/\(path)"
    }

    /// Whether a file is one of the project's own, which the user can edit.
    private func isProjectFile(_ path: String) -> Bool {
        path.hasPrefix(projectFolder + "/")
            && !path.contains("/managed_components/")
            && !path.hasPrefix(sourceFolder + "/build/")
    }

    static func isError(_ line: String) -> Bool {
        if line.hasPrefix("error: ") { return true }
        guard let range = line.range(of: ": error: ") else { return false }
        return !line[..<range.lowerBound].contains(" ")
    }

    /// "CMake Error at …", "CMake Warning (dev) at …", "CMake Error: …":
    /// whether it's an error; nil for other lines.
    static func cmakeHeader(_ line: String) -> Bool? {
        let kinds = ["Error", "Warning", "Deprecation Error", "Deprecation Warning"]
        for kind in kinds {
            for variant in ["CMake \(kind) (dev)", "CMake \(kind)"] where line.hasPrefix(variant) {
                let rest = line.dropFirst(variant.count)
                if rest.hasPrefix(" at ") || rest.hasPrefix(":") {
                    return kind.hasSuffix("Error")
                }
            }
        }
        return nil
    }

    /// The "file:line" in "CMake Error at file:line (command):" or in a call
    /// stack line, "  file:line (command)".
    static func location(in line: String) -> String? {
        for word in line.split(separator: " ") {
            guard let colon = word.lastIndex(of: ":"), colon != word.startIndex else { continue }
            let number = word[word.index(after: colon)...]
            // The words share the line's indices: is the word followed by " ("?
            if !number.isEmpty, number.allSatisfy(\.isNumber), line[word.endIndex...].hasPrefix(" (") {
                return String(word)
            }
        }
        return nil
    }

    /// ninja's "[12/1103] …" as (12, 1103).
    static func progress(_ line: String) -> (Int, Int)? {
        guard line.hasPrefix("["), let close = line.firstIndex(of: "]"),
              line[line.index(after: close)...].hasPrefix(" ") else { return nil }
        let parts = line[line.index(after: line.startIndex)..<close].split(separator: "/")
        guard parts.count == 2, let step = Int(parts[0]), let total = Int(parts[1]) else { return nil }
        return (step, total)
    }

    static func isNoise(_ line: String) -> Bool {
        let prefixes = [
            "-- ", "NOTE: ", "Loading defaults file ", "CMake Generate step failed",
            "ninja: build stopped", "ninja: error: rebuilding", "ninja: no work to do",
            "ninja failed with exit code ", "cmake failed with exit code ",
            "Executing action: ", "Running ninja in directory ", "Running cmake in directory ", "Executing \"",
            "esptool v", "Merged ", "Successfully created ESP32", "Bootloader binary size ",
            "Skipping linker script generation",
            // SwiftPM, building the Swift package.
            "Building for production...", "Building for debugging...", "Build complete!",
            "warning: '--build-system native' has been deprecated",
            // A bridging header with an error also fails its precompiled
            // header; the error itself is listed already.
            "error: generate-pch command failed", "<unknown>:0: error: failed to emit precompiled header",
        ]
        if prefixes.contains(where: line.hasPrefix) { return true }
        if line.hasPrefix("Creating ESP32") && line.hasSuffix(" image...") { return true }
        if line.hasPrefix("Generated /") && line.hasSuffix(".bin") { return true }
        if line.hasPrefix("Build of product ") && line.contains(" complete!") { return true }
        if line.hasSuffix(" error generated.") || line.hasSuffix(" errors generated.") {
            return line.prefix(while: \.isNumber).count > 0
        }
        // Building the macros of a dependency for the Mac.
        if line.hasPrefix("ld: warning: building for macOS-") && line.contains("which was built for newer version") {
            return true
        }
        return false
    }

    /// Removes terminal color codes (ESC [ … letter) and hyperlinks
    /// (ESC ] … ESC \), which Xcode would show as text, and a trailing CR.
    static func removingEscapeCodes(_ line: String) -> String {
        guard line.contains("\u{1B}") || line.hasSuffix("\r") else { return line }
        var result = ""
        var characters = line.makeIterator()
        while let character = characters.next() {
            guard character == "\u{1B}" else {
                result.append(character)
                continue
            }
            switch characters.next() {
            case "[":
                while let next = characters.next(), !next.isLetter {}
            case "]":
                var previous: Character?
                while let next = characters.next() {
                    if previous == "\u{1B}" && next == "\\" { break }
                    previous = next
                }
            default:
                break
            }
        }
        if result.hasSuffix("\r") { result.removeLast() }
        return result
    }
}
