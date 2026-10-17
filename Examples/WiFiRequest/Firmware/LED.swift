//
//  LED.swift
//  WiFiRequest
//
//  Created by Johan Kool on 17-10-2026.
//

// The board's LED, whatever kind it is, driven with ESP-IDF's led_strip and
// GPIO drivers. Board.swift says which LED the board has.

import ESPIDF

/// The kinds of LED boards have, and their pins (GPIO numbers).
enum BoardLED {
    /// An addressable RGB LED (WS2812), and the pin that powers it, if any:
    /// it's turned on first.
    case addressable(pin: Int32, powerPin: Int32? = nil)
    /// Separate red, green and blue LEDs, each on or off. With activeLow, a
    /// low level turns them on.
    case rgb(red: Int32, green: Int32, blue: Int32, activeLow: Bool = false)
    /// A one-colour LED, on for any colour but black.
    case single(pin: Int32, activeLow: Bool = false)
    /// No LED to blink.
    case none
}

/// A board's LED, set up to show colours.
struct LED {
    let kind: BoardLED
    /// The driver of an addressable LED.
    private var strip: led_strip_handle_t?

    /// Sets up the LED, off; nil if the board has none, or setting it up
    /// failed.
    init?(_ kind: BoardLED) {
        self.kind = kind
        switch kind {
        case .addressable(let pin, let powerPin):
            if let powerPin { Self.makeOutput(powerPin, on: true, activeLow: false) }
            guard let strip = Self.newStrip(pin: pin) else { return nil }
            led_strip_clear(strip)
            self.strip = strip
        case .rgb(let red, let green, let blue, let activeLow):
            for pin in [red, green, blue] { Self.makeOutput(pin, on: false, activeLow: activeLow) }
        case .single(let pin, let activeLow):
            Self.makeOutput(pin, on: false, activeLow: activeLow)
        case .none:
            return nil
        }
    }

    /// Shows a colour; each component is 0–255.
    func show(red: UInt32, green: UInt32, blue: UInt32) {
        switch kind {
        case .addressable:
            led_strip_set_pixel(strip, 0, red, green, blue)
            led_strip_refresh(strip)
        case .rgb(let redPin, let greenPin, let bluePin, let activeLow):
            Self.set(redPin, on: red > 0, activeLow: activeLow)
            Self.set(greenPin, on: green > 0, activeLow: activeLow)
            Self.set(bluePin, on: blue > 0, activeLow: activeLow)
        case .single(let pin, let activeLow):
            Self.set(pin, on: red > 0 || green > 0 || blue > 0, activeLow: activeLow)
        case .none:
            break
        }
    }

    /// The driver for an addressable LED. It generates the precise pulses
    /// WS2812 LEDs need with the RMT peripheral, or with SPI on chips that
    /// have no RMT (ESP32-C2, ESP32-C61).
    private static func newStrip(pin: Int32) -> led_strip_handle_t? {
        var config = led_strip_config_t()
        config.strip_gpio_num = pin
        config.max_leds = 1
        var strip: led_strip_handle_t?
        #if CONFIG_SOC_RMT_SUPPORTED
        var rmt = led_strip_rmt_config_t()
        rmt.resolution_hz = 10_000_000  // 10 MHz ticks
        rmt.mem_block_symbols = 64
        guard led_strip_new_rmt_device(&config, &rmt, &strip) == ESP_OK else { return nil }
        #else
        var spi = led_strip_spi_config_t()
        spi.clk_src = SPI_CLK_SRC_DEFAULT
        spi.spi_bus = SPI2_HOST
        guard led_strip_new_spi_device(&config, &spi, &strip) == ESP_OK else { return nil }
        #endif
        return strip
    }

    /// Makes a pin an output, on or off.
    private static func makeOutput(_ pin: Int32, on: Bool, activeLow: Bool) {
        gpio_reset_pin(gpio_num_t(pin))
        gpio_set_direction(gpio_num_t(pin), GPIO_MODE_OUTPUT)
        set(pin, on: on, activeLow: activeLow)
    }

    /// Turns a pin on or off, as the LED's polarity needs.
    private static func set(_ pin: Int32, on: Bool, activeLow: Bool) {
        gpio_set_level(gpio_num_t(pin), on != activeLow ? 1 : 0)
    }
}
