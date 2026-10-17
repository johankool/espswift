//
//  WiFi.swift
//  ___PROJECTNAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//

// Wi-Fi, with ESP-IDF's Wi-Fi driver and network interface (esp_netif):
// listing the networks nearby, and connecting to one. Only on chips that
// have Wi-Fi (not the ESP32-H2 and ESP32-P4).

#if CONFIG_SOC_WIFI_SUPPORTED

import ESPIDF
import Network

/// The ESP32's Wi-Fi, as a station: a client of an access point.
struct WiFi {
    /// ESP-IDF's network interface for Wi-Fi, which gets the IP address.
    private let interface: OpaquePointer

    /// Starts Wi-Fi; nil if that failed.
    init?() {
        // The Wi-Fi driver keeps its calibration data in NVS, the
        // key-value storage in flash, which needs setting up first.
        var result = nvs_flash_init()
        if result == ESP_ERR_NVS_NO_FREE_PAGES || result == ESP_ERR_NVS_NEW_VERSION_FOUND {
            nvs_flash_erase()
            result = nvs_flash_init()
        }
        guard result == ESP_OK,
              esp_netif_init() == ESP_OK,
              esp_event_loop_create_default() == ESP_OK,
              let interface = esp_netif_create_default_wifi_sta() else { return nil }
        self.interface = interface

        var config = wifi_init_config_default()
        guard esp_wifi_init(&config) == ESP_OK,
              esp_wifi_set_mode(WIFI_MODE_STA) == ESP_OK,
              esp_wifi_start() == ESP_OK else { return nil }
    }

    /// The networks nearby, strongest first: their names, and their signal
    /// strengths in dBm (-50 is strong, -80 is weak).
    func scan() -> [(name: String, signal: Int8)] {
        guard esp_wifi_scan_start(nil, true) == ESP_OK else { return [] }
        var count: UInt16 = 0
        esp_wifi_scan_get_ap_num(&count)
        var records = [wifi_ap_record_t](repeating: wifi_ap_record_t(), count: Int(count))
        esp_wifi_scan_get_ap_records(&count, &records)
        return records.prefix(Int(count)).map { record in
            (name: withUnsafeBytes(of: record.ssid) { string(cString: $0) }, signal: record.rssi)
        }
    }

    /// Connects to a network, trying a few times; returns the IP address
    /// the network gave the ESP32, or nil if connecting failed.
    func connect(to name: String, password: String) -> UInt32? {
        // The network's name and password go in C arrays of fixed size.
        var config = wifi_config_t()
        withUnsafeMutableBytes(of: &config.sta.ssid) { copy(name, to: $0) }
        withUnsafeMutableBytes(of: &config.sta.password) { copy(password, to: $0) }
        guard esp_wifi_set_config(WIFI_IF_STA, &config) == ESP_OK else { return nil }

        // ESP-IDF reports what happens as events, to a C function. This one
        // sets a bit in a FreeRTOS event group, which connect() waits for.
        guard let events = xEventGroupCreate() else { return nil }
        let handler: esp_event_handler_t = { events, base, id, _ in
            if base == WIFI_EVENT && id == Int32(WIFI_EVENT_STA_DISCONNECTED.rawValue) {
                xEventGroupSetBits(OpaquePointer(events), failedBit)
            } else if base == IP_EVENT && id == Int32(IP_EVENT_STA_GOT_IP.rawValue) {
                xEventGroupSetBits(OpaquePointer(events), connectedBit)
            }
        }
        esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, handler, UnsafeMutableRawPointer(events))
        esp_event_handler_register(IP_EVENT, ESP_EVENT_ANY_ID, handler, UnsafeMutableRawPointer(events))
        defer {
            esp_event_handler_unregister(WIFI_EVENT, ESP_EVENT_ANY_ID, handler)
            esp_event_handler_unregister(IP_EVENT, ESP_EVENT_ANY_ID, handler)
            vEventGroupDelete(events)
        }

        for attempt in 1...5 {
            esp_wifi_connect()
            // Wait up to 15 seconds for either bit, and clear it.
            let bits = xEventGroupWaitBits(events, connectedBit | failedBit, 1, 0, ticks(milliseconds: 15_000))
            if bits & connectedBit != 0 {
                var info = esp_netif_ip_info_t()
                esp_netif_get_ip_info(interface, &info)
                return info.ip.addr
            }
            print("Attempt \(attempt) failed.")
            vTaskDelay(ticks(milliseconds: 1000))
        }
        return nil
    }
}

/// The event group's bits.
private let connectedBit: EventBits_t = 1 << 0
private let failedBit: EventBits_t = 1 << 1

/// Copies a string's UTF-8 bytes to a C array, as far as they fit.
private func copy(_ text: String, to buffer: UnsafeMutableRawBufferPointer) {
    for (index, byte) in text.utf8.prefix(buffer.count).enumerated() {
        buffer[index] = byte
    }
}

#endif
