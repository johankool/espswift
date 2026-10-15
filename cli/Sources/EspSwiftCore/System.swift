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

/// What espswift reads from the system it runs on: files, the environment,
/// and the output of commands. Commands use it instead of Foundation
/// directly, so tests can give them a system of their own (see FakeSystem in
/// the tests).
public protocol System: Sendable {
    var operatingSystem: OperatingSystem { get }
    var homeDirectory: String { get }
    var environment: [String: String] { get }
    func fileExists(_ path: String) -> Bool
    func isDirectory(_ path: String) -> Bool
    /// The names of the entries in a folder; empty if it doesn't exist.
    func contentsOfDirectory(_ path: String) -> [String]
    func readFile(_ path: String) -> String?
    /// Runs a program and waits for it; nil if it couldn't be started.
    func run(_ executable: String, _ arguments: [String]) -> CommandResult?
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
}
