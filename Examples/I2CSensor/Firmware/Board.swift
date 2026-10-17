//
//  Board.swift
//  I2CSensor
//
//  Created by Johan Kool on 17-10-2026.
//

// The board chosen when the project was created. For another board, change
// its LED here (see BoardLED in LED.swift), and its chip and flash size in
// I2CSensor/sdkconfig.defaults.

enum Board {
    static let name = "ESP32-C6-DevKitC-1"
    static let led: BoardLED = .addressable(pin: 8)
    /// The pins (GPIO numbers) the sensor's SDA and SCL are wired to. Most
    /// pins can be used; on an M5Stack NanoC6's Grove port, SDA is 2 and
    /// SCL is 1.
    static let i2cSDA: Int32 = 22
    static let i2cSCL: Int32 = 23
}
