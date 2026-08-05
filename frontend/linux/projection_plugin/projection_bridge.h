#ifndef MULTIMEDIA_PROJECTION_BRIDGE_H_
#define MULTIMEDIA_PROJECTION_BRIDGE_H_

#include <chrono>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>

#include "projection_plugin/usb_device_monitor.h"
#include "projection_plugin/wired_android_auto_receiver.h"

struct ProjectionStatusSnapshot {
  std::string state = "idle";
  std::string target;
  std::string transport = "wired_usb";
  int64_t texture_id = -1;
  bool sdk_available = false;
  bool simulation = false;
  bool usb_phone_detected = false;
  bool usb_accessory_mode = false;
  std::string usb_device_name;
  std::string usb_vendor_id;
  std::string usb_product_id;
  std::string message;
};

class ProjectionBridge {
 public:
  explicit ProjectionBridge(void* flutter_texture_registrar);
  ~ProjectionBridge();

  ProjectionBridge(const ProjectionBridge&) = delete;
  ProjectionBridge& operator=(const ProjectionBridge&) = delete;

  ProjectionStatusSnapshot Initialize();
  ProjectionStatusSnapshot Start(const std::string& target,
                                 const std::string& transport);
  ProjectionStatusSnapshot Disconnect();
  ProjectionStatusSnapshot Suspend();
  ProjectionStatusSnapshot Resume();
  ProjectionStatusSnapshot GetStatus();
  bool SendTouch(double x, double y, const std::string& action);

 private:
  using InitializeFn = int (*)(void*);
  using StartFn = int (*)(const char*);
  using CommandFn = int (*)();
  using GetStateFn = const char* (*)();
  using GetTextureIdFn = int64_t (*)();
  using GetMessageFn = const char* (*)();
  using SendTouchFn = int (*)(double, double, int);
  using ShutdownFn = void (*)();

  bool LoadSdk();
  void RefreshLocked();
  void RefreshUsbLocked();
  ProjectionStatusSnapshot SnapshotLocked() const;
  ProjectionStatusSnapshot ErrorLocked(const std::string& message);
  bool RunCommandLocked(CommandFn command, const char* failure_message);

  void* flutter_texture_registrar_ = nullptr;
  void* library_handle_ = nullptr;
  InitializeFn initialize_fn_ = nullptr;
  StartFn start_fn_ = nullptr;
  CommandFn disconnect_fn_ = nullptr;
  CommandFn suspend_fn_ = nullptr;
  CommandFn resume_fn_ = nullptr;
  GetStateFn get_state_fn_ = nullptr;
  GetTextureIdFn get_texture_id_fn_ = nullptr;
  GetMessageFn get_message_fn_ = nullptr;
  SendTouchFn send_touch_fn_ = nullptr;
  ShutdownFn shutdown_fn_ = nullptr;
  std::unique_ptr<WiredAndroidAutoReceiver> embedded_receiver_;
  bool using_embedded_receiver_ = false;

  mutable std::mutex mutex_;
  ProjectionStatusSnapshot status_;
  UsbDeviceMonitor usb_monitor_;
  bool initialized_ = false;
  std::chrono::steady_clock::time_point transition_started_;
};

#endif  // MULTIMEDIA_PROJECTION_BRIDGE_H_
