#include "projection_plugin/wired_android_auto_receiver.h"

#include <arpa/inet.h>
#include <gio/gio.h>
#include <gst/video/video.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

#include <algorithm>
#include <cerrno>
#include <chrono>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <signal.h>
#include <sstream>

namespace {

constexpr uint16_t kReceiverPort = 5281;
constexpr uint8_t kStatusMessage = 1;
constexpr uint8_t kCodecMessage = 2;
constexpr uint8_t kVideoMessage = 3;
constexpr uint8_t kAudioMessage = 4;
constexpr uint8_t kStartCommand = 0x81;
constexpr uint8_t kTouchCommand = 0x82;
constexpr uint8_t kDisconnectCommand = 0x83;
constexpr size_t kMaximumMessageSize = 64 * 1024 * 1024;
constexpr GstClockTime kMediaAudioStartupBuffer = 120 * GST_MSECOND;

bool ReadExact(int fd, uint8_t* data, size_t length) {
  size_t offset = 0;
  while (offset < length) {
    const ssize_t count = recv(fd, data + offset, length - offset, 0);
    if (count == 0) return false;
    if (count < 0) {
      if (errno == EINTR) continue;
      return false;
    }
    offset += static_cast<size_t>(count);
  }
  return true;
}

std::string ExtractJsonString(const std::string& json,
                              const std::string& key) {
  const std::string marker = "\"" + key + "\":\"";
  const size_t start = json.find(marker);
  if (start == std::string::npos) return {};
  size_t cursor = start + marker.size();
  std::string value;
  while (cursor < json.size()) {
    const char current = json[cursor++];
    if (current == '"') break;
    if (current == '\\' && cursor < json.size()) {
      const char escaped = json[cursor++];
      if (escaped == 'n') {
        value.push_back('\n');
      } else {
        value.push_back(escaped);
      }
    } else {
      value.push_back(current);
    }
  }
  return value;
}

void InitializeGStreamerOnce() {
  static std::once_flag once;
  std::call_once(once, []() { gst_init(nullptr, nullptr); });
}

// Release the threshold after the initial jitter buffer is ready. Keeping a
// queue threshold enabled permanently gates the stream after every underrun.
void ReleaseAudioStartupBuffer(GstElement* queue, gpointer) {
  guint64 threshold = 0;
  g_object_get(queue, "min-threshold-time", &threshold, nullptr);
  if (threshold == 0) return;
  g_object_set(queue, "min-threshold-time", static_cast<guint64>(0), nullptr);
  g_message("Android Auto audio startup buffer ready: %.0f ms",
            static_cast<double>(threshold) / GST_MSECOND);
}

}  // namespace

WiredAndroidAutoReceiver::WiredAndroidAutoReceiver(
    FlTextureRegistrar* registrar)
    : registrar_(FL_TEXTURE_REGISTRAR(g_object_ref(registrar))) {
  texture_ = projection_texture_new(registrar_);
  if (fl_texture_registrar_register_texture(registrar_, FL_TEXTURE(texture_))) {
    status_.texture_id = fl_texture_get_id(FL_TEXTURE(texture_));
  } else {
    status_.message = "Flutter gagal mendaftarkan texture Android Auto";
  }
}

WiredAndroidAutoReceiver::~WiredAndroidAutoReceiver() {
  Disconnect();
  DestroyAudio();
  DestroyDecoder();
  if (service_process_ != nullptr) {
    if (!g_subprocess_get_if_exited(service_process_)) {
      g_subprocess_send_signal(service_process_, SIGTERM);
    }
    g_object_unref(service_process_);
    service_process_ = nullptr;
  }
  if (texture_ != nullptr) {
    fl_texture_registrar_unregister_texture(registrar_, FL_TEXTURE(texture_));
    g_object_unref(texture_);
    texture_ = nullptr;
  }
  if (registrar_ != nullptr) {
    g_object_unref(registrar_);
    registrar_ = nullptr;
  }
}

bool WiredAndroidAutoReceiver::IsAvailable() const {
  return !LocateServiceScript().empty() && status_.texture_id >= 0;
}

