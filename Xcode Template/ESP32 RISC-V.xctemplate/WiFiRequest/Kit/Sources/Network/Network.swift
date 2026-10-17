// Text for network data, in plain Swift: it doesn't use ESP-IDF, so it can
// be tested on the Mac (see Tests/NetworkTests: Cmd+U).

/// An IPv4 address as text, such as "192.168.1.20". The address is as
/// ESP-IDF (lwIP) stores it: in network byte order, so on the ESP32, which
/// is little-endian, the first number is the lowest byte.
public func dottedDecimal(_ address: UInt32) -> String {
    let bytes = [address, address >> 8, address >> 16, address >> 24].map { $0 & 0xFF }
    return "\(bytes[0]).\(bytes[1]).\(bytes[2]).\(bytes[3])"
}

/// The text in a C string's bytes, up to the first zero byte, such as a Wi-Fi
/// network's name in a fixed-size C array. Invalid UTF-8 shows as "�".
public func string(cString bytes: some Collection<UInt8>) -> String {
    String(decoding: bytes.prefix(while: { $0 != 0 }), as: UTF8.self)
}
