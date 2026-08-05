#ifndef MULTIMEDIA_USB_DEVICE_MONITOR_H_
#define MULTIMEDIA_USB_DEVICE_MONITOR_H_

#include <string>

struct UsbPhoneStatus {
  bool detected = false;
  bool accessory_mode = false;
  std::string device_name;
  std::string vendor_id;
  std::string product_id;
};

// Performs a read-only scan of Linux udev. The result is intentionally named
// "phone candidate": USB descriptors are sufficient for cable readiness, but
// only the Android Auto receiver can confirm a projection-capable phone.
class UsbDeviceMonitor {
 public:
  UsbPhoneStatus Scan() const;
};

#endif  // MULTIMEDIA_USB_DEVICE_MONITOR_H_
