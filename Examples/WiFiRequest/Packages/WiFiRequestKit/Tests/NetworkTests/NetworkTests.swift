// Tests for the Network target, run on the Mac: press Cmd+U in Xcode, or run
// `swift test` in the package folder.

import Network
import Testing

@Test func formatsAnAddressInNetworkByteOrder() {
    // 192.168.1.20 as lwIP stores it on a little-endian chip.
    #expect(dottedDecimal(0x1401_A8C0) == "192.168.1.20")
    #expect(dottedDecimal(0) == "0.0.0.0")
}

@Test func readsACString() {
    let name: [UInt8] = Array("Home".utf8) + [0, 0x41, 0]
    #expect(string(cString: name) == "Home")
    #expect(string(cString: Array("Full".utf8)) == "Full")
    #expect(string(cString: [0, 0x41]) == "")
}
