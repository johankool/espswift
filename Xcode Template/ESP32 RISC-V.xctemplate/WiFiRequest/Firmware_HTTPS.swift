//
//  HTTPS.swift
//  ___PROJECTNAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//

// Requests over HTTPS, with ESP-IDF's HTTP client.

import ESPIDF

/// A response to a request: its status code, such as 200, and its body.
struct HTTPResponse {
    let status: Int32
    let body: [UInt8]
}

/// Requests a URL (https:// or http://) with a GET request; nil if the
/// request failed. Reads up to maxLength bytes of the body.
///
/// The server's certificate is checked against the root certificates
/// ESP-IDF comes with (its certificate bundle), as a web browser does.
func get(_ url: String, maxLength: Int = 2048) -> HTTPResponse? {
    var config = esp_http_client_config_t()
    config.crt_bundle_attach = esp_crt_bundle_attach
    // The client copies the URL, so the C string only has to last this call.
    let client = url.withCString { url in
        config.url = url
        return esp_http_client_init(&config)
    }
    guard let client else { return nil }
    defer { esp_http_client_cleanup(client) }

    guard esp_http_client_open(client, 0) == ESP_OK else { return nil }
    defer { esp_http_client_close(client) }
    guard esp_http_client_fetch_headers(client) >= 0 else { return nil }
    let status = esp_http_client_get_status_code(client)

    var body: [UInt8] = []
    var buffer = [CChar](repeating: 0, count: 512)
    while body.count < maxLength {
        let count = esp_http_client_read(client, &buffer, Int32(buffer.count))
        guard count > 0 else { break }
        body += buffer.prefix(Int(count)).map { UInt8(bitPattern: $0) }
    }
    return HTTPResponse(status: status, body: Array(body.prefix(maxLength)))
}
