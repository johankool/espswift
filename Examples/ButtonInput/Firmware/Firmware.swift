//
//  Firmware.swift
//  ButtonInput
//
//  Created by Johan Kool on 17-10-2026.
//

// Embedded Swift entry point.
// This example reads the board's BOOT button: each press shows the next
// colour on the LED (red, green, blue, off), and a long press turns it off.
// It reads the button every 10 ms, and ButtonDebouncer (in the Kit's Button
// module, tested on the Mac) turns those readings into presses.

import Blink
import Button
import ESPIDF

@_cdecl("app_main")
public func app_main() {
    print("Press the BOOT button to change the LED's colour; hold it to turn the LED off.")

    let led = LED(Board.led)
    if led == nil {
        print("\(Board.name) has no LED; printing the colours instead.")
    }

    // The button's pin as an input. Its internal pull-up resistor keeps
    // the pin high until the pressed button connects it to ground.
    var config = gpio_config_t()
    config.pin_bit_mask = 1 << UInt64(Board.button)
    config.mode = GPIO_MODE_INPUT
    config.pull_up_en = GPIO_PULLUP_ENABLE
    guard gpio_config(&config) == ESP_OK else {
        print("Couldn't set up GPIO \(Board.button) for the button.")
        return
    }

    var debouncer = ButtonDebouncer(stableReadings: 3, longPressReadings: 100)
    var colorIndex: UInt32 = 0
    var presses = 0

    while true {
        // Low when pressed.
        let isDown = gpio_get_level(gpio_num_t(Board.button)) == 0

        switch debouncer.update(isDown: isDown) {
        case .pressed:
            presses += 1
            let step = blinkStep(colorIndex)
            led?.show(red: step.red, green: step.green, blue: step.blue)
            print("Press \(presses): \(step.name)")
            colorIndex += 1
        case .released(let heldFor):
            print("Released after \(heldFor * 10) ms")
        case .longPressed:
            led?.show(red: 0, green: 0, blue: 0)
            print("Long press: off")
            colorIndex = 0
        case nil:
            break
        }

        // Read the button again in 10 ms (one FreeRTOS tick).
        vTaskDelay(ticks(milliseconds: 10))
    }
}