bool WiredAndroidAutoReceiver::Start(bool wireless) {
  const std::string payload = wireless
                                  ? "{\"transport\":\"wireless\"}"
                                  : "{\"transport\":\"wired\"}";
  if (reader_running_.load()) {
    return SendMessage(kStartCommand, payload);
  }
  SetStatus("connecting", wireless
                              ? "Menjalankan receiver Android Auto wireless"
                              : "Menjalankan receiver Android Auto kabel");
  if (!InitializeDecoder()) return false;
  if (!InitializeAudio()) return false;
  if (!LaunchService() || !ConnectToService()) {
    SetStatus("error", "Receiver lokal tidak dapat dihubungi di 127.0.0.1:5281");
    return false;
  }

  reader_running_.store(true);
  reader_thread_ = std::thread(&WiredAndroidAutoReceiver::ReaderLoop, this);
  if (!SendMessage(kStartCommand, payload)) {
    SetStatus("error", "Perintah start Android Auto gagal dikirim");
    return false;
  }
  return true;
}

void WiredAndroidAutoReceiver::Disconnect() {
  if (socket_fd_ >= 0) SendMessage(kDisconnectCommand, nullptr, 0);
  reader_running_.store(false);
  if (socket_fd_ >= 0) {
    shutdown(socket_fd_, SHUT_RDWR);
    close(socket_fd_);
    socket_fd_ = -1;
  }
  if (reader_thread_.joinable()) reader_thread_.join();
  suspended_ = false;
  SetStatus("disconnected", "Android Auto dihentikan");
}

void WiredAndroidAutoReceiver::Suspend() {
  std::lock_guard<std::mutex> lock(status_mutex_);
  if (status_.state == "active") suspended_ = true;
}

void WiredAndroidAutoReceiver::Resume() {
  std::lock_guard<std::mutex> lock(status_mutex_);
  suspended_ = false;
}

bool WiredAndroidAutoReceiver::SendTouch(double x,
                                         double y,
                                         const std::string& action) {
  const double normalized_x = std::max(0.0, std::min(1.0, x));
  const double normalized_y = std::max(0.0, std::min(1.0, y));
  std::ostringstream json;
  json << "{\"x\":" << normalized_x << ",\"y\":" << normalized_y
       << ",\"action\":\"" << action << "\"}";
  return SendMessage(kTouchCommand, json.str());
}

WiredReceiverStatus WiredAndroidAutoReceiver::GetStatus() const {
  std::lock_guard<std::mutex> lock(status_mutex_);
  WiredReceiverStatus snapshot = status_;
  if (suspended_ && snapshot.state == "active") snapshot.state = "suspended";
  return snapshot;
}

bool WiredAndroidAutoReceiver::LaunchService() {
  if (service_process_ != nullptr && !g_subprocess_get_if_exited(service_process_)) {
    return true;
  }
  if (service_process_ != nullptr) {
    g_object_unref(service_process_);
    service_process_ = nullptr;
  }
  const std::string script = LocateServiceScript();
  if (script.empty()) {
    SetStatus("error", "Receiver belum dipasang; jalankan setup_android_auto_receiver.sh");
    return false;
  }

  g_autoptr(GError) error = nullptr;
  service_process_ = g_subprocess_new(G_SUBPROCESS_FLAGS_NONE, &error,
                                      script.c_str(), nullptr);
  if (service_process_ == nullptr) {
    SetStatus("error", error == nullptr ? "Receiver gagal dijalankan"
                                        : error->message);
    return false;
  }
  return true;
}

bool WiredAndroidAutoReceiver::ConnectToService() {
  for (int attempt = 0; attempt < 60; ++attempt) {
    const int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return false;
    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_port = htons(kReceiverPort);
    inet_pton(AF_INET, "127.0.0.1", &address.sin_addr);
    if (connect(fd, reinterpret_cast<sockaddr*>(&address), sizeof(address)) ==
        0) {
      socket_fd_ = fd;
      return true;
    }
    close(fd);
    std::this_thread::sleep_for(std::chrono::milliseconds(100));
  }
  return false;
}

