//
//  Board.swift
//  BLELight
//
//  Created by Johan Kool on 17-10-2026.
//

// The board chosen when the project was created. For another board, change
// its LED here (see BoardLED in LED.swift), and its chip and flash size in
// BLELight/sdkconfig.defaults.

enum Board {
    static let name = "ESP32-C6-DevKitC-1"
    static let led: BoardLED = .addressable(pin: 8)
}
