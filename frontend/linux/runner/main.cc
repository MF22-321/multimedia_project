#include "my_application.h"
#include <X11/Xlib.h>

int main(int argc, char** argv) {
  // media_kit/libmpv may access X11 from a worker thread on Jetson. Xlib must
  // be initialized for multi-threaded use before GTK/Flutter touches display.
  XInitThreads();
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
