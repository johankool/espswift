// The light's data, in plain Swift: it doesn't use ESP-IDF, so it can be
// tested on the Mac (see Tests/LightTests: Cmd+U).

/// A colour, as the light's characteristic reads and writes it: three
/// bytes, red, green and blue, each 0–255.
public struct Color {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// The colour in a characteristic's value; nil unless it's 3 bytes.
    public init?(bytes: some Collection<UInt8>) {
        guard bytes.count == 3 else { return nil }
        let bytes = Array(bytes)
        self.init(red: bytes[0], green: bytes[1], blue: bytes[2])
    }

    /// The colour as a characteristic's value.
    public var bytes: [UInt8] { [red, green, blue] }

    /// The colour as text, such as "#FF8000".
    public var hex: String {
        let digits = Array("0123456789ABCDEF".utf8)
        var text: [UInt8] = [UInt8(ascii: "#")]
        for byte in bytes {
            text += [digits[Int(byte >> 4)], digits[Int(byte & 0xF)]]
        }
        return String(decoding: text, as: UTF8.self)
    }
}

/// The 16 bytes of a 128-bit UUID written as text, such as
/// "EF173EFA-F017-40BA-88E4-D14B7E316946", in the order Bluetooth sends
/// them: little-endian, so the last byte of the text comes first. Nil if
/// the text isn't a UUID.
public func uuidBytes(_ text: String) -> [UInt8]? {
    var bytes: [UInt8] = []
    var high: UInt8?
    for character in text.utf8 where character != UInt8(ascii: "-") {
        let value: UInt8
        switch character {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): value = character - UInt8(ascii: "0")
        case UInt8(ascii: "A")...UInt8(ascii: "F"): value = character - UInt8(ascii: "A") + 10
        case UInt8(ascii: "a")...UInt8(ascii: "f"): value = character - UInt8(ascii: "a") + 10
        default: return nil
        }
        if let first = high {
            bytes.append(first << 4 | value)
            high = nil
        } else {
            high = value
        }
    }
    guard bytes.count == 16, high == nil else { return nil }
    return bytes.reversed()
}
