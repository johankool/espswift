//
//  Credentials.swift
//  WiFiRequest
//
//  Created by Johan Kool on 17-10-2026.
//

// The Wi-Fi network to connect to (2.4 GHz; the ESP32s don't support
// 5 GHz, except the ESP32-C5). With an empty name, the firmware lists the
// networks nearby instead.
//
// Keep your password out of a public repository: e.g. don't commit this
// file after filling it in.

enum Credentials {
    static let wifiName = ""
    static let wifiPassword = ""
}