bool WiredAndroidAutoReceiver::InitializeDecoder() {
  if (pipeline_ != nullptr) return true;
  InitializeGStreamerOnce();
  const char* decoder_override = std::getenv("AA_VIDEO_DECODER");
  const bool force_software =
      decoder_override != nullptr &&
      std::string(decoder_override) == "software";

  std::vector<std::pair<const char*, const char*>> candidates;
  if (!force_software) {
    candidates.emplace_back(
        "Jetson NVDEC/VIC",
        "appsrc name=aa_source is-live=true do-timestamp=true block=false "
        "format=time caps=video/x-h264,stream-format=byte-stream,alignment=nal "
        "! queue max-size-buffers=6 leaky=downstream ! h264parse "
        "disable-passthrough=true config-interval=-1 "
        "! video/x-h264,stream-format=byte-stream,alignment=au "
        "! nvv4l2decoder enable-max-performance=true disable-dpb=true "
        "num-extra-surfaces=2 ! nvvidconv compute-hw=2 output-buffers=4 "
        "! video/x-raw,format=RGBA ! appsink name=aa_sink sync=false "
        "max-buffers=1 drop=true");
  }
  candidates.emplace_back(
      "CPU",
      "appsrc name=aa_source is-live=true do-timestamp=true block=false "
      "format=time caps=video/x-h264,stream-format=byte-stream,alignment=nal "
      "! queue max-size-buffers=6 leaky=downstream ! h264parse "
      "disable-passthrough=true ! avdec_h264 max-threads=2 "
      "! videoconvert n-threads=2 ! video/x-raw,format=RGBA "
      "! appsink name=aa_sink sync=false max-buffers=1 drop=true");

  std::string last_error = "Decoder H.264 gagal dibuat";
  for (const auto& candidate : candidates) {
    g_autoptr(GError) error = nullptr;
    pipeline_ = gst_parse_launch(candidate.second, &error);
    if (pipeline_ == nullptr) {
      if (error != nullptr) last_error = error->message;
      continue;
    }
    appsrc_ = GST_APP_SRC(
        gst_bin_get_by_name(GST_BIN(pipeline_), "aa_source"));
    appsink_ = GST_APP_SINK(
        gst_bin_get_by_name(GST_BIN(pipeline_), "aa_sink"));
    if (appsrc_ == nullptr || appsink_ == nullptr) {
      last_error = "Elemen GStreamer appsrc/appsink tidak tersedia";
      DestroyDecoder();
      continue;
    }
    GstAppSinkCallbacks callbacks{};
    callbacks.new_sample = OnNewSample;
    gst_app_sink_set_callbacks(appsink_, &callbacks, this, nullptr);
    gst_app_src_set_stream_type(appsrc_, GST_APP_STREAM_TYPE_STREAM);
    if (gst_element_set_state(pipeline_, GST_STATE_PLAYING) ==
        GST_STATE_CHANGE_FAILURE) {
      last_error = std::string("Decoder ") + candidate.first +
                   " tidak dapat masuk mode PLAYING";
      DestroyDecoder();
      continue;
    }
    g_message("Android Auto video decoder: %s", candidate.first);
    return true;
  }

  SetStatus("error", last_error);
  return false;
}

void WiredAndroidAutoReceiver::DestroyDecoder() {
  if (pipeline_ != nullptr) gst_element_set_state(pipeline_, GST_STATE_NULL);
  if (appsrc_ != nullptr) {
    gst_object_unref(appsrc_);
    appsrc_ = nullptr;
  }
  if (appsink_ != nullptr) {
    gst_object_unref(appsink_);
    appsink_ = nullptr;
  }
  if (pipeline_ != nullptr) {
    gst_object_unref(pipeline_);
    pipeline_ = nullptr;
  }
}

bool WiredAndroidAutoReceiver::InitializeAudio() {
  // Create each output only when its first PCM frame arrives. Starting Pulse
  // during USB negotiation leaves it running on an old base clock and makes
  // early transport jitter much more audible.
  InitializeGStreamerOnce();
  return true;
}

