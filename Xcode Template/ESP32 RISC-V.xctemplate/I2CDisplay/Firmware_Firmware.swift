//
//  Firmware.swift
//  ___PROJECTNAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//

// Embedded Swift entry point.
// This example shows text on an SSD1306 display (such as Adafruit's
// 128 × 64 OLED displays) over I2C: a title, the board's name, how long it
// has been running, and a bar that fills up every minute. Wire the
// display's SDA and SCL to the pins below, VIN (or VCC) to 3V3 and GND to
// GND; on a display with a RST pin and no reset circuit, connect RST to
// 3V3 as well. The Kit's Display module draws the text (tested on the Mac),
// and SSD1306.swift sends it to the display.

import Display
import ESPIDF

/// The pins (GPIO numbers) the display's SDA and SCL are wired to. Most
/// pins can be used; these are free on ___VARIABLE_boardName___.
let sdaPin: Int32 = ___VARIABLE_boardI2CSDA___
let sclPin: Int32 = ___VARIABLE_boardI2CSCL___

/// How long an I2C transfer may take, in milliseconds.
let timeout: Int32 = 100

@_cdecl("app_main")
public func app_main() {
    // The LED isn't used: turn it off.
    _ = LED(Board.led)

    // The I2C bus, on the SDA and SCL pins. The internal pull-up resistors
    // are enough for a short wire; most displays have their own as well.
    var busConfig = i2c_master_bus_config_t()
    busConfig.i2c_port = -1  // Any free I2C controller.
    busConfig.sda_io_num = gpio_num_t(sdaPin)
    busConfig.scl_io_num = gpio_num_t(sclPin)
    busConfig.clk_source = I2C_CLK_SRC_DEFAULT
    busConfig.glitch_ignore_cnt = 7
    busConfig.flags.enable_internal_pullup = 1
    var bus: i2c_master_bus_handle_t?
    guard i2c_new_master_bus(&busConfig, &bus) == ESP_OK, let bus else {
        print("Couldn't set up the I2C bus on SDA GPIO \(sdaPin) and SCL GPIO \(sclPin).")
        return
    }

    // Wait for the display to answer.
    var found = SSD1306(bus: bus)
    while found == nil {
        print("No SSD1306 display answers at address 0x3C or 0x3D, on SDA GPIO \(sdaPin) and SCL GPIO \(sclPin); check the wiring. Trying again in 5 seconds.")
        vTaskDelay(ticks(milliseconds: 5000))
        found = SSD1306(bus: bus)
    }
    guard let display = found else { return }
    print("Found an SSD1306 display at address 0x\(display.address == 0x3C ? "3C" : "3D").")

    var framebuffer = Framebuffer(width: display.width, height: display.height)
    var seconds = 0
    while true {
        framebuffer.clear()
        // The title, twice as big, in the middle.
        let title = "ESPSwift"
        framebuffer.text(title, x: (display.width - Framebuffer.width(of: title, scale: 2)) / 2, y: 0, scale: 2)
        // The board's name; what doesn't fit is left out.
        framebuffer.text(Board.name, x: 0, y: 20)
        framebuffer.text("Running \(seconds / 60) min \(seconds % 60) s", x: 0, y: 32)
        // A bar that fills up every minute.
        framebuffer.rectangle(x: 0, y: display.height - 10, width: display.width, height: 10, filled: false)
        framebuffer.rectangle(x: 2, y: display.height - 8, width: (display.width - 4) * (seconds % 60 + 1) / 60, height: 6)

        if !display.show(framebuffer) {
            print("Sending to the display failed.")
        }
        vTaskDelay(ticks(milliseconds: 1000))
        seconds += 1
    }
}
