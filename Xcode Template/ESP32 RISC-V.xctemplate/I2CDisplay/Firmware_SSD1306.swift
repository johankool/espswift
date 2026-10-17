//
//  SSD1306.swift
//  ___PROJECTNAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//

// The SSD1306 display controller, over I2C, with ESP-IDF's I2C driver. The
// Kit's Display module draws what it shows.

import Display
import ESPIDF

/// An SSD1306 display, 128 pixels wide and 64 (or 32) high.
struct SSD1306 {
    /// The display's I2C addresses: 0x3C, or 0x3D with its address jumper
    /// set (as on Adafruit's 128 × 64 displays).
    static let addresses: [UInt16] = [0x3C, 0x3D]

    let width = 128
    let height: Int
    /// The address it answered at.
    let address: UInt16
    private let device: i2c_master_dev_handle_t

    /// Finds the display on the bus and turns it on; nil if none answers.
    init?(bus: i2c_master_bus_handle_t, height: Int = 64) {
        guard let address = Self.addresses.first(where: { i2c_master_probe(bus, $0, timeout) == ESP_OK }) else {
            return nil
        }
        var config = i2c_device_config_t()
        config.dev_addr_length = I2C_ADDR_BIT_LEN_7
        config.device_address = address
        config.scl_speed_hz = 400_000
        var device: i2c_master_dev_handle_t?
        guard i2c_master_bus_add_device(bus, &config, &device) == ESP_OK, let device else { return nil }
        self.address = address
        self.height = height
        self.device = device

        // The settings for a display with its own voltage (charge pump),
        // from the SSD1306's datasheet, as Adafruit's library sends them.
        let setUp: [UInt8] = [
            0xAE,                         // Display off
            0xD5, 0x80,                   // Clock: the default
            0xA8, UInt8(height - 1),      // Rows (multiplex ratio)
            0xD3, 0x00,                   // No vertical offset
            0x40,                         // Start at row 0
            0x8D, 0x14,                   // Charge pump on
            0x20, 0x00,                   // Horizontal addressing: page after page
            0xA1,                         // Columns and rows reversed: the panels
            0xC8,                         // are mounted upside down
            0xDA, height == 64 ? 0x12 : 0x02,  // How the rows are wired
            0x81, 0xCF,                   // Contrast
            0xD9, 0xF1,                   // Pre-charge period
            0xDB, 0x40,                   // VCOMH level
            0xA4,                         // Show the display's memory
            0xA6,                         // Not inverted
            0x2E,                         // No scrolling
            0xAF,                         // Display on
        ]
        guard send(commands: setUp) else { return nil }
    }

    /// Shows a framebuffer of the display's size; false if that failed.
    @discardableResult
    func show(_ framebuffer: Framebuffer) -> Bool {
        // Write all columns and pages, from the top left.
        guard send(commands: [0x21, 0, UInt8(width - 1), 0x22, 0, UInt8(height / 8 - 1)]) else { return false }
        for page in 0..<height / 8 {
            // 0x40: the bytes that follow are pixels.
            var data: [UInt8] = [0x40] + framebuffer.page(page)
            guard i2c_master_transmit(device, &data, data.count, timeout) == ESP_OK else { return false }
        }
        return true
    }

    /// Sends commands; false if that failed.
    private func send(commands: [UInt8]) -> Bool {
        // 0x00: the bytes that follow are commands.
        var data: [UInt8] = [0x00] + commands
        return i2c_master_transmit(device, &data, data.count, timeout) == ESP_OK
    }
}
