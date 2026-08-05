#ifndef MULTIMEDIA_PROJECTION_SDK_API_H_
#define MULTIMEDIA_PROJECTION_SDK_API_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ABI expected from the licensed receiver adapter shared library. The adapter
// is loaded from PROJECTION_SDK_LIBRARY at runtime, so the Flutter HMI remains
// independent from a specific Android Auto / CarPlay SDK vendor.
int multimedia_projection_initialize(void* flutter_texture_registrar);
int multimedia_projection_start(const char* target);
int multimedia_projection_disconnect(void);
int multimedia_projection_suspend(void);
int multimedia_projection_resume(void);
const char* multimedia_projection_get_state(void);
int64_t multimedia_projection_get_texture_id(void);
const char* multimedia_projection_get_message(void);
int multimedia_projection_send_touch(double x, double y, int action);
void multimedia_projection_shutdown(void);

#ifdef __cplusplus
}
#endif

#endif  // MULTIMEDIA_PROJECTION_SDK_API_H_
