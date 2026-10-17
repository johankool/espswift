//
//  Firmware.swift
//  ___PROJECTNAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//

// Embedded Swift entry point.
// This example is a Bluetooth LE light: a phone can connect to it and set
// the LED's colour. Use an app such as nRF Connect or LightBlue: connect to
// "ESPSwift Light", and write three bytes to the characteristic of its
// service (see Bluetooth.swift), such as 20 00 00 for red. Bluetooth.swift
// sets up Bluetooth; the Kit's Light module reads the colours.

import ESPIDF
import Light

@_cdecl("app_main")
public func app_main() {
    // The LED, kept for the closure below, which changes it.
    let led = LED(Board.led)
    if led == nil {
        print("\(Board.name) has no LED; printing the colours instead.")
    }

    #if CONFIG_BT_NIMBLE_ENABLED
    let started = startBluetooth(name: "ESPSwift Light") { color in
        led?.show(red: UInt32(color.red), green: UInt32(color.green), blue: UInt32(color.blue))
        print("Colour: \(color.hex)")
    }
    if !started {
        print("Starting Bluetooth failed.")
    }
    // NimBLE's task keeps running after app_main returns.
    #else
    print("\(Board.name) has no Bluetooth; this example needs a chip with Bluetooth LE, such as the ESP32-C6.")
    #endif
}
