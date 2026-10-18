// A colour light's state, as Matter sets it, and the colour it shows, in
// plain Swift: it doesn't use ESP-IDF, so it can be tested on the Mac (see
// Tests/LightColorTests: Cmd+U).

/// A colour light: on or off, its brightness, and its colour, given either
/// as a hue and saturation or as a colour temperature, in Matter's units.
public struct LightState {
    /// Whether the light is on.
    public var isOn = true
    /// The brightness: Matter's level, 1–254.
    public var level = 64
    /// How the colour is given.
    public var mode = Mode.temperature
    /// The hue: 0–254 for 0–360°.
    public var hue = 0
    /// The saturation: 0–254 for 0–100 %.
    public var saturation = 254
    /// The colour temperature in mireds (a million divided by kelvins):
    /// 153 (6500 K, cool white) to 370 (2700 K, warm white).
    public var temperature = 250

    public enum Mode {
        case hueSaturation
        case temperature
    }

    public init() {}

    /// The colour to show, 0–255 for each of red, green and blue.
    public var rgb: (red: UInt32, green: UInt32, blue: UInt32) {
        guard isOn else { return (0, 0, 0) }
        let full: (red: Int, green: Int, blue: Int)
        switch mode {
        case .hueSaturation:
            full = Self.rgb(hue: hue * 360 / 255, saturation: saturation * 255 / 254)
        case .temperature:
            full = Self.rgb(mireds: temperature)
        }
        // Scale to the brightness.
        let brightness = max(0, min(level, 254))
        return (UInt32(full.red * brightness / 254), UInt32(full.green * brightness / 254),
                UInt32(full.blue * brightness / 254))
    }

    /// A fully bright colour of a hue (0–359°) and saturation (0–255).
    static func rgb(hue: Int, saturation: Int) -> (red: Int, green: Int, blue: Int) {
        let hue = ((hue % 360) + 360) % 360
        let saturation = max(0, min(saturation, 255))
        // The hue's position in its sixth of the colour wheel, 0–255.
        let sector = hue / 60
        let fraction = (hue % 60) * 255 / 60
        let low = 255 - saturation
        let falling = 255 - saturation * fraction / 255
        let rising = 255 - saturation * (255 - fraction) / 255
        switch sector {
        case 0: return (255, rising, low)
        case 1: return (falling, 255, low)
        case 2: return (low, 255, rising)
        case 3: return (low, falling, 255)
        case 4: return (rising, low, 255)
        default: return (255, low, falling)
        }
    }

    /// White of a colour temperature, roughly: from warm white at 2700 K
    /// (370 mireds) to cool white at 6500 K (153 mireds).
    static func rgb(mireds: Int) -> (red: Int, green: Int, blue: Int) {
        let kelvins = 1_000_000 / max(mireds, 1)
        let t = max(0, min(100, (kelvins - 2700) * 100 / (6500 - 2700)))
        return (255, 169 + (249 - 169) * t / 100, 87 + (253 - 87) * t / 100)
    }
}
