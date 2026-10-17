//
//  FreeRTOS.swift
//  ButtonInput
//
//  Created by Johan Kool on 17-10-2026.
//

// Swift versions of FreeRTOS's C macros, which Swift can't call.

import ESPIDF

/// The FreeRTOS ticks in a number of milliseconds, as C's pdMS_TO_TICKS():
/// for vTaskDelay and the like. A tick is 10 ms by default
/// (configTICK_RATE_HZ, CONFIG_FREERTOS_HZ in sdkconfig, is 100).
func ticks(milliseconds: UInt32) -> TickType_t {
    TickType_t(UInt64(milliseconds) * UInt64(configTICK_RATE_HZ) / 1000)
}
