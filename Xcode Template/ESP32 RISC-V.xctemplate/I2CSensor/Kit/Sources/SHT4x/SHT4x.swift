// The Sensirion SHT4x temperature and humidity sensor's data, in plain
// Swift: it doesn't use ESP-IDF, so it can be tested on the Mac (see
// Tests/SHT4xTests: Cmd+U). The firmware does the I2C communication.
//
// Embedded Swift can't print Float or Double, so values are integers in
// hundredths, such as 2345 for 23.45 °C.

/// The SHT4x's I2C address and commands (from its datasheet).
public enum SHT4x {
    /// The I2C address of the SHT40-AD1B, the most common variant (others
    /// are at 0x45 or 0x46).
    public static let address: UInt16 = 0x44
    /// Measures temperature and humidity with high precision; the result
    /// is ready after 8.3 ms.
    public static let measureHighPrecision: UInt8 = 0xFD
    /// Reads the sensor's serial number.
    public static let readSerialNumber: UInt8 = 0x89

    /// The checksum that follows every two bytes the sensor sends: CRC-8
    /// with polynomial 0x31 and initial value 0xFF.
    public static func crc(_ bytes: some Sequence<UInt8>) -> UInt8 {
        var crc: UInt8 = 0xFF
        for byte in bytes {
            crc ^= byte
            for _ in 0..<8 {
                crc = crc & 0x80 != 0 ? (crc << 1) ^ 0x31 : crc << 1
            }
        }
        return crc
    }

    /// The 16-bit words in a response: each is two bytes and their
    /// checksum. Nil if a checksum is wrong or the length isn't a multiple
    /// of 3.
    public static func words(in response: [UInt8]) -> [UInt16]? {
        guard response.count % 3 == 0 else { return nil }
        var words: [UInt16] = []
        for start in stride(from: 0, to: response.count, by: 3) {
            let pair = response[start..<start + 2]
            guard crc(pair) == response[start + 2] else { return nil }
            words.append(UInt16(pair.first!) << 8 | UInt16(pair.last!))
        }
        return words
    }
}

/// A measurement of the SHT4x.
public struct Measurement {
    /// The temperature, in hundredths of a degree Celsius.
    public let temperature: Int32
    /// The relative humidity, in hundredths of a percent.
    public let humidity: Int32

    /// The measurement in a response to measureHighPrecision: the
    /// temperature and humidity words. Nil if a checksum is wrong.
    public init?(response: [UInt8]) {
        guard let words = SHT4x.words(in: response), words.count == 2 else { return nil }
        // The datasheet's formulas: T = -45 + 175 × S / 65535 °C, and
        // RH = -6 + 125 × S / 65535 %, limited to 0–100 %.
        temperature = Int32(-4_500 + 17_500 * Int64(words[0]) / 65_535)
        humidity = Int32(min(max(-600 + 12_500 * Int64(words[1]) / 65_535, 0), 10_000))
    }
}

/// A number of hundredths as a decimal number: 2345 as "23.45", -5 as
/// "-0.05".
public func decimal(hundredths: Int32) -> String {
    let sign = hundredths < 0 ? "-" : ""
    let magnitude = hundredths.magnitude
    let fraction = magnitude % 100
    return "\(sign)\(magnitude / 100).\(fraction < 10 ? "0" : "")\(fraction)"
}
