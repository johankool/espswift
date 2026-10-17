//
//  ESPIDF.h
//  ___PROJECTNAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
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
#include "nvs_flash.h"

// Bluetooth LE with NimBLE, on chips that have Bluetooth (not the
// ESP32-P4); sdkconfig.defaults turns it on.
#if CONFIG_BT_NIMBLE_ENABLED
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "host/ble_hs.h"
#include "os/os_mbuf.h"
#include "host/util/util.h"
#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"

// On some chips, such as the ESP32-C6, os_mbuf_append is a C macro that
// renames another function, which Swift can't call; this function can.
static inline int mbuf_append(struct os_mbuf *mbuf, const void *data, uint16_t length) {
    return os_mbuf_append(mbuf, data, length);
}
#endif

#endif /* ESPIDF_h */
