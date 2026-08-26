#ifndef MULTIMEDIA_VEHICLE_3D_PLUGIN_H_
#define MULTIMEDIA_VEHICLE_3D_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

void vehicle_3d_plugin_set_overlay(GtkWidget* fixed_overlay);
void vehicle_3d_plugin_register_with_registrar(FlPluginRegistrar* registrar);

#endif  // MULTIMEDIA_VEHICLE_3D_PLUGIN_H_
