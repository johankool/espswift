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
#include "esp_sleep.h"
#include "driver/usb_serial_jtag.h"

#endif /* ESPIDF_h */
