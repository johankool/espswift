//
//  Firmware.swift
//  ___PROJECTNAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//

// Embedded Swift entry point.
// This example blinks the board's LED: red, green, blue and off. The board
// chosen when the project was created sets which LED that is, in
// ESPIDF/include/ESPIDF.h: an addressable RGB LED (WS2812), separate red,
// green and blue LEDs, or a one-colour LED (on for any colour). Without an
// LED, it only prints the colours.

import Blink
import ESPIDF

@_cdecl("app_main")
public func app_main() {
    print("Hello from Embedded Swift on ESP32!")

    // ── LED Configuration ────────────────────────────────────
    // board_led_new() in ESPIDF.h sets up the board's LED: for
    // an addressable one, the led_strip driver, with the
    // peripheral that generates the precise timing pulses WS2812
    // LEDs need (RMT, or SPI on chips without RMT); otherwise
    // plain GPIO pins.

    var led = board_led_t()
    let hasLED = board_led_new(&led) == ESP_OK

    if hasLED {
        print("Blinking the LED on GPIO \(BOARD_LED_PIN).")
    } else {
        print("This board has no LED to blink; printing the colours instead.")
    }

    // ── Animation Loop ───────────────────────────────────────
    // Cycle through Red, Green, Blue, and Off — one color per second.

    var colorIndex: UInt32 = 0

    while true {
        // The color for this step: red, green, blue or off (see Blink.swift).
        let step = blinkStep(colorIndex)

        if hasLED {
            board_led_set(&led, step.red, step.green, step.blue)
        }

        print("LED: \(step.name)")

        // Wait 1 second using FreeRTOS task delay.
        vTaskDelay(pd_ms_to_ticks(1000))

        colorIndex += 1
    }
}