bool WiredAndroidAutoReceiver::CreateAudioPipeline(
    const char* source_name,
    uint32_t sample_rate,
    uint8_t channels,
    AudioOutput* output) {
  const char* configured_sink = std::getenv("AA_AUDIO_SINK");
  const std::string sink =
      configured_sink != nullptr && configured_sink[0] != '\0'
          ? configured_sink
          : "pulsesink sync=false async=false buffer-time=120000 "
            "latency-time=20000";
  const std::string queue_name = std::string(source_name) + "_startup_queue";
  const GstClockTime startup_buffer =
      sample_rate == 48000 && channels == 2 ? kMediaAudioStartupBuffer : 0;
  std::ostringstream description;
  description << "appsrc name=" << source_name
              << " is-live=true do-timestamp=true block=false format=time "
              << "max-time=400000000 leaky-type=downstream "
              << "caps=audio/x-raw,format=S16LE,layout=interleaved,rate="
              << sample_rate << ",channels=" << static_cast<int>(channels)
              << " ! queue name=" << queue_name
              << " max-size-time=300000000 min-threshold-time="
              << startup_buffer << " leaky=downstream "
              << "! audioconvert ! audioresample ! " << sink;

  g_autoptr(GError) error = nullptr;
  output->pipeline = gst_parse_launch(description.str().c_str(), &error);
  if (output->pipeline == nullptr) {
    g_warning("Android Auto audio pipeline failed: %s",
              error == nullptr ? "unknown error" : error->message);
    return false;
  }
  output->appsrc = GST_APP_SRC(
      gst_bin_get_by_name(GST_BIN(output->pipeline), source_name));
  output->startup_queue =
      gst_bin_get_by_name(GST_BIN(output->pipeline), queue_name.c_str());
  if (output->appsrc == nullptr || output->startup_queue == nullptr) {
    return false;
  }
  if (startup_buffer > 0) {
    g_signal_connect(output->startup_queue, "running",
                     G_CALLBACK(ReleaseAudioStartupBuffer), nullptr);
  }
  output->sample_rate = sample_rate;
  output->channels = channels;
  output->frame_count = 0;
  output->diagnostic_bytes = 0;
  output->diagnostic_peak = 0;
  output->diagnostic_started_us = 0;
  gst_app_src_set_stream_type(output->appsrc, GST_APP_STREAM_TYPE_STREAM);
  if (gst_element_set_state(output->pipeline, GST_STATE_PLAYING) ==
      GST_STATE_CHANGE_FAILURE) {
    return false;
  }
  return true;
}

void WiredAndroidAutoReceiver::DestroyAudio() {
  auto destroy_pipeline = [](AudioOutput& output) {
    if (output.pipeline != nullptr) {
      gst_element_set_state(output.pipeline, GST_STATE_NULL);
    }
    if (output.appsrc != nullptr) {
      gst_object_unref(output.appsrc);
      output.appsrc = nullptr;
    }
    if (output.startup_queue != nullptr) {
      gst_object_unref(output.startup_queue);
      output.startup_queue = nullptr;
    }
    if (output.pipeline != nullptr) {
      gst_object_unref(output.pipeline);
      output.pipeline = nullptr;
    }
    output.frame_count = 0;
    output.diagnostic_bytes = 0;
    output.diagnostic_peak = 0;
    output.diagnostic_started_us = 0;
  };
  destroy_pipeline(media_audio_);
  destroy_pipeline(speech_audio_);
  destroy_pipeline(system_audio_);
}

void WiredAndroidAutoReceiver::ReaderLoop() {
  while (reader_running_.load()) {
    uint8_t header[5];
    if (!ReadExact(socket_fd_, header, sizeof(header))) break;
    uint32_t network_length = 0;
    std::memcpy(&network_length, header + 1, sizeof(network_length));
    const uint32_t length = ntohl(network_length);
    if (length > kMaximumMessageSize) {
      SetStatus("error", "Frame receiver melebihi batas aman");
      break;
    }
    std::vector<uint8_t> payload(length);
    if (length > 0 && !ReadExact(socket_fd_, payload.data(), length)) break;
    HandleMessage(header[0], payload);
  }
  const bool was_running = reader_running_.exchange(false);
  if (was_running) SetStatus("disconnected", "Koneksi receiver lokal terputus");
}

