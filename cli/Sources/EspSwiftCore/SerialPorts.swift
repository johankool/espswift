/// Finds the serial ports of connected boards.
///
/// ESP32 boards connect through the chip's own USB (USB-JTAG/serial, on the
/// ESP32-C3, C5, C6, C61, H2 and P4) or through a USB-to-serial chip on the
/// board (CP210x, CH34x, FTDI). Both show up as serial devices in /dev.
public enum SerialPorts {
    /// The device name prefixes of boards, in order of preference: the
    /// chip's own USB first.
    public static func prefixes(for operatingSystem: OperatingSystem) -> [String] {
        switch operatingSystem {
        case .macOS:
            ["cu.usbmodem", "cu.wchusbserial", "cu.SLAB_USBtoUART", "cu.usbserial"]
        case .linux:
            ["ttyACM", "ttyUSB"]
        }
    }

    /// The ports among the names of the entries in /dev, as paths.
    public static func ports(in deviceNames: [String], on operatingSystem: OperatingSystem) -> [String] {
        prefixes(for: operatingSystem).flatMap { prefix in
            deviceNames.filter { $0.hasPrefix(prefix) }.sorted()
        }.map { "/dev/\($0)" }
    }

    /// The ports of the boards connected now.
    public static func connected(system: System) -> [String] {
        ports(in: system.contentsOfDirectory("/dev"), on: system.operatingSystem)
    }

    /// The port to use: the one asked for (--port, or ESPSWIFT_PORT), else
    /// the first connected board's.
    public static func choose(_ requested: String?, system: System) throws -> String {
        if let port = requested ?? system.environment["ESPSWIFT_PORT"], !port.isEmpty {
            return port
        }
        guard let port = connected(system: system).first else {
            throw EspSwiftError("No board found. Connect one over USB (or name its port with --port).")
        }
        return port
    }
}
