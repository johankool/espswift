import CSerialPort
import Foundation

/// The operating systems espswift runs on.
public enum OperatingSystem: String, Sendable {
    case macOS
    case linux

    /// The system espswift was built for.
    public static var current: OperatingSystem {
        #if os(macOS)
        .macOS
        #else
        .linux
        #endif
    }
}

/// The output and exit status of a command.
public struct CommandResult: Sendable {
    public var status: Int32
    /// Standard output and standard error together.
    public var output: String

    public init(status: Int32, output: String) {
        self.status = status
        self.output = output
    }
}

/// An error with a message for the user.
public struct EspSwiftError: Error, CustomStringConvertible, Equatable {
    public var description: String

    public init(_ description: String) {
        self.description = description
    }
}

/// What espswift does on the system it runs on: files, the environment,
/// running programs and talking to the user. Commands use it instead of
/// Foundation directly, so tests can give them a system of their own (see
/// FakeSystem in the tests).
public protocol System: Sendable {
    var operatingSystem: OperatingSystem { get }
    var homeDirectory: String { get }
    var environment: [String: String] { get }
    /// The path of the running espswift, with symbolic links resolved.
    var executablePath: String? { get }
    var currentDirectory: String { get }

    // ── Reading ──
    func fileExists(_ path: String) -> Bool
    func isDirectory(_ path: String) -> Bool
    /// The names of the entries in a folder; empty if it doesn't exist.
    func contentsOfDirectory(_ path: String) -> [String]
    func readFile(_ path: String) -> String?
    func readData(_ path: String) -> Data?
    /// The path with symbolic links resolved.
    func resolvingSymlinks(_ path: String) -> String

    // ── Changing ──
    func createDirectory(_ path: String) throws
    /// Removes a file or a folder with everything in it.
    func removeItem(_ path: String) throws
    /// Copies a file, or a folder's contents into a folder, replacing files
    /// that are there and keeping others (like `cp -R from/. to`).
    func copyContents(of source: String, to destination: String) throws
    /// Creates (or replaces) a symbolic link.
    func createSymbolicLink(at path: String, to destination: String) throws
    func writeFile(_ path: String, _ data: Data) throws
    func makeExecutable(_ path: String) throws

    // ── Programs ──
    /// Runs a program and waits for it, collecting its output; nil if it
    /// couldn't be started.
    func run(_ executable: String, _ arguments: [String]) -> CommandResult?
    /// Runs a program with its output going to the terminal, for long steps
    /// such as downloads; returns its exit status (-1 if it couldn't start).
    func runVisibly(_ executable: String, _ arguments: [String], environment: [String: String]) -> Int32
    /// Runs a program, passing each line of its output (standard output and
    /// standard error) to `onLine` as it comes; returns its exit status (-1
    /// if it couldn't start).
    func runStreaming(_ executable: String, _ arguments: [String], environment: [String: String],
                      onLine: (String) -> Void) -> Int32

    // ── Background programs (OpenOCD, while debugging) ──
    /// Starts a program in the background, with its output going to a
    /// file; returns its process ID.
    func startInBackground(_ executable: String, _ arguments: [String], environment: [String: String],
                           output: String) throws -> Int32
    func isRunning(_ process: Int32) -> Bool
    func terminate(_ process: Int32)
    /// Whether Ctrl+C stops espswift (and the programs it starts from then
    /// on). Off while a debugger runs, which uses Ctrl+C to pause.
    func ignoreInterrupts(_ ignore: Bool)

    // ── Serial ports ──
    /// Opens a serial port for reading at a baud rate; returns a handle.
    func openSerialPort(_ path: String, baudRate: Int) throws -> Int32
    /// Reads what arrived; nil when the port is gone (the board was
    /// unplugged or reset).
    func readSerialPort(_ handle: Int32) -> Data?
    func closeSerialPort(_ handle: Int32)
    /// Writes to standard output as is, without a newline.
    func writeOutput(_ data: Data)
    func sleep(seconds: Double)

    // ── The user ──
    /// Shows a line of progress.
    func report(_ message: String)
    /// Whether espswift can ask questions (it runs in a terminal).
    var isInteractive: Bool { get }
    /// Asks a question and returns the answer; nil if there is none.
    func ask(_ question: String) -> String?
}

extension System {
    /// The folders searched for programs: PATH, then the places Homebrew
    /// installs to. Xcode runs builds with a PATH that doesn't include them.
    public var searchPath: [String] {
        let path = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        return path + ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"].filter { !path.contains($0) }
    }

    /// The full path of a program found in the search path.
    public func findExecutable(_ name: String) -> String? {
        searchPath.map { "\($0)/\(name)" }.first(where: fileExists)
    }

    public func writeFile(_ path: String, _ text: String) throws {
        try writeFile(path, Data(text.utf8))
    }

    /// Asks a yes/no question. Without a terminal, the default is the answer.
    public func confirm(_ question: String, default defaultAnswer: Bool) -> Bool {
        guard isInteractive else { return defaultAnswer }
        let answer = ask("\(question) \(defaultAnswer ? "[Y/n]" : "[y/N]") ")?
            .trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        return answer.isEmpty ? defaultAnswer : answer.hasPrefix("y")
    }
}

