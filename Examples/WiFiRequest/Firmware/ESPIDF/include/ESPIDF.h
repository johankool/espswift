//
//  ESPIDF.h
//  WiFiRequest
//
//  Created by Johan Kool on 17-10-2026.
//

// The ESPIDF module: ESP-IDF's C APIs for Swift code, which uses them with
// `import ESPIDF`. Add any C headers you need to access from Swift here.
// Swift can't call C macros that take arguments, such as pdMS_TO_TICKS();
// FreeRTOS.swift has Swift versions of those. Swift code can check ESP-IDF's
// settings and the chip's features with #if, as C does: the build passes
// those enabled in sdkconfig as conditions, such as CONFIG_SOC_RMT_SUPPORTED.

#ifndef ESPIDF_h
#define ESPIDF_h

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "sdkconfig.h"
#include "led_strip.h"
#include "driver/gpio.h"
#include "freertos/event_groups.h"
#include "nvs_flash.h"
#include "esp_event.h"
#include "esp_netif.h"
#include "esp_wifi.h"
#include "esp_http_client.h"
#include "esp_crt_bundle.h"

// Swift can't use C macros that fill in a struct, such as
// WIFI_INIT_CONFIG_DEFAULT(); a function in a header can, and Swift can
// call it.
static inline wifi_init_config_t wifi_init_config_default(void) {
    wifi_init_config_t config = WIFI_INIT_CONFIG_DEFAULT();
    return config;
}

#endif /* ESPIDF_h */
