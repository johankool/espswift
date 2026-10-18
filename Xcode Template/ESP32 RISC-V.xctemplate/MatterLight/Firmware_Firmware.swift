//
//  Firmware.swift
//  ___PROJECTNAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//

// Embedded Swift entry point.
// This example is a colour light for Matter, the smart home standard, so
// Apple's Home app (and Google Home, Amazon Alexa, ...) can control the
// board's LED: on and off, its brightness and its colour. It uses
// esp-matter, Espressif's Matter SDK, through Swift's C++ interoperability:
// the files Matter*.swift wrap its C++ API, from Apple's
// swift-matter-examples. The Kit's LightColor module turns the light's
// state into the LED's colour.
//
// It needs a board with 8 MB of flash, such as the ESP32-C6-DevKitC-1 (see
// partitions.csv), and a chip with Wi-Fi and Bluetooth LE, which Matter
// uses to join your network.
//
// To add the light to Apple Home, which needs a home hub (an Apple TV or a
// HomePod): in the Home app, tap + ▸ Add Accessory, and scan the QR code,
// or tap More options and enter the manual pairing code. The firmware
// prints both when it starts, and a link that shows the QR code. (They're
// esp-matter's test codes, which every device has until it gets codes of
// its own: MT:Y.K9042C00KA0648G00 and 3497-011-2332.) The Home app warns
// that the light isn't certified: choose Add Anyway. It then gives the
// light your Wi-Fi network, over Bluetooth LE.

import ESPIDF
import LightColor

@_cdecl("app_main")
public func app_main() {
    let led = LED(Board.led)
    var light = LightState()

    // (1) A Matter node: the device.
    let rootNode = Matter.Node()
    rootNode.identifyHandler = {
        print("Identify")
    }

    // (2) A colour light endpoint, whose attributes Matter sets.
    let lightEndpoint = Matter.ExtendedColorLight(node: rootNode)
    lightEndpoint.eventHandler = { event in
        switch event.attribute {
        case .onOff:
            light.isOn = event.value == 1
        case .levelControl:
            light.level = event.value
        case .colorControl(.currentHue):
            light.mode = .hueSaturation
            light.hue = event.value
        case .colorControl(.currentSaturation):
            light.mode = .hueSaturation
            light.saturation = event.value
        case .colorControl(.colorTemperatureMireds):
            light.mode = .temperature
            light.temperature = event.value
        default:
            return
        }
        let color = light.rgb
        led?.show(red: color.red, green: color.green, blue: color.blue)
        print("Light: \(light.isOn ? "on" : "off"), level \(light.level), colour \(color.red) \(color.green) \(color.blue)")
    }

    // (3) The endpoint is part of the node.
    rootNode.addEndpoint(lightEndpoint)

    // (4) Start Matter with the node.
    let app = Matter.Application()
    app.rootNode = rootNode
    app.start()

    // The codes to add the light with, such as in Apple's Home app.
    var qrCode = [CChar](repeating: 0, count: 32)
    var manualCode = [CChar](repeating: 0, count: 16)
    if getPairingCodes(&qrCode, qrCode.count, &manualCode, manualCode.count) {
        let qr = string(fromCString: qrCode)
        print("Matter colour light. To add it to Apple Home, scan the QR code at")
        print("  https://project-chip.github.io/connectedhomeip/qrcode.html?data=\(qr)")
        print("or enter the manual pairing code \(formattedPairingCode(string(fromCString: manualCode))).")
    }

    // Keep app_main's variables, which Matter's callbacks use, alive.
    while true {
        vTaskDelay(ticks(milliseconds: 1000))
    }
}

/// The text of a C string in an array.
func string(fromCString characters: [CChar]) -> String {
    String(decoding: characters.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)
}
