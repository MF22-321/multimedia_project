#include "projection_plugin/projection_bridge.h"

#include <dlfcn.h>

#include <algorithm>
#include <cstdlib>

namespace {

bool IsTruthyEnvironmentValue(const char* value) {
  if (value == nullptr) return false;
  const std::string normalized(value);
  return normalized != "0" && normalized != "false" && normalized != "FALSE";
}

template <typename T>
T LoadSymbol(void* handle, const char* name) {
  return reinterpret_cast<T>(dlsym(handle, name));
}

bool IsKnownTarget(const std::string& target) {
  return target == "android_auto" || target == "carplay";
}

}  // namespace

ProjectionBridge::ProjectionBridge(void* flutter_texture_registrar)
    : flutter_texture_registrar_(flutter_texture_registrar) {}

ProjectionBridge::~ProjectionBridge() {
  std::lock_guard<std::mutex> lock(mutex_);
  embedded_receiver_.reset();
  if (shutdown_fn_ != nullptr) shutdown_fn_();
  if (library_handle_ != nullptr) dlclose(library_handle_);
}

ProjectionStatusSnapshot ProjectionBridge::Initialize() {
  std::lock_guard<std::mutex> lock(mutex_);
  if (initialized_) {
    RefreshLocked();
    return SnapshotLocked();
  }

  initialized_ = true;
  RefreshUsbLocked();
  status_.sdk_available = LoadSdk();
  if (!status_.sdk_available) {
    embedded_receiver_ = std::make_unique<WiredAndroidAutoReceiver>(
        static_cast<FlTextureRegistrar*>(flutter_texture_registrar_));
    using_embedded_receiver_ = embedded_receiver_->IsAvailable();
    status_.sdk_available = using_embedded_receiver_;
  }
  status_.simulation = !status_.sdk_available &&
                       !IsTruthyEnvironmentValue(std::getenv(
                           "PROJECTION_DISABLE_SIMULATOR"));

  if (using_embedded_receiver_) {
    status_.state = "idle";
    status_.texture_id = embedded_receiver_->GetStatus().texture_id;
    status_.message = "Receiver Android Auto kabel siap";
  } else if (status_.sdk_available) {
    if (initialize_fn_(flutter_texture_registrar_) != 0) {
      return ErrorLocked("Receiver SDK failed to initialize");
    }
    status_.state = "idle";
    status_.message = "Native receiver SDK ready";
  } else if (status_.simulation) {
    status_.state = "idle";
    status_.message = status_.usb_phone_detected
                          ? "USB phone detected; receiver SDK is still required"
                          : "Connect an Android phone by USB; simulator is available";
  } else {
    status_.state = "error";
    if (status_.message.empty()) {
      status_.message =
          "Receiver SDK is unavailable and simulator is disabled";
    }
  }
  return SnapshotLocked();
}

ProjectionStatusSnapshot ProjectionBridge::Start(const std::string& target,
                                                 const std::string& transport) {
  std::lock_guard<std::mutex> lock(mutex_);
  if (!initialized_) {
    return ErrorLocked("Projection bridge must be initialized first");
  }
  if (!IsKnownTarget(target)) {
    return ErrorLocked("Unsupported projection target: " + target);
  }
  const std::string selected_transport =
      transport == "wireless" ? "wireless" : "wired_usb";
  if (target != "android_auto" && selected_transport == "wireless") {
    return ErrorLocked("Wireless transport is currently available for Android Auto only");
  }

  status_.target = target;
  status_.transport = selected_transport;
  status_.texture_id = -1;
  RefreshUsbLocked();
  if (using_embedded_receiver_) {
    if (target != "android_auto") {
      return ErrorLocked("Receiver internal hanya mendukung Android Auto");
    }
    const bool wireless = selected_transport == "wireless";
    if (!embedded_receiver_->Start(wireless)) {
      const WiredReceiverStatus receiver_status = embedded_receiver_->GetStatus();
      return ErrorLocked(receiver_status.message.empty()
                             ? "Receiver Android Auto gagal dijalankan"
                             : receiver_status.message);
    }
    status_.state = "connecting";
    status_.texture_id = embedded_receiver_->GetStatus().texture_id;
    status_.message = wireless
                          ? "Menunggu pairing Bluetooth Android Auto wireless"
                          : "Menunggu handshake Android Auto dari ponsel";
  } else if (status_.sdk_available) {
    if (start_fn_(target.c_str()) != 0) {
      return ErrorLocked("Receiver SDK could not start " + target);
    }
    status_.state = "connecting";
    status_.message = "Waiting for phone receiver session";
  } else if (status_.simulation) {
    status_.state = "connecting";
    status_.message = status_.usb_phone_detected
                          ? "USB phone detected; starting UI simulator only"
                          : "Starting projection simulator (no USB phone detected)";
    transition_started_ = std::chrono::steady_clock::now();
  } else {
    return ErrorLocked("No native receiver SDK is installed");
  }

  return SnapshotLocked();
}