void WiredAndroidAutoReceiver::HandleMessage(
    uint8_t type,
    const std::vector<uint8_t>& payload) {
  if (type == kStatusMessage) {
    const std::string json(payload.begin(), payload.end());
    SetStatus(ExtractJsonString(json, "state"),
              ExtractJsonString(json, "message"));
  } else if (type == kCodecMessage) {
    const std::string codec(payload.begin(), payload.end());
    if (codec != "h264") {
      SetStatus("error", "Codec Android Auto tidak didukung: " + codec);
    }
  } else if (type == kVideoMessage) {
    PushVideo(payload);
  } else if (type == kAudioMessage) {
    PushAudio(payload);
  }
}

void WiredAndroidAutoReceiver::PushVideo(
    const std::vector<uint8_t>& payload) {
  if (appsrc_ == nullptr || payload.empty()) return;
  GstBuffer* buffer = gst_buffer_new_allocate(nullptr, payload.size(), nullptr);
  if (buffer == nullptr) return;
  gst_buffer_fill(buffer, 0, payload.data(), payload.size());
  // One IPC payload can be an SPS/PPS/slice rather than one complete picture.
  // Let appsrc timestamp arrival and h264parse assemble access units; assigning
  // 1/30 s to every NAL made the decoder clock drift and produced uneven motion.
  GST_BUFFER_PTS(buffer) = GST_CLOCK_TIME_NONE;
  GST_BUFFER_DTS(buffer) = GST_CLOCK_TIME_NONE;
  GST_BUFFER_DURATION(buffer) = GST_CLOCK_TIME_NONE;
  ++frame_number_;
  const GstFlowReturn result = gst_app_src_push_buffer(appsrc_, buffer);
  if (result != GST_FLOW_OK && result != GST_FLOW_FLUSHING) {
    SetStatus("error", "Decoder menolak frame Android Auto");
  }
}

