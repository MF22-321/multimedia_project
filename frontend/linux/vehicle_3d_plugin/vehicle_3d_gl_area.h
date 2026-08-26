#ifndef MULTIMEDIA_VEHICLE_3D_GL_AREA_H_
#define MULTIMEDIA_VEHICLE_3D_GL_AREA_H_

#include <gtk/gtk.h>

struct Vehicle3DGlArea;
using Vehicle3DTapCallback = void (*)(double x, double y, void* user_data);

Vehicle3DGlArea* vehicle_3d_gl_area_new(GtkWidget* fixed_overlay);
void vehicle_3d_gl_area_destroy(Vehicle3DGlArea* view);
bool vehicle_3d_gl_area_initialize(Vehicle3DGlArea* view);
void vehicle_3d_gl_area_set_bounds(Vehicle3DGlArea* view, int x, int y,
                                   int width, int height);
void vehicle_3d_gl_area_set_visible(Vehicle3DGlArea* view, bool visible);
void vehicle_3d_gl_area_set_transform(Vehicle3DGlArea* view, float yaw,
                                      float pitch, float zoom);
void vehicle_3d_gl_area_set_interacting(Vehicle3DGlArea* view,
                                        bool interacting);
void vehicle_3d_gl_area_set_focus(Vehicle3DGlArea* view, float x, float y);
void vehicle_3d_gl_area_set_tap_callback(Vehicle3DGlArea* view,
                                         Vehicle3DTapCallback callback,
                                         void* user_data);
void vehicle_3d_gl_area_reset(Vehicle3DGlArea* view);

#endif
