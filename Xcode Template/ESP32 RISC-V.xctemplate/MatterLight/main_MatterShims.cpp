// esp-matter functions for Swift, which can't call some of them directly
// (see Firmware/ESPIDF/include/ESPIDF.h), from swiftlang/swift-matter-examples
// (smart-light). ESP-IDF compiles this file, as part of the main component.

// connectedhomeip's headers use C++ features that GCC 15 deprecates.
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

#include "../../Firmware/ESPIDF/include/ESPIDF.h"
#include <setup_payload/OnboardingCodesUtil.h>

esp_err_t esp_matter::attribute::set_callback_shim(callback_t_shim callback) {
  return set_callback((callback_t)callback);
}

esp_matter::attribute_t *esp_matter::attribute::get_shim(esp_matter::cluster_t *cluster, unsigned int attribute_id) {
  return get(cluster, (uint32_t)attribute_id);
}

esp_matter::cluster_t *esp_matter::cluster::get_shim(esp_matter::endpoint_t *endpoint, unsigned int cluster_id) {
  return get(endpoint, (uint32_t)cluster_id);
}

void recomissionFabric() {
  if (chip::Server::GetInstance().GetFabricTable().FabricCount() == 0) {
    chip::CommissioningWindowManager &manager = chip::Server::GetInstance().GetCommissioningWindowManager();
    constexpr auto kTimeoutSeconds = chip::System::Clock::Seconds16(300);
    if (!manager.IsCommissioningWindowOpen()) {
      (void)manager.OpenBasicCommissioningWindow(kTimeoutSeconds, chip::CommissioningWindowAdvertisement::kDnssdOnly);
    }
  }
}

bool getPairingCodes(char *qrCode, size_t qrCodeSize, char *manualCode, size_t manualCodeSize) {
  if (qrCodeSize == 0 || manualCodeSize == 0) {
    return false;
  }
  // The light is added over Bluetooth LE.
  auto flags = chip::RendezvousInformationFlags(chip::RendezvousInformationFlag::kBLE);
  // Leave room for the terminating zero.
  chip::MutableCharSpan qr(qrCode, qrCodeSize - 1);
  chip::MutableCharSpan manual(manualCode, manualCodeSize - 1);
  if (GetQRCode(qr, flags) != CHIP_NO_ERROR || GetManualPairingCode(manual, flags) != CHIP_NO_ERROR) {
    return false;
  }
  qrCode[qr.size()] = '\0';
  manualCode[manual.size()] = '\0';
  return true;
}
