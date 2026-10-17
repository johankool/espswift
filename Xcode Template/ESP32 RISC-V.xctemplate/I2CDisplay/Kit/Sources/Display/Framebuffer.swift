// What a monochrome display such as the SSD1306 shows, in plain Swift: it
// doesn't use ESP-IDF, so it can be tested on the Mac (see
// Tests/DisplayTests: Cmd+U). The firmware sends its bytes to the display.

/// The pixels of a monochrome display, in the SSD1306's layout: the rows
/// are in pages of 8, and each byte is a column of 8 pixels in a page, its
/// lowest bit at the top. The bytes go page by page, left to right.
public struct Framebuffer {
    public let width: Int
    public let height: Int
    /// The pixels: width × height / 8 bytes, as the display takes them.
    public private(set) var bytes: [UInt8]

    /// A framebuffer with every pixel off; height is a multiple of 8.
    public init(width: Int = 128, height: Int = 64) {
        self.width = width
        self.height = height
        bytes = [UInt8](repeating: 0, count: width * height / 8)
    }

    /// The bytes of one page: the rows 8 × page to 8 × page + 7.
    public func page(_ page: Int) -> ArraySlice<UInt8> {
        bytes[page * width..<(page + 1) * width]
    }

    /// Turns every pixel off.
    public mutating func clear() {
        for index in bytes.indices { bytes[index] = 0 }
    }

    /// Whether a pixel is on; false outside the display.
    public func pixel(x: Int, y: Int) -> Bool {
        guard (0..<width).contains(x), (0..<height).contains(y) else { return false }
        return bytes[y / 8 * width + x] & (1 << UInt8(y % 8)) != 0
    }

    /// Turns a pixel on or off; a pixel outside the display is left out.
    public mutating func setPixel(x: Int, y: Int, on: Bool = true) {
        guard (0..<width).contains(x), (0..<height).contains(y) else { return }
        let index = y / 8 * width + x
        let bit: UInt8 = 1 << UInt8(y % 8)
        bytes[index] = on ? bytes[index] | bit : bytes[index] & ~bit
    }

    /// Fills a rectangle, or (filled: false) draws its outline.
    public mutating func rectangle(x: Int, y: Int, width: Int, height: Int, filled: Bool = true) {
        for row in y..<y + height {
            for column in x..<x + width
            where filled || row == y || row == y + height - 1 || column == x || column == x + width - 1 {
                setPixel(x: column, y: row)
            }
        }
    }

    /// Draws text with the 5 × 7 font, its top left corner at x, y, each
    /// pixel scale × scale pixels big; returns the x after the text. Each
    /// character is 6 pixels wide (times scale), with the space after it.
    @discardableResult
    public mutating func text(_ text: String, x: Int, y: Int, scale: Int = 1) -> Int {
        var x = x
        for character in text.utf8 {
            let glyph = Font.glyph(for: character)
            for (column, bits) in glyph.enumerated() {
                for row in 0..<7 where bits & (1 << UInt8(row)) != 0 {
                    rectangle(x: x + column * scale, y: y + row * scale, width: scale, height: scale)
                }
            }
            x += Font.advance * scale
        }
        return x
    }

    /// How wide text is with the 5 × 7 font, in pixels, without the space
    /// after its last character.
    public static func width(of text: String, scale: Int = 1) -> Int {
        max(text.utf8.count * Font.advance - 1, 0) * scale
    }
}
