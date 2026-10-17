import Foundation

/// Shows a board's serial output: `espswift monitor`, and the last step of
/// `espswift run` (Cmd+R in Xcode, whose console then shows the output).
///
/// When the port goes away (the board resets, as after flashing, or is
/// unplugged), it waits for the port and continues.
///
/// With a decoder, a crash's dump is followed by its backtrace, with
/// function names, files and lines, and the dump's stack is left out.
public struct Monitor: Sendable {
    public var system: System
    public var port: String
    public var baudRate = 115200
    public var decoder: PanicDecoder?

    public init(system: System, port: String, decoder: PanicDecoder? = nil) {
        self.system = system
        self.port = port
        self.decoder = decoder
    }

    /// Runs until stopped (Ctrl+C, or Stop in Xcode). `reconnects` limits
    /// how often it reconnects, for tests.
    public func run(reconnects: Int = .max) throws {
        system.report("=================================================")
        system.report(" ESP32 Serial Monitor")
        system.report(" Port: \(port) @ \(baudRate) baud")
        system.report("=================================================")
        var remaining = reconnects
        var waiting = false
        var watcher = PanicDumpWatcher(hidesStack: decoder != nil)
        var lastRegisters: String?
        while true {
            guard system.fileExists(port) else {
                if !waiting {
                    system.report("Waiting for \(port)...")
                    waiting = true
                }
                system.sleep(seconds: 0.2)
                continue
            }
            waiting = false
            let handle: Int32
            do {
                handle = try system.openSerialPort(port, baudRate: baudRate)
            } catch {
                // Just reappeared, and not ready yet.
                system.sleep(seconds: 0.2)
                continue
            }
            while let data = system.readSerialPort(handle) {
                for event in watcher.process(data) {
                    switch event {
                    case .output(let output):
                        system.writeOutput(output)
                    case .dump(let dump):
                        guard let decoder else { continue }
                        // A crash at startup repeats after every reset: decode it once.
                        let registers = Self.registers(of: dump)
                        if registers == lastRegisters {
                            system.report("(The same crash as before; its backtrace is above.)")
                            continue
                        }
                        lastRegisters = registers
                        for line in decoder.decode(dump) { system.report(line) }
                    }
                }
            }
            system.closeSerialPort(handle)
            guard remaining > 0 else { return }
            remaining -= 1
            system.report("")
            system.report("(\(port) went away; the board reset or was unplugged.)")
        }
    }

    /// A dump's registers, which tell crashes apart (the stack has the same
    /// values in another order after a reset, or other leftovers).
    static func registers(of dump: String) -> String {
        // The board ends lines with \r\n, which is one Character.
        dump.split(whereSeparator: \.isNewline).prefix { !$0.hasPrefix("Stack memory:") }.joined(separator: "\n")
    }

    /// ESP-IDF's own monitor (idf.py monitor), for a terminal: it decodes
    /// crash backtraces into file and line, and sends what you type to the
    /// board. It needs the build folder, for the firmware's symbols.
    public static func idfMonitor(system: System, port: String, project: Project, buildFolder: String) throws {
        let environment = try ESPIDF(system: system).environment()
        let status = system.runVisibly(ESPIDF.python(environment), [
            ESPIDF.idfPy(Locations(system: system)), "-C", project.sourceFolder, "-B", buildFolder, "-p", port, "monitor",
        ], environment: environment)
        guard status == 0 else { throw EspSwiftError("idf.py monitor failed.") }
    }
}
