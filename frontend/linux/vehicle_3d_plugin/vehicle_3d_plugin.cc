#include "vehicle_3d_plugin/vehicle_3d_plugin.h"

#include <cstring>

#include "vehicle_3d_plugin/vehicle_3d_gl_area.h"
#include "vehicle_3d_plugin/vehicle_3d_texture.h"

namespace {

constexpr char kChannelName[] = "com.multimedia.vehicle3d/control";
GtkWidget* g_vehicle_overlay = nullptr;

struct Vehicle3DPluginState {
  FlTextureRegistrar* registrar = nullptr;
  FlBinaryMessenger* messenger = nullptr;
  // Non-owning: the messenger retains the registered method channel for as
  // long as its handler is installed. Reuse it for native -> Dart tap events;
  // creating another channel with the same name replaces and then removes the
  // control handler when that temporary channel is destroyed.
  FlMethodChannel* channel = nullptr;
  Vehicle3DTexture* texture = nullptr;
  guint timer_id = 0;
  FlView* view = nullptr;
  gulong view_destroy_handler_id = 0;
  bool texture_registered = false;
  Vehicle3DGlArea* direct_view = nullptr;
};

void OnVehicleTapped(double x, double y, void* user_data) {
  auto* state = static_cast<Vehicle3DPluginState*>(user_data);
  if (state == nullptr || state->channel == nullptr) return;
  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_string_take(args, "x", fl_value_new_float(x));
  fl_value_set_string_take(args, "y", fl_value_new_float(y));
  fl_method_channel_invoke_method(state->channel, "vehicleTapped", args,
                                  nullptr, nullptr, nullptr);
}

void StopRendering(Vehicle3DPluginState* state) {
  if (state->timer_id != 0) {
    g_source_remove(state->timer_id);
    state->timer_id = 0;
  }
  if (state->texture != nullptr) {
    vehicle_3d_texture_set_active(state->texture, false);
  }
  if (state->texture_registered) {
    fl_texture_registrar_unregister_texture(state->registrar,
                                            FL_TEXTURE(state->texture));
    state->texture_registered = false;
  }
}

void OnViewDestroyed(GtkWidget*, gpointer user_data) {
  auto* state = static_cast<Vehicle3DPluginState*>(user_data);
  // GtkWidget::destroy is emitted before FlView releases its engine and GL
  // context. Stop the 30 FPS source here so it cannot request another frame
  // from a texture registrar whose engine is already being torn down.
  state->view = nullptr;
  state->view_destroy_handler_id = 0;
  vehicle_3d_gl_area_set_visible(state->direct_view, false);
  StopRendering(state);
}

double GetNumber(FlValue* args, const char* key, double fallback) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return fallback;
  }
  FlValue* value = fl_value_lookup_string(args, key);
  if (value == nullptr) return fallback;
  if (fl_value_get_type(value) == FL_VALUE_TYPE_FLOAT) {
    return fl_value_get_float(value);
  }
  if (fl_value_get_type(value) == FL_VALUE_TYPE_INT) {
    return static_cast<double>(fl_value_get_int(value));
  }
  return fallback;
}

bool GetBool(FlValue* args, const char* key, bool fallback) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return fallback;
  }
  FlValue* value = fl_value_lookup_string(args, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_BOOL) {
    return fallback;
  }
  return fl_value_get_bool(value);
}

void Respond(FlMethodCall* call, FlValue* result) {
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_success(call, result, &error)) {
    g_warning("Vehicle 3D response failed: %s", error->message);
  }
}

FlValue* StatusValue(const Vehicle3DPluginState* state) {
  FlValue* result = fl_value_new_map();
  fl_value_set_string_take(result, "available", fl_value_new_bool(true));
  fl_value_set_string_take(
      result, "textureId",
      fl_value_new_int(fl_texture_get_id(FL_TEXTURE(state->texture))));
  fl_value_set_string_take(result, "renderer",
                           fl_value_new_string("native_opengl"));
  fl_value_set_string_take(
      result, "model",
      fl_value_new_string("procedural_veloz_concept_preview"));
  fl_value_set_string_take(
      result, "message",
      fl_value_new_string("Jetson native GPU vehicle renderer ready"));
  return result;
}

