@testable import EspSwiftCore
import Foundation
import Testing

@Suite struct PanicDecoderTests {
    /// A crash on an ESP32-C6, as the board prints it (shortened).
    static let crash = """
        Crash test\r
        Guru Meditation Error: Core  0 panic'ed (Illegal instruction). Exception was unhandled.\r
        Core  0 register dump:\r
        MEPC    : 0x4200012e  RA      : 0x4200013c  SP      : 0x4080f9f0  GP      : 0x40809fb4  \r
        \r
        Stack memory:\r
        4080f9f0: 0x4202018b 0x00000000 0x42022000 0x420001b8 0x00000000 0x00000000 0x4080ce14 0x4200c6ca\r
        4080fa10: 0x00000000 0x75736552 0x203a746c 0x0000e800 0x00000000 0x00000000 0x42022000 0x4200c6ce\r
        \r
        \r
        ELF file SHA256: a29f030c5\r
        Rebooting...\r

        """

    /// GDB's backtrace of the crash.
    static let gdbOutput = """
        During symbol reading: Could not find DWO CU /p/.build/ModuleCache/SwiftShims.pcm
        0x4200012e in Swift runtime failure: Index out of range () at /p/Firmware/Firmware.swift:6
        6\t}
        #0  0x4200012e in Swift runtime failure: Index out of range () at /p/Firmware/Firmware.swift:6
        #1  0x4200012e in $eSayxSicigSi_Tg5 ()
        #2  $e8Firmware7element_2atSiSaySiG_SitF (values=..., index=...) at /p/Firmware/Firmware.swift:5
        #3  0x4200c6ce in main_task (args=<error reading variable: value has been optimized out>) at /Users/test/.espressif/v6.1/esp-idf/components/freertos/app_startup.c:206

        """

    @Test func findsTheDumpAndHidesItsStack() {
        var watcher = PanicDumpWatcher(hidesStack: true)
        // In pieces, as the serial port delivers it.
        let data = Data(Self.crash.utf8)
        var events: [PanicDumpWatcher.Event] = []
        var start = 0
        for size in [7, 100, 3, 250, 1000] where start < data.count {
            let end = min(start + size, data.count)
            events += watcher.process(data[start..<end])
            start = end
        }
        let shown = events.compactMap { event -> String? in
            if case .output(let data) = event { return String(decoding: data, as: UTF8.self) }
            return nil
        }.joined()
        #expect(!shown.contains("4080f9f0:") && !shown.contains("Stack memory"))
        #expect(shown.hasPrefix("Crash test\r\nGuru Meditation Error"))
        #expect(shown.hasSuffix("ELF file SHA256: a29f030c5\r\nRebooting...\r\n"))

        // The dump comes right after its last line, before "Rebooting...".
        let dumps = events.compactMap { event -> String? in
            if case .dump(let dump) = event { return dump }
            return nil
        }
        #expect(dumps.count == 1)
        #expect(dumps.first?.hasPrefix("Core  0 register dump:") == true)
        #expect(dumps.first?.contains("4080fa10: 0x00000000") == true)
        if case .output(let last) = events.last {
            #expect(String(decoding: last, as: UTF8.self).hasPrefix("Rebooting"))
        }
    }

    @Test func showsEverythingWithoutADecoder() {
        var watcher = PanicDumpWatcher(hidesStack: false)
        let events = watcher.process(Data(Self.crash.utf8))
        let shown = events.compactMap { event -> Data? in
            if case .output(let data) = event { return data }
            return nil
        }.reduce(Data(), +)
        #expect(String(decoding: shown, as: UTF8.self) == Self.crash)
    }

    @Test func showsTheStartOfALineAtOnce() {
        var watcher = PanicDumpWatcher(hidesStack: true)
        #expect(watcher.process(Data("Type a key: ".utf8)) == [.output(Data("Type a key: ".utf8))])
        #expect(watcher.process(Data("x\n".utf8)) == [.output(Data("x\n".utf8))])
    }

    @Test func readsGDBsFrames() {
        #expect(PanicDecoder.frames(inGDBOutput: Self.gdbOutput) == [
            .init(name: "Swift runtime failure: Index out of range", file: "/p/Firmware/Firmware.swift", line: 6),
            .init(name: "$eSayxSicigSi_Tg5", file: nil, line: nil),
            .init(name: "$e8Firmware7element_2atSiSaySiG_SitF", file: "/p/Firmware/Firmware.swift", line: 5),
            .init(name: "main_task", file: "/Users/test/.espressif/v6.1/esp-idf/components/freertos/app_startup.c", line: 206),
        ])
    }

    static func decoder(_ system: FakeSystem) -> PanicDecoder {
        system.commands["/idf/gdb"] = CommandResult(status: 0, output: gdbOutput)
        system.commands["/swift/swift-demangle"] = CommandResult(
            status: 0, output: "element(_:at:)\nspecialized Array.subscript.getter\n")
        return PanicDecoder(system: system, elf: "/p/Blink/build/Blink.elf", projectFolder: "/p", gdb: "/idf/gdb",
                            python: "/idf/python", demangler: "/swift/swift-demangle")
    }

    @Test func decodesTheBacktrace() {
        let system = FakeSystem()
        #expect(Self.decoder(system).decode("Core  0 register dump:\n") == [
            "",
            "Backtrace (decoded by espswift):",
            "  #0 Swift runtime failure: Index out of range at Firmware/Firmware.swift:6",
            "  #1 specialized Array.subscript.getter",
            "  #2 element(_:at:) at Firmware/Firmware.swift:5",
            "  #3 main_task at ~/.espressif/v6.1/esp-idf/components/freertos/app_startup.c:206",
            "",
        ])
        // The dump goes to GDB in a file, which is removed afterwards.
        #expect(system.actions.contains { $0.hasPrefix("write /tmp/espswift-panic-") })
        #expect(!system.files.keys.contains { $0.contains("espswift-panic-") })
    }

    @Test func monitorDecodesEachCrashOnce() throws {
        let system = FakeSystem()
        system.file("/dev/cu.usbmodem1", "")
        // The same crash after a reset, then another.
        let other = Self.crash.replacingOccurrences(of: "0x4200012e", with: "0x42000200")
        system.serialConnections["/dev/cu.usbmodem1"] = [[Data(Self.crash.utf8), Data(Self.crash.utf8), Data(other.utf8)]]
        try Monitor(system: system, port: "/dev/cu.usbmodem1", decoder: Self.decoder(system)).run(reconnects: 0)
        #expect(system.reports.filter { $0 == "Backtrace (decoded by espswift):" }.count == 2)
        #expect(system.reports.contains("(The same crash as before; its backtrace is above.)"))
        #expect(!String(decoding: system.output, as: UTF8.self).contains("Stack memory"))
    }
}
