#ifndef MULTIMEDIA_WIRED_ANDROID_AUTO_RECEIVER_H_
#define MULTIMEDIA_WIRED_ANDROID_AUTO_RECEIVER_H_

#include <flutter_linux/flutter_linux.h>
#include <gst/app/gstappsink.h>
#include <gst/app/gstappsrc.h>

#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "projection_plugin/projection_texture.h"

struct WiredReceiverStatus {
  std::string state = "idle";
  std::string message;
  int64_t texture_id = -1;
};

class WiredAndroidAutoReceiver {
 public:
  explicit WiredAndroidAutoReceiver(FlTextureRegistrar* registrar);
  ~WiredAndroidAutoReceiver();

  WiredAndroidAutoReceiver(const WiredAndroidAutoReceiver&) = delete;
  WiredAndroidAutoReceiver& operator=(const WiredAndroidAutoReceiver&) = delete;

  bool IsAvailable() const;
  bool Start(bool wireless = false);
  void Disconnect();
  void Suspend();
  void Resume();
  bool SendTouch(double x, double y, const std::string& action);
  WiredReceiverStatus GetStatus() const;

 private:
  struct AudioOutput {
    GstElement* pipeline = nullptr;
    GstAppSrc* appsrc = nullptr;
    GstElement* startup_queue = nullptr;
    uint32_t sample_rate = 0;
    uint8_t channels = 0;
    uint64_t frame_count = 0;
    uint64_t diagnostic_bytes = 0;
    uint16_t diagnostic_peak = 0;
    int64_t diagnostic_started_us = 0;
  };

  static GstFlowReturn OnNewSample(GstAppSink* sink, gpointer user_data);

  bool LaunchService();
  bool ConnectToService();
  bool InitializeDecoder();
  void DestroyDecoder();
  bool InitializeAudio();
  bool CreateAudioPipeline(const char* source_name,
                           uint32_t sample_rate,
                           uint8_t channels,
                           AudioOutput* output);
  void DestroyAudio();
  void ReaderLoop();
  void HandleMessage(uint8_t type, const std::vector<uint8_t>& payload);
  void PushVideo(const std::vector<uint8_t>& payload);
  void PushAudio(const std::vector<uint8_t>& payload);
  bool SendMessage(uint8_t type, const std::string& payload);
  bool SendMessage(uint8_t type, const uint8_t* payload, size_t length);
  void SetStatus(const std::string& state, const std::string& message);
  std::string LocateServiceScript() const;

  FlTextureRegistrar* registrar_ = nullptr;
  ProjectionTexture* texture_ = nullptr;
  GSubprocess* service_process_ = nullptr;
  int socket_fd_ = -1;
  std::atomic<bool> reader_running_{false};
  std::thread reader_thread_;
  mutable std::mutex status_mutex_;
  std::mutex send_mutex_;
  WiredReceiverStatus status_;
  bool suspended_ = false;

  GstElement* pipeline_ = nullptr;
  GstAppSrc* appsrc_ = nullptr;
  GstAppSink* appsink_ = nullptr;
  uint64_t frame_number_ = 0;
  std::atomic<uint64_t> decoded_frame_count_{0};
  int64_t fps_window_started_us_ = 0;
  uint64_t fps_window_frames_ = 0;

  AudioOutput media_audio_;
  AudioOutput speech_audio_;
  AudioOutput system_audio_;
  std::atomic<uint64_t> audio_frame_count_{0};
};

#endif  // MULTIMEDIA_WIRED_ANDROID_AUTO_RECEIVER_H_