FlValue* DirectStatusValue(const Vehicle3DPluginState* state) {
  FlValue* result = fl_value_new_map();
  const bool available = state->direct_view != nullptr;
  fl_value_set_string_take(result, "available", fl_value_new_bool(available));
  fl_value_set_string_take(result, "renderer",
                           fl_value_new_string("gtk_gl_area_zbuffer"));
  fl_value_set_string_take(result, "model",
                           fl_value_new_string("toyota_veloz_2022_glb_hd"));
  if (!available) {
    fl_value_set_string_take(
        result, "message",
        fl_value_new_string("Native vehicle overlay is unavailable"));
  }
  return result;
}

gboolean Tick(gpointer user_data) {
  auto* state = static_cast<Vehicle3DPluginState*>(user_data);
  if (state->texture != nullptr) {
    vehicle_3d_texture_tick(state->texture, 1.0f / 30.0f);
  }
  return G_SOURCE_CONTINUE;
}

void MethodCallHandler(FlMethodChannel* channel,
                       FlMethodCall* method_call,
                       gpointer user_data) {
  auto* state = static_cast<Vehicle3DPluginState*>(user_data);
  const char* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (std::strcmp(method, "initialize") == 0 ||
      std::strcmp(method, "getStatus") == 0) {
    if (std::strcmp(method, "initialize") == 0) {
      if (state->timer_id == 0) {
        // The legacy external texture is opt-in. Do not wake the GTK main
        // loop every 33 ms while Home is using the direct GtkGLArea.
        state->timer_id = g_timeout_add(33, Tick, state);
      }
      vehicle_3d_texture_set_size(
          state->texture,
          static_cast<uint32_t>(GetNumber(args, "width", 960)),
          static_cast<uint32_t>(GetNumber(args, "height", 540)));
      vehicle_3d_texture_set_auto_rotate(
          state->texture, GetBool(args, "autoRotate", false));
      vehicle_3d_texture_set_active(state->texture, true);
      vehicle_3d_texture_render_frame(state->texture);
    }
    g_autoptr(FlValue) result = StatusValue(state);
    Respond(method_call, result);
    return;
  }
  if (std::strcmp(method, "initializeDirectView") == 0) {
    if (state->direct_view == nullptr && g_vehicle_overlay != nullptr) {
      state->direct_view = vehicle_3d_gl_area_new(g_vehicle_overlay);
      vehicle_3d_gl_area_set_tap_callback(state->direct_view, OnVehicleTapped,
                                          state);
    }
    const bool ready = vehicle_3d_gl_area_initialize(state->direct_view);
    g_autoptr(FlValue) result = DirectStatusValue(state);
    if (!ready) {
      fl_value_set_string_take(result, "available", fl_value_new_bool(false));
    }
    Respond(method_call, result);
    return;
  }
  if (std::strcmp(method, "setDirectViewBounds") == 0) {
    vehicle_3d_gl_area_set_bounds(
        state->direct_view, static_cast<int>(GetNumber(args, "x", 0)),
        static_cast<int>(GetNumber(args, "y", 0)),
        static_cast<int>(GetNumber(args, "width", 640)),
        static_cast<int>(GetNumber(args, "height", 360)));
    g_autoptr(FlValue) result = fl_value_new_bool(true);
    Respond(method_call, result);
    return;
  }
  if (std::strcmp(method, "setDirectViewVisible") == 0) {
    vehicle_3d_gl_area_set_visible(state->direct_view,
                                   GetBool(args, "visible", true));
    g_autoptr(FlValue) result = fl_value_new_bool(true);
    Respond(method_call, result);
    return;
  }
  if (std::strcmp(method, "setTransform") == 0) {
    vehicle_3d_texture_set_transform(
        state->texture, static_cast<float>(GetNumber(args, "yaw", -0.38)),
        static_cast<float>(GetNumber(args, "pitch", 0.08)),
        static_cast<float>(GetNumber(args, "zoom", 1.0)));
    vehicle_3d_gl_area_set_transform(
        state->direct_view, static_cast<float>(GetNumber(args, "yaw", -0.38)),
        static_cast<float>(GetNumber(args, "pitch", 0.08)),
        static_cast<float>(GetNumber(args, "zoom", 1.0)));
    g_autoptr(FlValue) result = fl_value_new_bool(true);
    Respond(method_call, result);
    return;
  }
  if (std::strcmp(method, "setViewTransform") == 0) {
    vehicle_3d_gl_area_set_transform(
        state->direct_view, static_cast<float>(GetNumber(args, "yaw", -0.38)),
        static_cast<float>(GetNumber(args, "pitch", 0.08)),
        static_cast<float>(GetNumber(args, "zoom", 1.16)));
    vehicle_3d_gl_area_set_focus(
        state->direct_view,
        static_cast<float>(GetNumber(args, "focusX", 0)),
        static_cast<float>(GetNumber(args, "focusY", 0)));
    g_autoptr(FlValue) result = fl_value_new_bool(true);
    Respond(method_call, result);
    return;
  }
  if (std::strcmp(method, "setInteractionActive") == 0) {
    vehicle_3d_gl_area_set_interacting(
        state->direct_view, GetBool(args, "active", false));
    g_autoptr(FlValue) result = fl_value_new_bool(true);
    Respond(method_call, result);
    return;
  }
  if (std::strcmp(method, "setAutoRotate") == 0) {
      vehicle_3d_texture_set_auto_rotate(
        state->texture, GetBool(args, "enabled", false));
    g_autoptr(FlValue) result = fl_value_new_bool(true);
    Respond(method_call, result);
    return;
  }
  if (std::strcmp(method, "setActive") == 0) {
    vehicle_3d_texture_set_active(state->texture,
                                  GetBool(args, "active", true));
    g_autoptr(FlValue) result = fl_value_new_bool(true);
    Respond(method_call, result);
    return;
  }
  if (std::strcmp(method, "reset") == 0) {
    vehicle_3d_texture_reset(state->texture);
    vehicle_3d_gl_area_reset(state->direct_view);
    g_autoptr(FlValue) result = fl_value_new_bool(true);
    Respond(method_call, result);
    return;
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_not_implemented(method_call, &error)) {
    g_warning("Vehicle 3D not-implemented response failed: %s", error->message);
  }
}

