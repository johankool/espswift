//
//  Firmware.swift
//  ___PROJECTNAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//

// Embedded Swift entry point.
// This example sleeps: it shows a colour on the LED for a second, then puts
// the chip in deep sleep for 10 seconds, and starts again when it wakes up,
// with the next colour. In deep sleep the chip uses a few microamps instead
// of tens of milliamps, and only its RTC memory keeps its contents, so a
// count of the wake-ups survives there.

import Blink
import ESPIDF

/// How long the chip sleeps, in seconds.
let sleepSeconds: UInt64 = 10

/// The times the chip woke up from deep sleep, since it was powered on or
/// reset. It's in RTC memory, which stays powered in deep sleep, as C's
/// RTC_DATA_ATTR puts variables there; the rest of memory is lost. (The
/// ESP32-C2 and ESP32-C61 have no RTC memory, so there the count starts
/// again at every wake-up.)
#if CONFIG_SOC_RTC_MEM_SUPPORTED
@section(".rtc.data")
nonisolated(unsafe) var wakeCount: UInt32 = 0
#else
nonisolated(unsafe) var wakeCount: UInt32 = 0
#endif

/// Waits for the computer to reconnect to the chip's USB port, which goes
/// away in deep sleep, and for the serial monitor to open it again, so the
/// output isn't lost. Without a computer, e.g. on a battery, it waits 2.5
/// seconds for nothing; leave it out then.
func waitForUSB() {
    #if CONFIG_SOC_USB_SERIAL_JTAG_SUPPORTED
    for _ in 0..<200 where !usb_serial_jtag_is_connected() {
        vTaskDelay(ticks(milliseconds: 10))
    }
    vTaskDelay(ticks(milliseconds: 500))
    #endif
}

@_cdecl("app_main")
public func app_main() {
    // The LED first: it kept its colour while the chip slept.
    let led = LED(Board.led)
    waitForUSB()

    // What woke the chip: each kind of wake-up is a bit.
    let causes = esp_sleep_get_wakeup_causes()
    if causes & (1 << ESP_SLEEP_WAKEUP_TIMER.rawValue) != 0 {
        wakeCount += 1
        print("Woke up from deep sleep: wake-up \(wakeCount).")
    } else {
        // Powered on, reset or flashed: RTC memory starts from zero.
        wakeCount = 0
        print("Started; going to sleep for \(sleepSeconds) seconds at a time.")
    }

    // Show the colour for this wake-up for a second.
    let step = blinkStep(wakeCount)
    led?.show(red: step.red, green: step.green, blue: step.blue)
    print("LED: \(step.name). Sleeping for \(sleepSeconds) seconds in a second...")
    vTaskDelay(ticks(milliseconds: 1000))

    // The LED stays powered in deep sleep, so turn it off first.
    led?.show(red: 0, green: 0, blue: 0)

    // Sleep, until the timer wakes the chip. The chip then starts from
    // the beginning, as after a reset, and app_main runs again.
    esp_sleep_enable_timer_wakeup(sleepSeconds * 1_000_000)
    esp_deep_sleep_start()
}
