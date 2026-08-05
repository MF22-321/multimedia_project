#include "projection_plugin/projection_plugin.h"

#include <cstring>
#include <memory>
#include <string>

#include "projection_plugin/projection_bridge.h"

namespace {

constexpr char kChannelName[] = "com.multimedia.projection/control";

struct ProjectionPluginState {
  std::unique_ptr<ProjectionBridge> bridge;
};

FlValue* StatusToValue(const ProjectionStatusSnapshot& status) {
  FlValue* value = fl_value_new_map();
  fl_value_set_string_take(value, "state",
                           fl_value_new_string(status.state.c_str()));
  if (status.target.empty()) {
    fl_value_set_string_take(value, "target", fl_value_new_null());
  } else {
    fl_value_set_string_take(value, "target",
                             fl_value_new_string(status.target.c_str()));
  }
  fl_value_set_string_take(value, "textureId",
                           fl_value_new_int(status.texture_id));
  fl_value_set_string_take(value, "sdkAvailable",
                           fl_value_new_bool(status.sdk_available));
  fl_value_set_string_take(value, "simulation",
                           fl_value_new_bool(status.simulation));
  fl_value_set_string_take(value, "transport",
                           fl_value_new_string(status.transport.c_str()));
  fl_value_set_string_take(value, "usbPhoneDetected",
                           fl_value_new_bool(status.usb_phone_detected));
  fl_value_set_string_take(value, "usbAccessoryMode",
                           fl_value_new_bool(status.usb_accessory_mode));
  fl_value_set_string_take(
      value, "usbDeviceName",
      fl_value_new_string(status.usb_device_name.c_str()));
  fl_value_set_string_take(
      value, "usbVendorId",
      fl_value_new_string(status.usb_vendor_id.c_str()));
  fl_value_set_string_take(
      value, "usbProductId",
      fl_value_new_string(status.usb_product_id.c_str()));
  fl_value_set_string_take(value, "message",
                           fl_value_new_string(status.message.c_str()));
  return value;
}

std::string GetStringArgument(FlValue* args, const char* key) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) return {};
  FlValue* value = fl_value_lookup_string(args, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_STRING) {
    return {};
  }
  return fl_value_get_string(value);
}

double GetDoubleArgument(FlValue* args, const char* key) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) return 0;
  FlValue* value = fl_value_lookup_string(args, key);
  if (value == nullptr) return 0;
  if (fl_value_get_type(value) == FL_VALUE_TYPE_FLOAT) {
    return fl_value_get_float(value);
  }
  if (fl_value_get_type(value) == FL_VALUE_TYPE_INT) {
    return static_cast<double>(fl_value_get_int(value));
  }
  return 0;
}

void RespondWithStatus(FlMethodCall* method_call,
                       const ProjectionStatusSnapshot& status) {
  g_autoptr(FlValue) result = StatusToValue(status);
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_success(method_call, result, &error)) {
    g_warning("Failed to respond on projection channel: %s", error->message);
  }
}

void MethodCallHandler(FlMethodChannel* channel,
                       FlMethodCall* method_call,
                       gpointer user_data) {
  auto* state = static_cast<ProjectionPluginState*>(user_data);
  const char* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (std::strcmp(method, "initialize") == 0) {
    RespondWithStatus(method_call, state->bridge->Initialize());
    return;
  }
  if (std::strcmp(method, "start") == 0) {
    RespondWithStatus(
        method_call,
        state->bridge->Start(GetStringArgument(args, "target"),
                             GetStringArgument(args, "transport")));
    return;
  }
  if (std::strcmp(method, "disconnect") == 0) {
    RespondWithStatus(method_call, state->bridge->Disconnect());
    return;
  }
  if (std::strcmp(method, "suspend") == 0) {
    RespondWithStatus(method_call, state->bridge->Suspend());
    return;
  }
  if (std::strcmp(method, "resume") == 0) {
    RespondWithStatus(method_call, state->bridge->Resume());
    return;
  }
  if (std::strcmp(method, "getStatus") == 0) {
    RespondWithStatus(method_call, state->bridge->GetStatus());
    return;
  }
  if (std::strcmp(method, "sendTouch") == 0) {
    const bool accepted = state->bridge->SendTouch(
        GetDoubleArgument(args, "x"), GetDoubleArgument(args, "y"),
        GetStringArgument(args, "action"));
    g_autoptr(FlValue) result = fl_value_new_bool(accepted);
    g_autoptr(GError) error = nullptr;
    if (!fl_method_call_respond_success(method_call, result, &error)) {
      g_warning("Failed to respond to projection touch: %s", error->message);
    }
    return;
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_not_implemented(method_call, &error)) {
    g_warning("Failed to send projection not-implemented response: %s",
              error->message);
  }
}

void DestroyPluginState(gpointer user_data) {
  delete static_cast<ProjectionPluginState*>(user_data);
}

}  // namespace

void projection_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  auto* state = new ProjectionPluginState();
  state->bridge = std::make_unique<ProjectionBridge>(
      fl_plugin_registrar_get_texture_registrar(registrar));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), kChannelName,
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, MethodCallHandler, state, DestroyPluginState);
}