ProjectionStatusSnapshot ProjectionBridge::Disconnect() {
  std::lock_guard<std::mutex> lock(mutex_);
  if (using_embedded_receiver_) {
    embedded_receiver_->Disconnect();
  } else if (status_.sdk_available &&
      !RunCommandLocked(disconnect_fn_, "Receiver disconnect failed")) {
    return SnapshotLocked();
  }
  status_.state = "disconnected";
  status_.target.clear();
  status_.transport = "wired_usb";
  status_.texture_id = -1;
  status_.message = "Phone projection disconnected";
  return SnapshotLocked();
}

ProjectionStatusSnapshot ProjectionBridge::Suspend() {
  std::lock_guard<std::mutex> lock(mutex_);
  if (status_.state != "active") return SnapshotLocked();
  if (using_embedded_receiver_) {
    embedded_receiver_->Suspend();
  } else if (status_.sdk_available &&
      !RunCommandLocked(suspend_fn_, "Receiver suspend failed")) {
    return SnapshotLocked();
  }
  status_.state = "suspended";
  status_.message = "Projection surface suspended; session retained";
  return SnapshotLocked();
}

ProjectionStatusSnapshot ProjectionBridge::Resume() {
  std::lock_guard<std::mutex> lock(mutex_);
  if (status_.state != "suspended") return SnapshotLocked();
  if (using_embedded_receiver_) {
    embedded_receiver_->Resume();
  } else if (status_.sdk_available &&
      !RunCommandLocked(resume_fn_, "Receiver resume failed")) {
    return SnapshotLocked();
  }
  status_.state = "active";
  status_.message = status_.simulation
                        ? "Projection simulator resumed"
                        : "Phone projection resumed";
  return SnapshotLocked();
}

ProjectionStatusSnapshot ProjectionBridge::GetStatus() {
  std::lock_guard<std::mutex> lock(mutex_);
  RefreshLocked();
  return SnapshotLocked();
}

bool ProjectionBridge::SendTouch(double x,
                                 double y,
                                 const std::string& action) {
  std::lock_guard<std::mutex> lock(mutex_);
  if (using_embedded_receiver_) {
    if (status_.state != "active") return false;
    return embedded_receiver_->SendTouch(x, y, action);
  }
  if (!status_.sdk_available || send_touch_fn_ == nullptr ||
      status_.state != "active") {
    return false;
  }

  int native_action = -1;
  if (action == "down") native_action = 0;
  if (action == "move") native_action = 1;
  if (action == "up") native_action = 2;
  if (native_action < 0) return false;

  return send_touch_fn_(std::max(0.0, std::min(1.0, x)),
                        std::max(0.0, std::min(1.0, y)), native_action) == 0;
}

