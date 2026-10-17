//
//  Firmware.swift
//  WiFiRequest
//
//  Created by Johan Kool on 17-10-2026.
//

// Embedded Swift entry point.
// This example connects to a Wi-Fi network and requests a web page over
// HTTPS. Set your network's name and password in Credentials.swift; until
// then, it lists the networks nearby. The LED shows how it's going: blue
// while connecting, green when the request succeeded, red when it failed.
// WiFi.swift and HTTPS.swift do the work.

import ESPIDF
import Network

/// The page to request: GitHub's API answers with a short quote.
let url = "https://api.github.com/zen"

@_cdecl("app_main")
public func app_main() {
    let led = LED(Board.led)

    guard let wifi = WiFi() else {
        print("Starting Wi-Fi failed.")
        return
    }

    guard !Credentials.wifiName.isEmpty else {
        print("Wi-Fi networks nearby:")
        for network in wifi.scan() {
            print("  \(network.name) (\(network.signal) dBm)")
        }
        print("To connect to one, set its name and password in Credentials.swift.")
        return
    }

    led?.show(red: 0, green: 0, blue: 32)
    print("Connecting to \(Credentials.wifiName)...")
    guard let address = wifi.connect(to: Credentials.wifiName, password: Credentials.wifiPassword) else {
        led?.show(red: 32, green: 0, blue: 0)
        print("Couldn't connect to \(Credentials.wifiName). Check its name and password in Credentials.swift.")
        return
    }
    print("Connected; IP address: \(dottedDecimal(address))")

    print("Requesting \(url)...")
    guard let response = get(url) else {
        led?.show(red: 32, green: 0, blue: 0)
        print("The request failed.")
        return
    }
    led?.show(red: 0, green: response.status == 200 ? 32 : 0, blue: 0)
    print("Status \(response.status): \(String(decoding: response.body, as: UTF8.self))")
}