void WiredAndroidAutoReceiver::PushAudio(
    const std::vector<uint8_t>& payload) {
  if (payload.size() <= 7) return;
  const uint8_t channel_id = payload[0];
  const uint8_t codec = payload[1];
  if (codec != 1) {
    SetStatus("error", "Codec audio Android Auto bukan PCM");
    return;
  }

  AudioOutput* output = nullptr;
  if (channel_id == 4) output = &media_audio_;
  if (channel_id == 5) output = &speech_audio_;
  if (channel_id == 6) output = &system_audio_;
  if (output == nullptr) return;

  uint32_t network_rate = 0;
  std::memcpy(&network_rate, payload.data() + 2, sizeof(network_rate));
  const uint32_t negotiated_rate = ntohl(network_rate);
  const uint8_t negotiated_channels = payload[6];
  if (output->pipeline == nullptr) {
    const uint32_t fallback_rate = channel_id == 4 ? 48000 : 16000;
    const uint8_t fallback_channels = channel_id == 4 ? 2 : 1;
    const uint32_t sample_rate =
        negotiated_rate > 0 ? negotiated_rate : fallback_rate;
    const uint8_t channels =
        negotiated_channels > 0 ? negotiated_channels : fallback_channels;
    const char* source_name = channel_id == 4
                                  ? "aa_media_audio"
                                  : channel_id == 5 ? "aa_speech_audio"
                                                    : "aa_system_audio";
    if (!CreateAudioPipeline(source_name, sample_rate, channels, output)) {
      SetStatus("error", "Output audio Android Auto tidak dapat dibuka");
      return;
    }
  }
  if (output->appsrc == nullptr) return;

  const size_t pcm_size = payload.size() - 7;
  const uint64_t bytes_per_second =
      static_cast<uint64_t>(output->sample_rate) * output->channels * 2;
  if (pcm_size == 0 || bytes_per_second == 0) return;
  GstBuffer* buffer = gst_buffer_new_allocate(nullptr, pcm_size, nullptr);
  if (buffer == nullptr) return;
  gst_buffer_fill(buffer, 0, payload.data() + 7, pcm_size);

  const GstClockTime duration =
      gst_util_uint64_scale(pcm_size, GST_SECOND, bytes_per_second);
  // appsrc timestamps on arrival. The unsynchronised Pulse sink consumes PCM
  // continuously, so transient USB jitter cannot create a new future PTS and
  // manufacture an audible silent gap during startup.
  GST_BUFFER_PTS(buffer) = GST_CLOCK_TIME_NONE;
  GST_BUFFER_DTS(buffer) = GST_CLOCK_TIME_NONE;
  GST_BUFFER_DURATION(buffer) = duration;

  const GstFlowReturn result =
      gst_app_src_push_buffer(output->appsrc, buffer);
  if (result != GST_FLOW_OK && result != GST_FLOW_FLUSHING) {
    g_warning("Android Auto audio channel %u rejected PCM frame: %d",
              channel_id, result);
    return;
  }
  ++output->frame_count;
  output->diagnostic_bytes += pcm_size;
  for (size_t offset = 7; offset + 1 < payload.size(); offset += 2) {
    int16_t sample = 0;
    std::memcpy(&sample, payload.data() + offset, sizeof(sample));
    const uint16_t magnitude = static_cast<uint16_t>(
        std::min<int32_t>(32768, std::abs(static_cast<int32_t>(sample))));
    output->diagnostic_peak = std::max(output->diagnostic_peak, magnitude);
  }
  const int64_t diagnostic_now_us = g_get_monotonic_time();
  if (output->diagnostic_started_us == 0) {
    output->diagnostic_started_us = diagnostic_now_us;
  }
  const int64_t diagnostic_elapsed_us =
      diagnostic_now_us - output->diagnostic_started_us;
  if (diagnostic_elapsed_us >= 5 * G_USEC_PER_SEC) {
    const double kilobits_per_second =
        static_cast<double>(output->diagnostic_bytes) * 8.0 * G_USEC_PER_SEC /
        static_cast<double>(diagnostic_elapsed_us) / 1000.0;
    const double peak_percent =
        static_cast<double>(output->diagnostic_peak) * 100.0 / 32768.0;
    const double queued_ms =
        static_cast<double>(gst_app_src_get_current_level_time(output->appsrc)) /
        GST_MSECOND;
    g_message("Android Auto audio performance: channel=%u %.0f kbps "
              "peak=%.1f%% queue=%.0fms",
              channel_id, kilobits_per_second, peak_percent, queued_ms);
    output->diagnostic_started_us = diagnostic_now_us;
    output->diagnostic_bytes = 0;
    output->diagnostic_peak = 0;
  }
  const uint64_t frames = audio_frame_count_.fetch_add(1) + 1;
  if (frames == 1) {
    g_message("Android Auto first PCM frame: channel=%u rate=%u channels=%u",
              channel_id, negotiated_rate, negotiated_channels);
  }
}

