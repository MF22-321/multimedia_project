#include "projection_plugin/projection_texture.h"

#include <algorithm>
#include <atomic>
#include <mutex>
#include <vector>

namespace {

struct TextureStorage {
  std::mutex mutex;
  std::vector<uint8_t> latest;
  std::vector<uint8_t> render;
  uint32_t width = 2;
  uint32_t height = 2;
  FlTextureRegistrar* registrar = nullptr;
  std::atomic<bool> notification_pending{false};
};

}  // namespace

struct _ProjectionTexture {
  FlPixelBufferTexture parent_instance;
  TextureStorage* storage;
};

namespace {

struct FrameNotification {
  ProjectionTexture* texture;
};

gboolean NotifyFlutter(gpointer user_data) {
  auto* notification = static_cast<FrameNotification*>(user_data);
  auto* texture = notification->texture;
  auto* storage = texture->storage;
  storage->notification_pending.store(false);
  fl_texture_registrar_mark_texture_frame_available(
      storage->registrar, FL_TEXTURE(texture));
  g_object_unref(texture);
  delete notification;
  return G_SOURCE_REMOVE;
}

}  // namespace

G_DEFINE_TYPE(ProjectionTexture,
              projection_texture,
              fl_pixel_buffer_texture_get_type())

static gboolean projection_texture_copy_pixels(FlPixelBufferTexture* texture,
                                                const uint8_t** out_buffer,
                                                uint32_t* width,
                                                uint32_t* height,
                                                GError** error) {
  auto* self = PROJECTION_TEXTURE(texture);
  std::lock_guard<std::mutex> lock(self->storage->mutex);
  // Keep the buffer returned to Flutter stable while the decoder writes into
  // the other vector. Swapping avoids a second 1280x720 RGBA memcpy on every
  // frame (roughly 110 MiB/s at 30 fps).
  self->storage->render.swap(self->storage->latest);
  *out_buffer = self->storage->render.data();
  *width = self->storage->width;
  *height = self->storage->height;
  return TRUE;
}

static void projection_texture_dispose(GObject* object) {
  auto* self = PROJECTION_TEXTURE(object);
  if (self->storage != nullptr) {
    if (self->storage->registrar != nullptr) {
      g_object_unref(self->storage->registrar);
      self->storage->registrar = nullptr;
    }
    delete self->storage;
    self->storage = nullptr;
  }
  G_OBJECT_CLASS(projection_texture_parent_class)->dispose(object);
}

static void projection_texture_class_init(ProjectionTextureClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = projection_texture_dispose;
  FL_PIXEL_BUFFER_TEXTURE_CLASS(klass)->copy_pixels =
      projection_texture_copy_pixels;
}

static void projection_texture_init(ProjectionTexture* self) {
  self->storage = new TextureStorage();
  self->storage->latest.assign(2 * 2 * 4, 0);
  self->storage->render = self->storage->latest;
}

ProjectionTexture* projection_texture_new(FlTextureRegistrar* registrar) {
  auto* self = PROJECTION_TEXTURE(
      g_object_new(projection_texture_get_type(), nullptr));
  self->storage->registrar = FL_TEXTURE_REGISTRAR(g_object_ref(registrar));
  return self;
}

void projection_texture_update(ProjectionTexture* self,
                               const uint8_t* rgba,
                               uint32_t width,
                               uint32_t height,
                               size_t stride) {
  g_return_if_fail(PROJECTION_IS_TEXTURE(self));
  if (rgba == nullptr || width == 0 || height == 0) return;

  {
    std::lock_guard<std::mutex> lock(self->storage->mutex);
    self->storage->width = width;
    self->storage->height = height;
    self->storage->latest.resize(static_cast<size_t>(width) * height * 4);
    const size_t row_size = static_cast<size_t>(width) * 4;
    for (uint32_t row = 0; row < height; ++row) {
      std::copy(rgba + static_cast<size_t>(row) * stride,
                rgba + static_cast<size_t>(row) * stride + row_size,
                self->storage->latest.begin() +
                    static_cast<size_t>(row) * row_size);
    }
  }

  bool expected = false;
  if (self->storage->notification_pending.compare_exchange_strong(expected,
                                                                  true)) {
    auto* notification = new FrameNotification{
        PROJECTION_TEXTURE(g_object_ref(self))};
    g_main_context_invoke(nullptr, NotifyFlutter, notification);
  }
}
