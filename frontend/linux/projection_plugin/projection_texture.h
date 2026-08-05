#ifndef MULTIMEDIA_PROJECTION_TEXTURE_H_
#define MULTIMEDIA_PROJECTION_TEXTURE_H_

#include <flutter_linux/flutter_linux.h>

#include <cstddef>
#include <cstdint>

G_DECLARE_FINAL_TYPE(ProjectionTexture,
                     projection_texture,
                     PROJECTION,
                     TEXTURE,
                     FlPixelBufferTexture)

ProjectionTexture* projection_texture_new(FlTextureRegistrar* registrar);

void projection_texture_update(ProjectionTexture* self,
                               const uint8_t* rgba,
                               uint32_t width,
                               uint32_t height,
                               size_t stride);

#endif  // MULTIMEDIA_PROJECTION_TEXTURE_H_
