// Button presses from a button's readings, in plain Swift: it doesn't use
// ESP-IDF, so it can be tested on the Mac (see Tests/ButtonTests: Cmd+U).

/// What a button did.
public enum ButtonEvent {
    case pressed
    /// Released, after being held for a number of readings.
    case released(heldFor: Int)
    /// Still held after the long press time; reported once per press.
    case longPressed
}

/// Turns readings of a button, taken at a fixed interval, into presses and
/// releases. A button's contacts bounce: for a few milliseconds after it's
/// pressed or released, it reads as pressed and released in turn. So a
/// change only counts once the button has read the same for a few readings.
public struct ButtonDebouncer {
    /// The readings a change must last to count.
    public let stableReadings: Int
    /// The readings after which a press is a long press.
    public let longPressReadings: Int
    /// Whether the button is pressed, after debouncing.
    public private(set) var isPressed = false

    /// The readings in a row that differed from isPressed.
    private var changedReadings = 0
    /// The readings since the button was pressed.
    private var heldReadings = 0

    /// - Parameters:
    ///   - stableReadings: The readings a change must last to count: with a
    ///     reading every 10 ms, 3 is 30 ms.
    ///   - longPressReadings: The readings after which a press is a long
    ///     press: with a reading every 10 ms, 100 is 1 second.
    public init(stableReadings: Int = 3, longPressReadings: Int = 100) {
        self.stableReadings = stableReadings
        self.longPressReadings = longPressReadings
    }

    /// Takes the next reading; returns what the button did, if anything.
    public mutating func update(isDown: Bool) -> ButtonEvent? {
        if isPressed { heldReadings += 1 }
        guard isDown != isPressed else {
            changedReadings = 0
            return isPressed && heldReadings == longPressReadings ? .longPressed : nil
        }
        changedReadings += 1
        guard changedReadings >= stableReadings else { return nil }
        changedReadings = 0
        isPressed = isDown
        if isPressed {
            heldReadings = 0
            return .pressed
        } else {
            return .released(heldFor: heldReadings)
        }
    }
}
