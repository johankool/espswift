//
//  Firmware.swift
//  I2CSensor
//
//  Created by Johan Kool on 17-10-2026.
//

// Embedded Swift entry point.
// This example reads a Sensirion SHT4x temperature and humidity sensor
// (such as an SHT40 breakout board) over I2C, every 2 seconds, and shows
// the temperature on the LED: blue when cold, green, red when warm. Wire
// the sensor's SDA and SCL to the pins in Board.swift, VCC to 3V3 and GND
// to GND. The Kit's SHT4x module checks and converts the sensor's data.

import ESPIDF
import SHT4x

/// How long an I2C transfer may take, in milliseconds.
let timeout: Int32 = 100

@_cdecl("app_main")
public func app_main() {
    let led = LED(Board.led)

    // The I2C bus, on the board's SDA and SCL pins. The internal pull-up
    // resistors are enough for a short wire; most breakout boards have
    // their own as well.
    var busConfig = i2c_master_bus_config_t()
    busConfig.i2c_port = -1  // Any free I2C controller.
    busConfig.sda_io_num = gpio_num_t(Board.i2cSDA)
    busConfig.scl_io_num = gpio_num_t(Board.i2cSCL)
    busConfig.clk_source = I2C_CLK_SRC_DEFAULT
    busConfig.glitch_ignore_cnt = 7
    busConfig.flags.enable_internal_pullup = 1
    var bus: i2c_master_bus_handle_t?
    guard i2c_new_master_bus(&busConfig, &bus) == ESP_OK else {
        print("Couldn't set up the I2C bus on SDA GPIO \(Board.i2cSDA) and SCL GPIO \(Board.i2cSCL).")
        return
    }

    // Wait for the sensor to answer at its address.
    while i2c_master_probe(bus, SHT4x.address, timeout) != ESP_OK {
        print("No SHT4x sensor answers at address 0x44, on SDA GPIO \(Board.i2cSDA) and SCL GPIO \(Board.i2cSCL); check the wiring. Trying again in 5 seconds.")
        vTaskDelay(ticks(milliseconds: 5000))
    }

    // The sensor, as a device on the bus.
    var deviceConfig = i2c_device_config_t()
    deviceConfig.dev_addr_length = I2C_ADDR_BIT_LEN_7
    deviceConfig.device_address = SHT4x.address
    deviceConfig.scl_speed_hz = 100_000
    var sensor: i2c_master_dev_handle_t?
    guard i2c_master_bus_add_device(bus, &deviceConfig, &sensor) == ESP_OK else {
        print("Couldn't add the sensor to the I2C bus.")
        return
    }

    if let serialNumber = read(sensor, command: SHT4x.readSerialNumber, waitMilliseconds: 20),
       let words = SHT4x.words(in: serialNumber), words.count == 2 {
        print("Found an SHT4x sensor, serial number \(UInt32(words[0]) << 16 | UInt32(words[1])).")
    }

    while true {
        if let response = read(sensor, command: SHT4x.measureHighPrecision, waitMilliseconds: 20),
           let measurement = Measurement(response: response) {
            print("Temperature: \(decimal(hundredths: measurement.temperature)) °C, humidity: \(decimal(hundredths: measurement.humidity)) %")
            // Blue below 20 °C, green up to 25 °C, red above.
            switch measurement.temperature {
            case ..<2_000: led?.show(red: 0, green: 0, blue: 32)
            case ..<2_500: led?.show(red: 0, green: 32, blue: 0)
            default: led?.show(red: 32, green: 0, blue: 0)
            }
        } else {
            print("Reading the sensor failed.")
        }
        vTaskDelay(ticks(milliseconds: 2000))
    }
}

/// Sends a command to the sensor, waits for it, and reads its response:
/// 6 bytes, two words with their checksums. Nil if a transfer failed.
/// (A wait of 20 ms is at least 10 ms: vTaskDelay waits whole ticks of
/// 10 ms, and the first one may be nearly over.)
func read(_ sensor: i2c_master_dev_handle_t?, command: UInt8, waitMilliseconds: UInt32) -> [UInt8]? {
    var command = command
    guard i2c_master_transmit(sensor, &command, 1, timeout) == ESP_OK else { return nil }
    vTaskDelay(ticks(milliseconds: waitMilliseconds))
    var response = [UInt8](repeating: 0, count: 6)
    guard i2c_master_receive(sensor, &response, response.count, timeout) == ESP_OK else { return nil }
    return response
}
