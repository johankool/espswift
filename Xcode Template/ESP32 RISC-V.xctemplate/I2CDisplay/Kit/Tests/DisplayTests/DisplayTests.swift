// Tests for the Display target, run on the Mac: press Cmd+U in Xcode, or run
// `swift test` in the package folder.

import Display
import Testing

@Test func storesPixelsInPages() {
    var framebuffer = Framebuffer(width: 128, height: 64)
    #expect(framebuffer.bytes.count == 1024)
    framebuffer.setPixel(x: 3, y: 0)
    framebuffer.setPixel(x: 3, y: 9)
    #expect(framebuffer.bytes[3] == 0b0000_0001)        // Page 0, column 3, top row.
    #expect(framebuffer.bytes[128 + 3] == 0b0000_0010)  // Page 1, column 3, its second row.
    #expect(framebuffer.pixel(x: 3, y: 9))
    framebuffer.setPixel(x: 3, y: 9, on: false)
    #expect(!framebuffer.pixel(x: 3, y: 9))
    #expect(framebuffer.page(0).count == 128)
}

@Test func leavesOutPixelsOutsideTheDisplay() {
    var framebuffer = Framebuffer(width: 128, height: 32)
    framebuffer.setPixel(x: 128, y: 0)
    framebuffer.setPixel(x: -1, y: 5)
    framebuffer.setPixel(x: 0, y: 32)
    #expect(framebuffer.bytes.allSatisfy { $0 == 0 })
    #expect(!framebuffer.pixel(x: 200, y: 200))
}

@Test func drawsText() {
    var framebuffer = Framebuffer()
    let end = framebuffer.text("A", x: 0, y: 0)
    #expect(end == 6)
    // "A" is the font's columns, in page 0.
    #expect(Array(framebuffer.bytes[0..<6]) == [0x7E, 0x11, 0x11, 0x11, 0x7E, 0x00])
    #expect(Framebuffer.width(of: "Hi") == 11)
    #expect(Framebuffer.width(of: "Hi", scale: 2) == 22)
    #expect(Framebuffer.width(of: "") == 0)
}

@Test func scalesText() {
    var framebuffer = Framebuffer()
    framebuffer.text(".", x: 0, y: 0, scale: 2)
    // "." is two columns of two pixels (rows 5 and 6): twice as big, 4 × 4.
    #expect(framebuffer.pixel(x: 2, y: 10) && framebuffer.pixel(x: 5, y: 13))
    #expect(!framebuffer.pixel(x: 1, y: 10) && !framebuffer.pixel(x: 2, y: 9))
}

@Test func drawsUnknownCharactersAsQuestionMarks() {
    #expect(Font.glyph(for: UInt8(ascii: "?")) == Font.glyph(for: 0xC3))
    #expect(Font.glyph(for: UInt8(ascii: "~")).count == 5)
}

@Test func drawsRectangles() {
    var framebuffer = Framebuffer()
    framebuffer.rectangle(x: 0, y: 0, width: 3, height: 3, filled: false)
    #expect(framebuffer.pixel(x: 2, y: 2) && framebuffer.pixel(x: 0, y: 1))
    #expect(!framebuffer.pixel(x: 1, y: 1))
    framebuffer.clear()
    #expect(framebuffer.bytes.allSatisfy { $0 == 0 })
}
