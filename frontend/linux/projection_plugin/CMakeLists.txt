cmake_minimum_required(VERSION 3.13)

add_library(projection_plugin STATIC
  "projection_bridge.cc"
  "projection_plugin.cc"
  "projection_texture.cc"
  "usb_device_monitor.cc"
  "wired_android_auto_receiver.cc"
)

apply_standard_settings(projection_plugin)
target_include_directories(projection_plugin PUBLIC "${CMAKE_SOURCE_DIR}")
pkg_check_modules(UDEV REQUIRED IMPORTED_TARGET libudev)
pkg_check_modules(GSTREAMER REQUIRED IMPORTED_TARGET
  gstreamer-1.0
  gstreamer-app-1.0
  gstreamer-video-1.0
)
target_link_libraries(projection_plugin PRIVATE
  flutter
  ${CMAKE_DL_LIBS}
  PkgConfig::UDEV
  PkgConfig::GSTREAMER
)
