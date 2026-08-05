#include "projection_plugin/usb_device_monitor.h"

#include <libudev.h>

#include <algorithm>
#include <array>
#include <cctype>
#include <string>

namespace {

std::string ValueOrEmpty(const char* value) {
  return value == nullptr ? std::string() : std::string(value);
}

std::string Lowercase(std::string value) {
  std::transform(value.begin(), value.end(), value.begin(), [](char character) {
    return static_cast<char>(
        std::tolower(static_cast<unsigned char>(character)));
  });
  return value;
}

bool ContainsAny(const std::string& value,
                 const std::array<const char*, 13>& candidates) {
  const std::string normalized = Lowercase(value);
  return std::any_of(candidates.begin(), candidates.end(),
                     [&normalized](const char* candidate) {
                       return normalized.find(candidate) != std::string::npos;
                     });
}

bool IsKnownAndroidVendor(const std::string& vendor_id) {
  constexpr std::array<const char*, 11> kAndroidVendorIds = {
      "04e8",  // Samsung
      "0bb4",  // HTC
      "0fce",  // Sony
      "1004",  // LG
      "12d1",  // Huawei
      "18d1",  // Google / Android Open Accessory
      "22b8",  // Motorola
      "22d9",  // OPPO
      "2717",  // Xiaomi
      "2a70",  // OnePlus
      "2d95",  // vivo
  };
  return std::find(kAndroidVendorIds.begin(), kAndroidVendorIds.end(),
                   Lowercase(vendor_id)) != kAndroidVendorIds.end();
}

bool IsAccessoryMode(const std::string& vendor_id,
                     const std::string& product_id) {
  if (Lowercase(vendor_id) != "18d1" || product_id.size() != 4) return false;
  const std::string normalized_product = Lowercase(product_id);
  return normalized_product >= "2d00" && normalized_product <= "2d05";
}

int CandidateScore(udev_device* device,
                   const std::string& vendor_id,
                   const std::string& product_id) {
  if (IsAccessoryMode(vendor_id, product_id)) return 100;

  const std::string interfaces = ValueOrEmpty(
      udev_device_get_property_value(device, "ID_USB_INTERFACES"));
  if (Lowercase(interfaces).find(":ff4201:") != std::string::npos) {
    return 80;  // Android Debug Bridge interface.
  }

  constexpr std::array<const char*, 13> kAndroidNames = {
      "android", "google",  "pixel",    "samsung", "xiaomi",
      "redmi",   "oneplus", "oppo",     "realme",  "vivo",
      "motorola", "huawei", "honor",
  };
  const std::string identity =
      ValueOrEmpty(udev_device_get_property_value(device, "ID_VENDOR")) + " " +
      ValueOrEmpty(udev_device_get_property_value(device, "ID_VENDOR_FROM_DATABASE")) +
      " " + ValueOrEmpty(udev_device_get_property_value(device, "ID_MODEL")) +
      " " + ValueOrEmpty(
          udev_device_get_property_value(device, "ID_MODEL_FROM_DATABASE"));
  if (ContainsAny(identity, kAndroidNames)) return 60;
  if (IsKnownAndroidVendor(vendor_id)) return 40;
  return 0;
}

std::string DeviceName(udev_device* device) {
  constexpr std::array<const char*, 4> kNameProperties = {
      "ID_MODEL_FROM_DATABASE", "ID_MODEL", "ID_VENDOR_FROM_DATABASE",
      "ID_VENDOR"};
  for (const char* property : kNameProperties) {
    const char* value = udev_device_get_property_value(device, property);
    if (value != nullptr && value[0] != '\0') return value;
  }
  return "Android USB device";
}

}  // namespace

UsbPhoneStatus UsbDeviceMonitor::Scan() const {
  UsbPhoneStatus best;
  int best_score = 0;

  udev* context = udev_new();
  if (context == nullptr) return best;

  udev_enumerate* enumerate = udev_enumerate_new(context);
  if (enumerate == nullptr) {
    udev_unref(context);
    return best;
  }

  udev_enumerate_add_match_subsystem(enumerate, "usb");
  udev_enumerate_add_match_property(enumerate, "DEVTYPE", "usb_device");
  udev_enumerate_scan_devices(enumerate);

  udev_list_entry* devices = udev_enumerate_get_list_entry(enumerate);
  udev_list_entry* entry = nullptr;
  udev_list_entry_foreach(entry, devices) {
    const char* path = udev_list_entry_get_name(entry);
    if (path == nullptr) continue;

    udev_device* device = udev_device_new_from_syspath(context, path);
    if (device == nullptr) continue;

    const std::string vendor_id =
        ValueOrEmpty(udev_device_get_sysattr_value(device, "idVendor"));
    const std::string product_id =
        ValueOrEmpty(udev_device_get_sysattr_value(device, "idProduct"));
    const int score = CandidateScore(device, vendor_id, product_id);
    if (score > best_score) {
      best_score = score;
      best.detected = true;
      best.accessory_mode = IsAccessoryMode(vendor_id, product_id);
      best.device_name = DeviceName(device);
      best.vendor_id = Lowercase(vendor_id);
      best.product_id = Lowercase(product_id);
    }
    udev_device_unref(device);
  }

  udev_enumerate_unref(enumerate);
  udev_unref(context);
  return best;
}
