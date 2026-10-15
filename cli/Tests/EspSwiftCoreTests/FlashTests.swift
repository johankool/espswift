@testable import EspSwiftCore
import Foundation
import Testing

@Suite struct MonitorTests {
    @Test func showsOutputAndReconnectsAfterAReset() throws {
        let system = FakeSystem()
        system.file("/dev/cu.usbmodem1", "")
        system.serialConnections["/dev/cu.usbmodem1"] = [
            [Data("Hello from ".utf8), Data("Embedded Swift\n".utf8)],
            [Data("LED: Red\n".utf8)],
        ]
        try Monitor(system: system, port: "/dev/cu.usbmodem1").run(reconnects: 1)
        #expect(String(decoding: system.output, as: UTF8.self) == "Hello from Embedded Swift\nLED: Red\n")
        #expect(system.actions == ["open /dev/cu.usbmodem1 115200", "close", "open /dev/cu.usbmodem1 115200", "close"])
        #expect(system.reports.contains { $0.contains("went away") })
    }

    @Test func waitsForThePort() throws {
        let system = FakeSystem()
        system.serialConnections["/dev/ttyACM0"] = [[Data("boot\n".utf8)]]
        // The port appears after the second look.
        var looks = 0
        system.effects["sleep"] = { system, _ in
            looks += 1
            if looks == 2 { system.file("/dev/ttyACM0", "") }
            return 0
        }
        let fake = SleepCountingSystem(system)
        try Monitor(system: fake, port: "/dev/ttyACM0").run(reconnects: 0)
        #expect(String(decoding: system.output, as: UTF8.self) == "boot\n")
        #expect(system.reports.filter { $0.hasPrefix("Waiting for") }.count == 1)
    }
}

/// A FakeSystem whose sleep runs its "sleep" effect, so a test can change
/// the system while something waits.
final class SleepCountingSystem: System, @unchecked Sendable {
    let base: FakeSystem
    init(_ base: FakeSystem) { self.base = base }
    var operatingSystem: OperatingSystem { base.operatingSystem }
    var homeDirectory: String { base.homeDirectory }
    var environment: [String: String] { base.environment }
    var executablePath: String? { base.executablePath }
    var currentDirectory: String { base.currentDirectory }
    func fileExists(_ path: String) -> Bool { base.fileExists(path) }
    func isDirectory(_ path: String) -> Bool { base.isDirectory(path) }
    func contentsOfDirectory(_ path: String) -> [String] { base.contentsOfDirectory(path) }
    func readFile(_ path: String) -> String? { base.readFile(path) }
    func readData(_ path: String) -> Data? { base.readData(path) }
    func createDirectory(_ path: String) throws { try base.createDirectory(path) }
    func removeItem(_ path: String) throws { try base.removeItem(path) }
    func copyContents(of source: String, to destination: String) throws { try base.copyContents(of: source, to: destination) }
    func createSymbolicLink(at path: String, to destination: String) throws { try base.createSymbolicLink(at: path, to: destination) }
    func writeFile(_ path: String, _ data: Data) throws { try base.writeFile(path, data) }
    func makeExecutable(_ path: String) throws { try base.makeExecutable(path) }
    func run(_ executable: String, _ arguments: [String]) -> CommandResult? { base.run(executable, arguments) }
    func runVisibly(_ executable: String, _ arguments: [String], environment: [String: String]) -> Int32 {
        base.runVisibly(executable, arguments, environment: environment)
    }
    func runStreaming(_ executable: String, _ arguments: [String], environment: [String: String],
                      onLine: (String) -> Void) -> Int32 {
        base.runStreaming(executable, arguments, environment: environment, onLine: onLine)
    }
    func openSerialPort(_ path: String, baudRate: Int) throws -> Int32 { try base.openSerialPort(path, baudRate: baudRate) }
    func readSerialPort(_ handle: Int32) -> Data? { base.readSerialPort(handle) }
    func closeSerialPort(_ handle: Int32) { base.closeSerialPort(handle) }
    func writeOutput(_ data: Data) { base.writeOutput(data) }
    func sleep(seconds: Double) { _ = base.effects["sleep"]?(base, []) }
    func report(_ message: String) { base.report(message) }
    var isInteractive: Bool { base.isInteractive }
    func ask(_ question: String) -> String? { base.ask(question) }
}

@Suite struct FlashTests {
    @Test func flashesTheProjectsLastBuild() throws {
        let system = BuildTests.system()
        let project = try Project.find(system: system, start: "/Users/test/Blink")
        // Without a record, ./build; with one for this project, its folder.
        #expect(Flash.buildFolder(for: project, system: system) == "/Users/test/Blink/Blink/build")
        system.file("/Users/test/.espswift/last-build", "/Users/test/Blink/Blink\n/Users/test/DerivedData/esp-idf\n")
        #expect(Flash.buildFolder(for: project, system: system) == "/Users/test/DerivedData/esp-idf")
        system.file("/Users/test/.espswift/last-build", "/Users/test/Other/Other\n/Users/test/DerivedData/other\n")
        #expect(Flash.buildFolder(for: project, system: system) == "/Users/test/Blink/Blink/build")
    }

    @Test func runsIdfFlash() throws {
        let system = BuildTests.system()
        system.file("/Users/test/Blink/Blink/build/flasher_args.json", "{}")
        try Flash(system: system).run(sourceFolder: "/Users/test/Blink/Blink", buildFolder: "/Users/test/Blink/Blink/build",
                                      port: "/dev/cu.usbmodem1")
        #expect(system.actions.contains("run /Users/test/.espressif/python_env/idf6.1_py3.14_env/bin/python /Users/test/.espswift/esp-idf/tools/idf.py -C /Users/test/Blink/Blink -B /Users/test/Blink/Blink/build -p /dev/cu.usbmodem1 flash"))
    }

    @Test func needsABuild() {
        let system = BuildTests.system()
        #expect(throws: EspSwiftError.self) {
            try Flash(system: system).run(sourceFolder: "/x", buildFolder: "/x/build", port: "/dev/cu.usbmodem1")
        }
        #expect(!system.actions.contains { $0.hasPrefix("run ") })
    }

    @Test func choosesThePort() throws {
        let system = FakeSystem.workingMac
        #expect(try SerialPorts.choose(nil, system: system) == "/dev/cu.usbmodem21101")
        #expect(try SerialPorts.choose("/dev/cu.other", system: system) == "/dev/cu.other")
        system.environment["ESPSWIFT_PORT"] = "/dev/cu.env"
        #expect(try SerialPorts.choose(nil, system: system) == "/dev/cu.env")
        system.environment["ESPSWIFT_PORT"] = nil
        system.files["/dev/cu.usbmodem21101"] = nil
        #expect(throws: EspSwiftError.self) { try SerialPorts.choose(nil, system: system) }
    }
}
