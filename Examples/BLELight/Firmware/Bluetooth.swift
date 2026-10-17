//
//  Bluetooth.swift
//  BLELight
//
//  Created by Johan Kool on 17-10-2026.
//

// Bluetooth LE, with NimBLE, ESP-IDF's Bluetooth LE stack: a GATT server
// with the light's service, and advertising, so phones can find and
// connect to it.
//
// NimBLE calls C functions with what happens, so the functions here are
// global functions or closures that don't capture anything, which Swift
// can pass as C function pointers. NimBLE runs them in its own task, one
// at a time.

// NimBLE's settings are in a global C variable, ble_hs_cfg, which Swift 6
// only lets code change without checks for concurrency with
// @preconcurrency.
@preconcurrency import ESPIDF
import Light

/// The light's service, and its characteristic: its colour, three bytes
/// (red, green, blue) to read and write. Their UUIDs were made with
/// `uuidgen`, as services of your own need UUIDs of their own.
let serviceUUID = "EF173EFA-F017-40BA-88E4-D14B7E316946"
let colorUUID = "DD7861D3-70C6-4373-943B-CD473F41FD19"

/// What the light's characteristic does when it's written: set by
/// startBluetooth.
nonisolated(unsafe) private var colorChanged: ((Color) -> Void)?
/// The light's colour, as its characteristic reads it.
nonisolated(unsafe) private var currentColor = Color(red: 0, green: 0, blue: 0)
/// The kind of Bluetooth address the ESP32 advertises with.
nonisolated(unsafe) private var addressType: UInt8 = 0

/// Starts Bluetooth: the light's service, under a name phones show, and
/// advertising. onChange is called with each colour written.
func startBluetooth(name: String, onChange: @escaping (Color) -> Void) -> Bool {
    colorChanged = onChange

    // NimBLE keeps its pairing data in NVS, the key-value storage in flash.
    var result = nvs_flash_init()
    if result == ESP_ERR_NVS_NO_FREE_PAGES || result == ESP_ERR_NVS_NEW_VERSION_FOUND {
        nvs_flash_erase()
        result = nvs_flash_init()
    }
    guard result == ESP_OK, nimble_port_init() == ESP_OK else { return false }

    // NimBLE's standard GAP and GATT services, with the device's name.
    ble_svc_gap_init()
    ble_svc_gatt_init()
    ble_svc_gap_device_name_set(name)

    guard let services = lightService(),
          ble_gatts_count_cfg(services) == 0,
          ble_gatts_add_svcs(services) == 0 else { return false }

    // Advertise once NimBLE is in sync with the Bluetooth controller.
    ble_hs_cfg.sync_cb = {
        ble_hs_util_ensure_addr(0)
        ble_hs_id_infer_auto(0, &addressType)
        advertise()
    }
    // NimBLE's own task runs the Bluetooth stack.
    nimble_port_freertos_init { _ in
        nimble_port_run()
        nimble_port_freertos_deinit()
    }
    return true
}

/// The light's service, as NimBLE's C structs: a list of services, each
/// with a list of characteristics. NimBLE keeps using them, so they're in
/// memory that's never freed, as C's static variables are.
private func lightService() -> UnsafePointer<ble_gatt_svc_def>? {
    guard let serviceUUID = uuid(serviceUUID), let colorUUID = uuid(colorUUID) else { return nil }

    var color = ble_gatt_chr_def()
    color.uuid = colorUUID
    color.flags = ble_gatt_chr_flags(BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_WRITE)
    color.access_cb = { _, _, context, _ in
        guard let context else { return Int32(BLE_ATT_ERR_UNLIKELY) }
        switch Int32(context.pointee.op) {
        case BLE_GATT_ACCESS_OP_READ_CHR:
            var bytes = currentColor.bytes
            return mbuf_append(context.pointee.om, &bytes, UInt16(bytes.count)) == 0
                ? 0 : Int32(BLE_ATT_ERR_INSUFFICIENT_RES)
        case BLE_GATT_ACCESS_OP_WRITE_CHR:
            var bytes = [UInt8](repeating: 0, count: 3)
            var length: UInt16 = 0
            guard ble_hs_mbuf_to_flat(context.pointee.om, &bytes, UInt16(bytes.count), &length) == 0,
                  let color = Color(bytes: bytes.prefix(Int(length))) else {
                return Int32(BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN)
            }
            currentColor = color
            colorChanged?(color)
            return 0
        default:
            return Int32(BLE_ATT_ERR_UNLIKELY)
        }
    }

    var service = ble_gatt_svc_def()
    service.type = UInt8(BLE_GATT_SVC_TYPE_PRIMARY)
    service.uuid = serviceUUID
    // Each list ends with an empty entry.
    service.characteristics = UnsafePointer(permanent([color, ble_gatt_chr_def()]))
    return UnsafePointer(permanent([service, ble_gatt_svc_def()]))
}

/// Advertises the ESP32, so phones find it and can connect, until one does.
private func advertise() {
    var fields = ble_hs_adv_fields()
    fields.flags = UInt8(BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP)
    // The device's name, which NimBLE keeps.
    guard let name = ble_svc_gap_device_name() else { return }
    fields.name = UnsafeRawPointer(name).assumingMemoryBound(to: UInt8.self)
    fields.name_len = UInt8(strlen(name))
    fields.name_is_complete = 1
    ble_gap_adv_set_fields(&fields)

    var parameters = ble_gap_adv_params()
    parameters.conn_mode = UInt8(BLE_GAP_CONN_MODE_UND)
    parameters.disc_mode = UInt8(BLE_GAP_DISC_MODE_GEN)
    if ble_gap_adv_start(addressType, nil, Int32.max, &parameters, handleConnection, nil) == 0 {
        print("Advertising as \(string(cString: name)).")
    }
}

/// Handles connections: advertises again when a phone disconnects.
private func handleConnection(_ event: UnsafeMutablePointer<ble_gap_event>?, _: UnsafeMutableRawPointer?) -> Int32 {
    guard let event else { return 0 }
    switch Int32(event.pointee.type) {
    case BLE_GAP_EVENT_CONNECT:
        if event.pointee.connect.status == 0 {
            print("Connected.")
        } else {
            advertise()
        }
    case BLE_GAP_EVENT_DISCONNECT:
        print("Disconnected.")
        advertise()
    default:
        break
    }
    return 0
}

/// A 128-bit UUID as NimBLE's C struct, in memory that's never freed.
private func uuid(_ text: String) -> UnsafePointer<ble_uuid_t>? {
    guard let bytes = uuidBytes(text) else { return nil }
    var uuid = ble_uuid128_t()
    uuid.u.type = UInt8(BLE_UUID_TYPE_128)
    withUnsafeMutableBytes(of: &uuid.value) { value in
        for (index, byte) in bytes.enumerated() { value[index] = byte }
    }
    return UnsafeRawPointer(permanent([uuid])).assumingMemoryBound(to: ble_uuid_t.self)
}

/// Copies values to memory that's never freed.
private func permanent<T>(_ values: [T]) -> UnsafeMutablePointer<T> {
    let pointer = UnsafeMutablePointer<T>.allocate(capacity: values.count)
    pointer.initialize(from: values, count: values.count)
    return pointer
}

/// The text of a C string.
private func string(cString: UnsafePointer<CChar>) -> String {
    String(decoding: UnsafeRawBufferPointer(start: cString, count: strlen(cString)), as: UTF8.self)
}
