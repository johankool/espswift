import Foundation

/// Debugs the firmware on the board with LLDB: `espswift debug`. Breakpoints
/// in Swift (and C), stepping, backtraces and variables.
///
/// It uses the chip's built-in USB-JTAG, so the board must be connected
/// through its native USB port (on the ESP32-C6-DevKitC-1 the port labelled
/// "USB", not "UART"). The ESP32-C2 has no built-in USB-JTAG and needs an
/// external JTAG adapter, which this doesn't set up.
///
/// It debugs the build that was flashed last (Cmd+R, or espswift run):
/// OpenOCD talks to the chip, and LLDB connects to it. Connecting resets the
/// chip, so it lets the firmware start up and pauses it before handing over
/// the (lldb) prompt. Quitting LLDB stops OpenOCD and lets the firmware
/// continue.
///
/// Breakpoints are hardware breakpoints, as the code runs from flash
/// (software breakpoints there crash the chip). The chips have 4 of them.
public struct Debug: Sendable {
    public var system: System
    public var locations: Locations

    public init(system: System) {
        self.system = system
        locations = Locations(system: system)
    }

    public func run(build: LastBuild) throws {
        let elf = try firmware(of: build)
        let chip = Project.chip(inConfig: system.readFile("\(build.sourceFolder)/sdkconfig")) ?? "esp32c6"
        let environment = try ESPIDF(system: system).environment()
        let config = "board/\(chip)-builtin.cfg"
        guard let scripts = environment["OPENOCD_SCRIPTS"], system.fileExists("\(scripts)/\(config)") else {
            throw EspSwiftError("The \(chip) has no built-in USB-JTAG; debugging it needs an external JTAG adapter.")
        }
        guard let openocd = environment["PATH"].flatMap({ path in
            path.split(separator: ":").map { "\($0)/openocd" }.first(where: system.fileExists)
        }) else {
            throw EspSwiftError("OpenOCD wasn't found. Run: espswift setup")
        }
        let lldb = try findLLDB()

        let work = "\(system.environment["TMPDIR"] ?? "/tmp")/espswift-debug-\(ProcessInfo.processInfo.processIdentifier)"
        try system.createDirectory(work)
        defer { try? system.removeItem(work) }

        // OpenOCD ignores Ctrl+C, which pauses the firmware in LLDB, and so
        // does espswift while LLDB runs; LLDB handles it itself.
        system.ignoreInterrupts(true)
        defer { system.ignoreInterrupts(false) }
        system.report("Starting OpenOCD for the \(chip)...")
        let log = "\(work)/openocd.log"
        let process = try system.startInBackground(openocd, ["-f", config], environment: environment, output: log)
        defer { system.terminate(process) }
        try waitForOpenOCD(process: process, log: log)

        try system.writeFile("\(work)/espswift_connect.py", Self.connectHelper)
        _ = system.runVisibly(lldb, [
            "-o", "settings set target.require-hardware-breakpoint true",
            "-o", "target create \"\(elf)\"",
            "-o", "command script import \"\(work)/espswift_connect.py\"",
            "-o", "espswift-connect",
        ], environment: system.environment)
    }

    /// The firmware's ELF file, from ESP-IDF's project_description.json.
    func firmware(of build: LastBuild) throws -> String {
        guard let data = system.readData("\(build.buildFolder)/project_description.json"),
              let description = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let elf = description["app_elf"] as? String,
              system.fileExists("\(build.buildFolder)/\(elf)") else {
            throw EspSwiftError("The firmware of the last build wasn't found in \(build.buildFolder). Build the project again.")
        }
        return "\(build.buildFolder)/\(elf)"
    }

    /// The LLDB of the Swift toolchain the build uses, for Swift; else the
    /// system's (Xcode's works too).
    func findLLDB() throws -> String {
        if let toolchain = system.readFile(locations.swiftToolchainRecord)?.split(separator: "\n").first {
            let lldb = Setup.path(String(toolchain), "usr/bin/lldb")
            if system.fileExists(lldb) { return lldb }
        }
        if system.operatingSystem == .macOS,
           let xcrun = system.run("/usr/bin/xcrun", ["--find", "lldb"])?.output.trimmingCharacters(in: .whitespacesAndNewlines),
           system.fileExists(xcrun) {
            return xcrun
        }
        guard let lldb = system.findExecutable("lldb") else {
            throw EspSwiftError("LLDB wasn't found. It comes with the Swift toolchain; run: espswift setup")
        }
        return lldb
    }

    /// Waits until OpenOCD listens for LLDB (it prints "Listening on port 3333").
    func waitForOpenOCD(process: Int32, log: String) throws {
        for _ in 0..<30 {
            if system.readFile(log)?.contains("Listening on port 3333") == true { return }
            guard system.isRunning(process) else {
                let errors = (system.readFile(log) ?? "").split(separator: "\n").filter { $0.hasPrefix("Error") }.prefix(5)
                throw EspSwiftError("""
                    OpenOCD couldn't connect to the board. Is it connected through its native USB port (labelled USB, not UART)?
                    \(errors.joined(separator: "\n"))
                    """)
            }
            system.sleep(seconds: 0.5)
        }
        throw EspSwiftError("OpenOCD didn't start:\n\((system.readFile(log) ?? "").split(separator: "\n").suffix(5).joined(separator: "\n"))")
    }

    /// An LLDB command that connects to OpenOCD, lets the firmware start up
    /// after the reset that connecting causes (breakpoints set before it would
    /// be lost), and pauses it.
    static let connectHelper = """
        import lldb, time

        def _wait_until_stopped(listener, process, seconds):
            event = lldb.SBEvent()
            end = time.time() + seconds
            while time.time() < end and process.GetState() != lldb.eStateStopped:
                listener.WaitForEvent(1, event)
            return process.GetState() == lldb.eStateStopped

        def espswift_connect(debugger, command, result, internal_dict):
            target = debugger.GetSelectedTarget()
            listener = debugger.GetListener()
            debugger.SetAsync(True)
            error = lldb.SBError()
            process = target.ConnectRemote(listener, "connect://localhost:3333", "gdb-remote", error)
            if not error.Success():
                result.SetError(f"Couldn't connect to OpenOCD: {error}")
                debugger.SetAsync(False)
                return
            _wait_until_stopped(listener, process, 10)
            print("Letting the firmware start up...")
            process.Continue()
            time.sleep(4)
            process.Stop()
            _wait_until_stopped(listener, process, 10)
            debugger.SetAsync(False)
            print()
            print("The firmware is paused. Set breakpoints, then continue. For example:")
            print("  b Firmware.swift:49  breakpoint on line 49 of Firmware.swift")
            print("  c                    continue")
            print("  bt                   backtrace;  v  variables;  n  next line;  s  step in")
            print("  process interrupt    pause (or Ctrl+C);  quit  stop debugging")

        def __lldb_init_module(debugger, internal_dict):
            debugger.HandleCommand("command script add -f espswift_connect.espswift_connect espswift-connect")

        """
}