void DestroyPluginState(gpointer user_data) {
  auto* state = static_cast<Vehicle3DPluginState*>(user_data);
  state->channel = nullptr;
  if (state->view != nullptr && state->view_destroy_handler_id != 0) {
    g_signal_handler_disconnect(state->view, state->view_destroy_handler_id);
  }
  StopRendering(state);
  if (state->texture != nullptr) {
    g_object_unref(state->texture);
  }
  vehicle_3d_gl_area_destroy(state->direct_view);
  g_clear_object(&state->messenger);
  g_clear_object(&state->registrar);
  delete state;
}

}  // namespace

void vehicle_3d_plugin_set_overlay(GtkWidget* fixed_overlay) {
  g_vehicle_overlay = fixed_overlay;
}

void vehicle_3d_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  auto* state = new Vehicle3DPluginState();
  state->messenger = fl_plugin_registrar_get_messenger(registrar);
  g_object_ref(state->messenger);
  state->registrar = FL_TEXTURE_REGISTRAR(
      g_object_ref(fl_plugin_registrar_get_texture_registrar(registrar)));
  state->view = fl_plugin_registrar_get_view(registrar);
  state->texture = vehicle_3d_texture_new(state->registrar, state->view);
  // GtkGLArea is intentionally created lazily by initializeDirectView. Merely
  // mapping an unused alpha GL child can replace Flutter's complete frame with
  // black on Jetson/NVIDIA. Home and Vehicle Analysis use the stable Flutter
  // Canvas renderer, so they never allocate this native surface.
  state->texture_registered = fl_texture_registrar_register_texture(
      state->registrar, FL_TEXTURE(state->texture));
  if (!state->texture_registered) {
    g_warning("Unable to register native vehicle 3D texture");
  }
  // The external pixel-buffer renderer is retained only as an explicit
  // fallback for other screens. Keep it dormant by default: continuously
  // producing unused external-texture frames caused compositor corruption on
  // Jetson/NVIDIA, while the Home card now uses the direct GtkGLArea.
  vehicle_3d_texture_set_active(state->texture, false);
  if (state->view != nullptr) {
    state->view_destroy_handler_id = g_signal_connect(
        state->view, "destroy", G_CALLBACK(OnViewDestroyed), state);
  }
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), kChannelName,
      FL_METHOD_CODEC(codec));
  state->channel = channel;
  fl_method_channel_set_method_call_handler(
      channel, MethodCallHandler, state, DestroyPluginState);
}
