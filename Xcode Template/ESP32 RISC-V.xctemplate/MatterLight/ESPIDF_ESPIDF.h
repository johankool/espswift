//
//  ESPIDF.h
//  ___PROJECTNAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//

// The ESPIDF module: ESP-IDF's C APIs for Swift code, which uses them with
// `import ESPIDF`, and esp-matter's C++ API, which the Firmware target
// imports with C++ interoperability (see Package.swift).

#ifndef ESPIDF_h
#define ESPIDF_h

// ESP-IDF 6's stdio.h uses ssize_t without including sys/types.h.
#include <sys/types.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "sdkconfig.h"
#include "led_strip.h"
#include "driver/gpio.h"
#include "nvs_flash.h"

// esp-matter, in C++: only for Swift code, which imports this header as
// C++. (The ESPIDF target's own C file doesn't include it.)
#ifdef __cplusplus

// As esp-matter's build defines them (for Swift; ESP-IDF's compiler has them).
#ifndef CHIP_HAVE_CONFIG_H
#define CHIP_HAVE_CONFIG_H 1
#endif
#ifndef CHIP_USE_ENUM_CLASS_FOR_IM_ENUM
#define CHIP_USE_ENUM_CLASS_FOR_IM_ENUM 1
#endif
#ifndef CHIP_ADDRESS_RESOLVE_IMPL_INCLUDE_HEADER
#define CHIP_ADDRESS_RESOLVE_IMPL_INCLUDE_HEADER <lib/address_resolve/AddressResolve_DefaultImpl.h>
#endif

// connectedhomeip's headers use strnlen and strdup without including what
// declares them.
extern "C" size_t strnlen(const char *s, size_t maxlen);
extern "C" char *strdup(const char *s1);

#include <esp_matter.h>
#include <esp_matter_cluster.h>
#include <app-common/zap-generated/ids/Clusters.h>
#include <app/server/Server.h>

// Small C++ functions for what Swift can't call directly, from
// swiftlang/swift-matter-examples (smart-light). ESP-IDF's compiler (GCC)
// makes uint32_t an unsigned long, but Swift's (Clang) an unsigned int, so
// Swift can't call esp-matter's functions that take one: these take
// unsigned ints, and ESP-IDF compiles them (main/MatterShims.cpp).
namespace esp_matter {
  namespace attribute {
    typedef esp_err_t (*callback_t_shim)(callback_type_t type, uint16_t endpoint_id, unsigned int cluster_id,
                                         unsigned int attribute_id, esp_matter_attr_val_t *val, void *priv_data);
    esp_err_t set_callback_shim(callback_t_shim callback);
    attribute_t *get_shim(cluster_t *cluster, unsigned int attribute_id);
  }
  namespace cluster {
    cluster_t *get_shim(endpoint_t *endpoint, unsigned int cluster_id);
  }
}

// Opens the commissioning window again when the light was removed from its
// last Matter fabric (home), so it can be added again.
void recomissionFabric();

// Writes the codes to add the light with, as C strings: the QR code's
// contents (MT:...) and the manual pairing code (11 digits). False if that
// failed. (Once Matter has started.)
bool getPairingCodes(char *qrCode, size_t qrCodeSize, char *manualCode, size_t manualCodeSize);

#endif /* __cplusplus */

#endif /* ESPIDF_h */
