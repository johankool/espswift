//
//  Firmware.swift
//  Hello
//
//  Created by you.
//

// Embedded Swift entry point.
// This example blinks the board's LED: red, green, blue and off. Board.swift
// says which LED the board has, and LED.swift drives it: an addressable RGB
// LED (WS2812), separate red, green and blue LEDs, or a one-colour LED (on for
// any colour). Without an LED, it only prints the colours.

import Blink
import ESPIDF

@_cdecl("app_main")
public func app_main() {
    print("Hello from my first firmware!")

    let led = LED(Board.led)
    if led == nil {
        print("\(Board.name) has no LED to blink; printing the colours instead.")
    }

    // ── Animation Loop ───────────────────────────────────────
    // Cycle through Red, Green, Blue, and Off — one color per second.

    var colorIndex: UInt32 = 0

    while true {
        // The color for this step: red, green, blue or off (see Blink.swift).
        let step = blinkStep(colorIndex)

        led?.show(red: step.red, green: step.green, blue: step.blue)
        print("LED: \(step.name)")

        // Wait 1 second using FreeRTOS task delay.
        vTaskDelay(ticks(milliseconds: 1000))

        colorIndex += 1
    }
}
