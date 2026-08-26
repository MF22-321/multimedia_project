cmake_minimum_required(VERSION 3.13)

add_library(vehicle_3d_plugin STATIC
  "vehicle_3d_plugin.cc"
  "vehicle_3d_gl_area.cc"
  "vehicle_3d_texture.cc"
)

apply_standard_settings(vehicle_3d_plugin)
target_compile_features(vehicle_3d_plugin PRIVATE cxx_std_17)
target_include_directories(vehicle_3d_plugin PUBLIC "${CMAKE_SOURCE_DIR}")
pkg_check_modules(EPOXY REQUIRED IMPORTED_TARGET epoxy)
target_link_libraries(vehicle_3d_plugin PRIVATE
  flutter
  PkgConfig::EPOXY
)
