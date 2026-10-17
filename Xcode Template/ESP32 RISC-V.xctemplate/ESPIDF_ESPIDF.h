//
//  ESPIDF.h
//  ___PROJECTNAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//

// The ESPIDF module: ESP-IDF's C APIs for Swift code, which uses them with
// `import ESPIDF`. Add any C headers you need to access from Swift here.

#ifndef ESPIDF_h
#define ESPIDF_h

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "sdkconfig.h"
#include "led_strip.h"
#include "driver/gpio.h"
#include <stdbool.h>

// ── FreeRTOS Macro Wrappers ──────────────────────────────────────
// C macros like pdMS_TO_TICKS() cannot be called directly from Swift.
// These inline functions wrap them for Swift compatibility.

/// Convert milliseconds to FreeRTOS ticks.
/// Assumes default tick rate of 100 Hz (configTICK_RATE_HZ=100),
/// so 1000 ms = 100 ticks.
static inline TickType_t pd_ms_to_ticks(uint32_t ms) {
    return pdMS_TO_TICKS(ms);
}

// ── Board ────────────────────────────────────────────────────────
// The board chosen when the project was created: ___VARIABLE_boardName___.
// Its LED is one of:
//   BOARD_LED_ADDRESSABLE   an addressable RGB LED (WS2812) on BOARD_LED_GPIO
//   BOARD_LED_SINGLE        a one-colour LED on BOARD_LED_GPIO
//   BOARD_LED_RGB           separate red, green and blue LEDs on
//                           BOARD_LED_GPIO, BOARD_LED_GREEN_GPIO and
//                           BOARD_LED_BLUE_GPIO
//   BOARD_LED_NONE          no LED you can blink
//   BOARD_LED_CHIP_DEFAULT  another board: a WS2812 on the pin Espressif's
//                           DevKits use for the chip (see BOARD_LED_PIN)
// BOARD_LED_POWER_GPIO, if not -1, powers the LED: it's set high first.
// With BOARD_LED_ACTIVE_LOW 1, a low level turns the LED on.
// For another board, change these to match it.

#define BOARD_NAME "___VARIABLE_boardName___"
#define ___VARIABLE_boardLEDKind___ 1
#define BOARD_LED_GPIO ___VARIABLE_boardLEDGPIO___
#define BOARD_LED_GREEN_GPIO ___VARIABLE_boardLEDGreenGPIO___
#define BOARD_LED_BLUE_GPIO ___VARIABLE_boardLEDBlueGPIO___
#define BOARD_LED_POWER_GPIO ___VARIABLE_boardLEDPowerGPIO___
#define BOARD_LED_ACTIVE_LOW ___VARIABLE_boardLEDActiveLow___

// The LED's pin (the red one, for BOARD_LED_RGB); for another board, the
// pin of the WS2812 on Espressif's DevKits for the chip, as in ESP-IDF's
// blink example. -1 if there's no LED.
#if BOARD_LED_CHIP_DEFAULT && CONFIG_IDF_TARGET_ESP32C5
#define BOARD_LED_PIN 27
#elif BOARD_LED_CHIP_DEFAULT && CONFIG_IDF_TARGET_ESP32P4
#define BOARD_LED_PIN 44
#elif BOARD_LED_CHIP_DEFAULT
#define BOARD_LED_PIN 8
#else
#define BOARD_LED_PIN BOARD_LED_GPIO
#endif

/// The board's LED, whatever kind it is.
typedef struct {
    led_strip_handle_t strip;   // For an addressable LED
} board_led_t;

/// Turns a pin on or off, as the LED's polarity needs.
static inline void board_led_write(int gpio, bool on) {
    if (gpio >= 0) {
        gpio_set_level((gpio_num_t)gpio, on != BOARD_LED_ACTIVE_LOW);
    }
}

/// Sets up the board's LED, off. Returns ESP_ERR_NOT_SUPPORTED if the
/// board has none. An addressable LED uses the RMT peripheral on chips that
/// have one, and SPI on chips that don't (ESP32-C2, ESP32-C61).
static inline esp_err_t board_led_new(board_led_t *led) {
    *led = (board_led_t){0};
    if (BOARD_LED_POWER_GPIO >= 0) {
        gpio_reset_pin((gpio_num_t)BOARD_LED_POWER_GPIO);
        gpio_set_direction((gpio_num_t)BOARD_LED_POWER_GPIO, GPIO_MODE_OUTPUT);
        gpio_set_level((gpio_num_t)BOARD_LED_POWER_GPIO, 1);
    }
#if BOARD_LED_ADDRESSABLE || BOARD_LED_CHIP_DEFAULT
    led_strip_config_t strip_config = {
        .strip_gpio_num = BOARD_LED_PIN,
        .max_leds = 1,                        // Only one LED on board
    };
#if CONFIG_SOC_RMT_SUPPORTED
    led_strip_rmt_config_t rmt_config = {
        .resolution_hz = 10 * 1000 * 1000,    // 10 MHz tick resolution
        .mem_block_symbols = 64,
    };
    esp_err_t err = led_strip_new_rmt_device(&strip_config, &rmt_config, &led->strip);
#else
    led_strip_spi_config_t spi_config = {
        .clk_src = SPI_CLK_SRC_DEFAULT,
        .spi_bus = SPI2_HOST,
    };
    esp_err_t err = led_strip_new_spi_device(&strip_config, &spi_config, &led->strip);
#endif
    if (err == ESP_OK) {
        led_strip_clear(led->strip);
    }
    return err;
#elif BOARD_LED_SINGLE || BOARD_LED_RGB
    const int pins[] = {BOARD_LED_GPIO, BOARD_LED_GREEN_GPIO, BOARD_LED_BLUE_GPIO};
    for (int i = 0; i < 3; i++) {
        if (pins[i] < 0) continue;
        gpio_reset_pin((gpio_num_t)pins[i]);
        esp_err_t err = gpio_set_direction((gpio_num_t)pins[i], GPIO_MODE_OUTPUT);
        if (err != ESP_OK) return err;
        board_led_write(pins[i], false);
    }
    return ESP_OK;
#else
    return ESP_ERR_NOT_SUPPORTED;
#endif
}

/// Shows a colour (each 0–255) on the board's LED. A one-colour LED is on
/// for any colour but black; separate red, green and blue LEDs are each on
/// or off.
static inline void board_led_set(board_led_t *led, uint32_t red, uint32_t green, uint32_t blue) {
    (void)led; (void)red; (void)green; (void)blue;
#if BOARD_LED_ADDRESSABLE || BOARD_LED_CHIP_DEFAULT
    led_strip_set_pixel(led->strip, 0, red, green, blue);
    led_strip_refresh(led->strip);
#elif BOARD_LED_SINGLE
    board_led_write(BOARD_LED_GPIO, red || green || blue);
#elif BOARD_LED_RGB
    board_led_write(BOARD_LED_GPIO, red > 0);
    board_led_write(BOARD_LED_GREEN_GPIO, green > 0);
    board_led_write(BOARD_LED_BLUE_GPIO, blue > 0);
#endif
}

#endif /* ESPIDF_h */
