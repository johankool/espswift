// Tests for the SHT4x target, run on the Mac: press Cmd+U in Xcode, or run
// `swift test` in the package folder.

import SHT4x
import Testing

@Test func computesTheDatasheetsChecksum() {
    // The example in the SHT4x datasheet: CRC(0xBEEF) = 0x92.
    #expect(SHT4x.crc([0xBE, 0xEF]) == 0x92)
}

@Test func readsAMeasurement() throws {
    // 0x6666 is 40 % of the range: -45 + 175 × 0.4 = 25 °C, and
    // -6 + 125 × 0.4 = 44 %.
    let word: [UInt8] = [0x66, 0x66]
    let response = word + [SHT4x.crc(word)] + word + [SHT4x.crc(word)]
    let measurement = try #require(Measurement(response: response))
    #expect(measurement.temperature == 2_500)
    #expect(measurement.humidity == 4_400)
}

@Test func rejectsAWrongChecksum() {
    #expect(Measurement(response: [0x66, 0x66, 0x00, 0x66, 0x66, 0x93]) == nil)
    #expect(Measurement(response: [0x66, 0x66]) == nil)
}

@Test func limitsTheHumidity() throws {
    let low: [UInt8] = [0x00, 0x00]
    let measurement = try #require(Measurement(response: low + [SHT4x.crc(low)] + low + [SHT4x.crc(low)]))
    #expect(measurement.temperature == -4_500)
    #expect(measurement.humidity == 0)
}

@Test(arguments: [(2345, "23.45"), (-5, "-0.05"), (-4500, "-45.00"), (0, "0.00"), (10000, "100.00")] as [(Int32, String)])
func formatsHundredths(value: Int32, text: String) {
    #expect(decimal(hundredths: value) == text)
}
