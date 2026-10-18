// Tests for the pairing code's format, run on the Mac: press Cmd+U in Xcode,
// or run `swift test` in the package folder.

import LightColor
import Testing

@Test func groupsThePairingCodesDigits() {
    #expect(formattedPairingCode("34970112332") == "3497-011-2332")
    #expect(formattedPairingCode("123") == "123")
}
