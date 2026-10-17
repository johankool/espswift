// The blink pattern, in plain Swift: it doesn't use ESP-IDF, so it can be
// tested on the Mac (see Tests/BlinkTests: Cmd+U).

/// One step of the blink pattern: a color for the LED and its name.
public struct BlinkStep {
    public let red: UInt32
    public let green: UInt32
    public let blue: UInt32
    public let name: StaticString
}

/// Cycles through red, green, blue and off.
/// - Parameters:
///   - index: The step number; the pattern repeats every 4 steps.
///   - brightness: The color's brightness, 0–255. Low by default, as the
///     LED is very bright.
public func blinkStep(_ index: UInt32, brightness: UInt32 = 32) -> BlinkStep {
    switch index % 4 {
    case 0: BlinkStep(red: brightness, green: 0, blue: 0, name: "Red")
    case 1: BlinkStep(red: 0, green: brightness, blue: 0, name: "Green")
    case 2: BlinkStep(red: 0, green: 0, blue: brightness, name: "Blue")
    default: BlinkStep(red: 0, green: 0, blue: 0, name: "Off")
    }
}