GstFlowReturn WiredAndroidAutoReceiver::OnNewSample(GstAppSink* sink,
                                                    gpointer user_data) {
  auto* self = static_cast<WiredAndroidAutoReceiver*>(user_data);
  GstSample* sample = gst_app_sink_pull_sample(sink);
  if (sample == nullptr) return GST_FLOW_EOS;
  GstCaps* caps = gst_sample_get_caps(sample);
  GstBuffer* buffer = gst_sample_get_buffer(sample);
  GstVideoInfo info;
  gst_video_info_init(&info);
  if (caps != nullptr && buffer != nullptr &&
      gst_video_info_from_caps(&info, caps)) {
    GstVideoFrame frame;
    if (gst_video_frame_map(&frame, &info, buffer, GST_MAP_READ)) {
      projection_texture_update(
          self->texture_, static_cast<const uint8_t*>(
                              GST_VIDEO_FRAME_PLANE_DATA(&frame, 0)),
          GST_VIDEO_FRAME_WIDTH(&frame), GST_VIDEO_FRAME_HEIGHT(&frame),
          static_cast<size_t>(GST_VIDEO_FRAME_PLANE_STRIDE(&frame, 0)));
      const uint64_t decoded = self->decoded_frame_count_.fetch_add(1) + 1;
      const int64_t now_us = g_get_monotonic_time();
      if (self->fps_window_started_us_ == 0) {
        self->fps_window_started_us_ = now_us;
      }
      ++self->fps_window_frames_;
      const int64_t elapsed_us = now_us - self->fps_window_started_us_;
      if (elapsed_us >= 5 * G_USEC_PER_SEC) {
        const double fps =
            static_cast<double>(self->fps_window_frames_) * G_USEC_PER_SEC /
            static_cast<double>(elapsed_us);
        g_message("Android Auto render performance: %.1f fps (%" G_GUINT64_FORMAT
                  " decoded total)",
                  fps, decoded);
        self->fps_window_started_us_ = now_us;
        self->fps_window_frames_ = 0;
      }
      if (decoded == 1) {
        std::ostringstream message;
        message << "Android Auto aktif · video "
                << GST_VIDEO_FRAME_WIDTH(&frame) << "x"
                << GST_VIDEO_FRAME_HEIGHT(&frame);
        self->SetStatus("active", message.str());
        g_message("Android Auto first decoded frame: %ux%u",
                  GST_VIDEO_FRAME_WIDTH(&frame),
                  GST_VIDEO_FRAME_HEIGHT(&frame));
      }
      gst_video_frame_unmap(&frame);
    }
  }
  gst_sample_unref(sample);
  return GST_FLOW_OK;
}

bool WiredAndroidAutoReceiver::SendMessage(uint8_t type,
                                           const std::string& payload) {
  return SendMessage(type,
                     reinterpret_cast<const uint8_t*>(payload.data()),
                     payload.size());
}

bool WiredAndroidAutoReceiver::SendMessage(uint8_t type,
                                           const uint8_t* payload,
                                           size_t length) {
  std::lock_guard<std::mutex> lock(send_mutex_);
  if (socket_fd_ < 0 || length > UINT32_MAX) return false;
  uint8_t header[5];
  header[0] = type;
  const uint32_t network_length = htonl(static_cast<uint32_t>(length));
  std::memcpy(header + 1, &network_length, sizeof(network_length));

  auto send_all = [this](const uint8_t* data, size_t size) {
    size_t offset = 0;
    while (offset < size) {
      const ssize_t count = send(socket_fd_, data + offset, size - offset,
                                 MSG_NOSIGNAL);
      if (count < 0) {
        if (errno == EINTR) continue;
        return false;
      }
      offset += static_cast<size_t>(count);
    }
    return true;
  };
  return send_all(header, sizeof(header)) &&
         (length == 0 || send_all(payload, length));
}

void WiredAndroidAutoReceiver::SetStatus(const std::string& state,
                                         const std::string& message) {
  std::lock_guard<std::mutex> lock(status_mutex_);
  if (!state.empty()) status_.state = state;
  status_.message = message;
}

std::string WiredAndroidAutoReceiver::LocateServiceScript() const {
  const char* override_path = std::getenv("AA_RECEIVER_SCRIPT");
  if (override_path != nullptr &&
      g_file_test(override_path, G_FILE_TEST_IS_EXECUTABLE)) {
    return override_path;
  }

  std::vector<std::string> roots;
  const char* configured_root = std::getenv("MULTIMEDIA_ROOT");
  if (configured_root != nullptr && configured_root[0] != '\0') {
    roots.emplace_back(configured_root);
  }
  g_autofree gchar* current = g_get_current_dir();
  roots.emplace_back(current);
  roots.emplace_back(std::string(current) + "/..");

  for (const std::string& root : roots) {
    const std::string script = root + "/scripts/run_android_auto_receiver.sh";
    const std::string receiver =
        root + "/frontend/projection_receiver/dist/receiver.js";
    if (g_file_test(script.c_str(), G_FILE_TEST_IS_EXECUTABLE) &&
        g_file_test(receiver.c_str(), G_FILE_TEST_IS_REGULAR)) {
      return script;
    }
  }
  return {};
}
