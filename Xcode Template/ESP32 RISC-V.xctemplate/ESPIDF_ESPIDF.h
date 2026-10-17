//
//  ESPIDF.h
//  ___PROJECTNAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//

// The ESPIDF module: ESP-IDF's C APIs for Swift code, which uses them with
// `import ESPIDF`. Add any C headers you need to access from Swift here, and
// wrappers for the C macros Swift can't call. Swift code can check ESP-IDF's
// settings and the chip's features with #if, as C does: the build passes
// those enabled in sdkconfig as conditions, such as CONFIG_SOC_RMT_SUPPORTED.

#ifndef ESPIDF_h
#define ESPIDF_h

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "sdkconfig.h"
#include "led_strip.h"
#include "driver/gpio.h"

// ── FreeRTOS Macro Wrappers ──────────────────────────────────────
// C macros like pdMS_TO_TICKS() cannot be called directly from Swift.
// These inline functions wrap them for Swift compatibility.

/// Convert milliseconds to FreeRTOS ticks.
/// Assumes default tick rate of 100 Hz (configTICK_RATE_HZ=100),
/// so 1000 ms = 100 ticks.
static inline TickType_t pd_ms_to_ticks(uint32_t ms) {
    return pdMS_TO_TICKS(ms);
}

#endif /* ESPIDF_h */
