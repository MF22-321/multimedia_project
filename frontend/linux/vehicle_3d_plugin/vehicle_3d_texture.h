#ifndef MULTIMEDIA_VEHICLE_3D_TEXTURE_H_
#define MULTIMEDIA_VEHICLE_3D_TEXTURE_H_

#include <flutter_linux/flutter_linux.h>

#include <cstdint>

G_DECLARE_FINAL_TYPE(Vehicle3DTexture,
                     vehicle_3d_texture,
                     VEHICLE_3D,
                     TEXTURE,
                     FlPixelBufferTexture)

Vehicle3DTexture* vehicle_3d_texture_new(FlTextureRegistrar* registrar,
                                        FlView* view);

void vehicle_3d_texture_set_size(Vehicle3DTexture* self,
                                 uint32_t width,
                                 uint32_t height);
void vehicle_3d_texture_set_transform(Vehicle3DTexture* self,
                                      float yaw,
                                      float pitch,
                                      float zoom);
void vehicle_3d_texture_set_auto_rotate(Vehicle3DTexture* self, bool enabled);
void vehicle_3d_texture_set_active(Vehicle3DTexture* self, bool active);
void vehicle_3d_texture_reset(Vehicle3DTexture* self);
bool vehicle_3d_texture_render_frame(Vehicle3DTexture* self);
void vehicle_3d_texture_tick(Vehicle3DTexture* self, float delta_seconds);

#endif  // MULTIMEDIA_VEHICLE_3D_TEXTURE_H_