/// The system espswift runs on.
public struct LiveSystem: System {
    public init() {}

    public var operatingSystem: OperatingSystem { .current }

    public var homeDirectory: String {
        environment["HOME"] ?? NSHomeDirectory()
    }

    public var environment: [String: String] {
        ProcessInfo.processInfo.environment
    }

    public var executablePath: String? {
        Bundle.main.executableURL?.resolvingSymlinksInPath().path
    }

    public var currentDirectory: String {
        FileManager.default.currentDirectoryPath
    }

    public func fileExists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    public func isDirectory(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    public func contentsOfDirectory(_ path: String) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
    }

    public func readFile(_ path: String) -> String? {
        try? String(contentsOfFile: path, encoding: .utf8)
    }

    public func readData(_ path: String) -> Data? {
        FileManager.default.contents(atPath: path)
    }

    public func resolvingSymlinks(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    }

    public func createDirectory(_ path: String) throws {
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    }

    public func removeItem(_ path: String) throws {
        // Also removes a symbolic link whose destination is gone.
        if fileExists(path) || (try? FileManager.default.destinationOfSymbolicLink(atPath: path)) != nil {
            try FileManager.default.removeItem(atPath: path)
        }
    }

    public func copyContents(of source: String, to destination: String) throws {
        guard isDirectory(source) else {
            try removeItem(destination)
            try FileManager.default.copyItem(atPath: source, toPath: destination)
            return
        }
        try createDirectory(destination)
        for entry in contentsOfDirectory(source) {
            try copyContents(of: "\(source)/\(entry)", to: "\(destination)/\(entry)")
        }
    }

    public func createSymbolicLink(at path: String, to destination: String) throws {
        try removeItem(path)
        try FileManager.default.createSymbolicLink(atPath: path, withDestinationPath: destination)
    }

    public func writeFile(_ path: String, _ data: Data) throws {
        try data.write(to: URL(fileURLWithPath: path))
    }

    public func makeExecutable(_ path: String) throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
    }

    public func run(_ executable: String, _ arguments: [String]) -> CommandResult? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return nil
        }
        // Read before waiting, so a long output can't fill the pipe and
        // block the program.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return CommandResult(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }

    public func runVisibly(_ executable: String, _ arguments: [String], environment: [String: String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment
        do {
            try process.run()
        } catch {
            return -1
        }
        process.waitUntilExit()
        return process.terminationStatus
    }

    public func runStreaming(_ executable: String, _ arguments: [String], environment: [String: String],
                             onLine: (String) -> Void) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return -1
        }
        // Lines as they come; a line split over two reads is joined first.
        var pending = Data()
        let reader = pipe.fileHandleForReading
        while true {
            let data = reader.availableData
            if data.isEmpty { break }
            pending.append(data)
            while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
                onLine(String(decoding: pending[pending.startIndex..<newline], as: UTF8.self))
                pending.removeSubrange(pending.startIndex...newline)
            }
        }
        if !pending.isEmpty {
            onLine(String(decoding: pending, as: UTF8.self))
        }
        process.waitUntilExit()
        return process.terminationStatus
    }

    public func startInBackground(_ executable: String, _ arguments: [String], environment: [String: String],
                                  output: String) throws -> Int32 {
        FileManager.default.createFile(atPath: output, contents: nil)
        guard let file = FileHandle(forWritingAtPath: output) else {
            throw EspSwiftError("Can't write \(output).")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment
        process.standardOutput = file
        process.standardError = file
        try process.run()
        return process.processIdentifier
    }

    public func isRunning(_ process: Int32) -> Bool {
        kill(process, 0) == 0
    }

    public func terminate(_ process: Int32) {
        kill(process, SIGTERM)
    }

    public func ignoreInterrupts(_ ignore: Bool) {
        signal(SIGINT, ignore ? SIG_IGN : SIG_DFL)
    }

    public func openSerialPort(_ path: String, baudRate: Int) throws -> Int32 {
        let handle = espswift_serial_open(path, Int32(baudRate))
        guard handle >= 0 else {
            throw EspSwiftError("Can't open \(path): \(String(cString: strerror(errno))).")
        }
        return handle
    }

    public func readSerialPort(_ handle: Int32) -> Data? {
        var buffer = [UInt8](repeating: 0, count: 1024)
        while true {
            let count = read(handle, &buffer, buffer.count)
            if count > 0 { return Data(buffer[0..<count]) }
            if count < 0 && errno == EINTR { continue }
            return nil
        }
    }

    public func closeSerialPort(_ handle: Int32) {
        close(handle)
    }

    public func writeOutput(_ data: Data) {
        FileHandle.standardOutput.write(data)
    }

    public func sleep(seconds: Double) {
        Thread.sleep(forTimeInterval: seconds)
    }

    public func report(_ message: String) {
        print(message)
        // Before the output of programs espswift runs, also into a file.
        fflush(nil)  // all streams; Glibc's stdout is a mutable global Swift 6 rejects
    }

    public var isInteractive: Bool {
        isatty(STDIN_FILENO) != 0
    }

    public func ask(_ question: String) -> String? {
        print(question, terminator: "")
        fflush(nil)  // all streams; Glibc's stdout is a mutable global Swift 6 rejects
        return readLine()
    }
}