bool ProjectionBridge::LoadSdk() {
  const char* library_path = std::getenv("PROJECTION_SDK_LIBRARY");
  if (library_path == nullptr || library_path[0] == '\0') {
    status_.message = "PROJECTION_SDK_LIBRARY is not configured";
    return false;
  }

  library_handle_ = dlopen(library_path, RTLD_NOW | RTLD_LOCAL);
  if (library_handle_ == nullptr) {
    const char* error = dlerror();
    status_.message = error == nullptr ? "Unable to load receiver SDK" : error;
    return false;
  }

  initialize_fn_ = LoadSymbol<InitializeFn>(
      library_handle_, "multimedia_projection_initialize");
  start_fn_ =
      LoadSymbol<StartFn>(library_handle_, "multimedia_projection_start");
  disconnect_fn_ = LoadSymbol<CommandFn>(
      library_handle_, "multimedia_projection_disconnect");
  suspend_fn_ = LoadSymbol<CommandFn>(
      library_handle_, "multimedia_projection_suspend");
  resume_fn_ = LoadSymbol<CommandFn>(
      library_handle_, "multimedia_projection_resume");
  get_state_fn_ = LoadSymbol<GetStateFn>(
      library_handle_, "multimedia_projection_get_state");
  get_texture_id_fn_ = LoadSymbol<GetTextureIdFn>(
      library_handle_, "multimedia_projection_get_texture_id");
  get_message_fn_ = LoadSymbol<GetMessageFn>(
      library_handle_, "multimedia_projection_get_message");
  send_touch_fn_ = LoadSymbol<SendTouchFn>(
      library_handle_, "multimedia_projection_send_touch");
  shutdown_fn_ = LoadSymbol<ShutdownFn>(
      library_handle_, "multimedia_projection_shutdown");

  const bool complete = initialize_fn_ != nullptr && start_fn_ != nullptr &&
                        disconnect_fn_ != nullptr && suspend_fn_ != nullptr &&
                        resume_fn_ != nullptr && get_state_fn_ != nullptr &&
                        get_texture_id_fn_ != nullptr &&
                        send_touch_fn_ != nullptr && shutdown_fn_ != nullptr;
  if (!complete) {
    status_.message = "Receiver adapter does not implement the complete ABI";
    dlclose(library_handle_);
    library_handle_ = nullptr;
    initialize_fn_ = nullptr;
    start_fn_ = nullptr;
    disconnect_fn_ = nullptr;
    suspend_fn_ = nullptr;
    resume_fn_ = nullptr;
    get_state_fn_ = nullptr;
    get_texture_id_fn_ = nullptr;
    get_message_fn_ = nullptr;
    send_touch_fn_ = nullptr;
    shutdown_fn_ = nullptr;
    return false;
  }
  return true;
}

void ProjectionBridge::RefreshLocked() {
  RefreshUsbLocked();
  if (using_embedded_receiver_) {
    const WiredReceiverStatus receiver_status = embedded_receiver_->GetStatus();
    status_.state = receiver_status.state;
    status_.texture_id = receiver_status.texture_id;
    status_.message = receiver_status.message;
    return;
  }
  if (status_.sdk_available) {
    const char* state = get_state_fn_();
    if (state != nullptr && state[0] != '\0') status_.state = state;
    status_.texture_id = get_texture_id_fn_();
    if (get_message_fn_ != nullptr) {
      const char* message = get_message_fn_();
      if (message != nullptr) status_.message = message;
    }
    return;
  }

  if (status_.simulation && status_.state == "connecting") {
    const auto elapsed = std::chrono::steady_clock::now() - transition_started_;
    if (elapsed >= std::chrono::milliseconds(850)) {
      status_.state = "active";
      status_.message =
          "Simulator active; install receiver SDK for real phone projection";
    }
  }
}

void ProjectionBridge::RefreshUsbLocked() {
  const UsbPhoneStatus usb_status = usb_monitor_.Scan();
  status_.usb_phone_detected = usb_status.detected;
  status_.usb_accessory_mode = usb_status.accessory_mode;
  status_.usb_device_name = usb_status.device_name;
  status_.usb_vendor_id = usb_status.vendor_id;
  status_.usb_product_id = usb_status.product_id;
}

ProjectionStatusSnapshot ProjectionBridge::SnapshotLocked() const {
  return status_;
}

ProjectionStatusSnapshot ProjectionBridge::ErrorLocked(
    const std::string& message) {
  status_.state = "error";
  status_.texture_id = -1;
  status_.message = message;
  return SnapshotLocked();
}

bool ProjectionBridge::RunCommandLocked(CommandFn command,
                                        const char* failure_message) {
  if (command == nullptr || command() != 0) {
    ErrorLocked(failure_message);
    return false;
  }
  return true;
}
