// Tests for the Light target, run on the Mac: press Cmd+U in Xcode, or run
// `swift test` in the package folder.

import Light
import Testing

@Test func readsAColorFromThreeBytes() throws {
    let color = try #require(Color(bytes: [255, 128, 0]))
    #expect([color.red, color.green, color.blue] == [255, 128, 0])
    #expect(color.bytes == [255, 128, 0])
    #expect(color.hex == "#FF8000")
}

@Test func rejectsOtherLengths() {
    #expect(Color(bytes: [255, 128]) == nil)
    #expect(Color(bytes: [1, 2, 3, 4]) == nil)
}

@Test func readsAUUIDLittleEndian() throws {
    let bytes = try #require(uuidBytes("EF173EFA-F017-40BA-88E4-D14B7E316946"))
    #expect(bytes.count == 16)
    #expect(bytes.first == 0x46)
    #expect(bytes.last == 0xEF)
    #expect(uuidBytes("ef173efa-f017-40ba-88e4-d14b7e316946") == bytes)
}

@Test func rejectsTextThatIsNotAUUID() {
    #expect(uuidBytes("EF173EFA") == nil)
    #expect(uuidBytes("EF173EFA-F017-40BA-88E4-D14B7E31694G") == nil)
}
