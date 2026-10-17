//
//  Board.swift
//  ButtonInput
//
//  Created by Johan Kool on 17-10-2026.
//

// The board chosen when the project was created. For another board, change
// its LED here (see BoardLED in LED.swift), and its chip and flash size in
// ButtonInput/sdkconfig.defaults.

enum Board {
    static let name = "ESP32-C6-DevKitC-1"
    static let led: BoardLED = .addressable(pin: 8)
    /// The pin (GPIO number) of the board's BOOT button, which connects the
    /// pin to ground when pressed. Other boards: see their pinout, or wire
    /// a button from another pin to GND.
    static let button: Int32 = 9
}
