#include <X11/Xlib.h>
#include <X11/keysym.h>
#include <X11/extensions/XTest.h>

#include <chrono>
#include <cstdlib>
#include <string>
#include <thread>

int main(int argc, char** argv) {
  const bool alt_tab = argc == 2 && std::string(argv[1]) == "--alt-tab";
  const bool alt_escape = argc == 2 && std::string(argv[1]) == "--alt-escape";
  const bool escape = argc == 2 && std::string(argv[1]) == "--escape";
  if (!alt_tab && !alt_escape && !escape && argc != 3 && argc != 4) return 2;

  Display* display = XOpenDisplay(nullptr);
  if (display == nullptr) return 3;

  if (escape) {
    const KeyCode key = XKeysymToKeycode(display, XK_Escape);
    XTestFakeKeyEvent(display, key, True, CurrentTime);
    XTestFakeKeyEvent(display, key, False, CurrentTime);
    XSync(display, False);
    XCloseDisplay(display);
    return 0;
  }

  if (alt_tab || alt_escape) {
    const KeyCode alt = XKeysymToKeycode(display, XK_Alt_L);
    const KeyCode tab = XKeysymToKeycode(display, alt_tab ? XK_Tab : XK_Escape);
    XTestFakeKeyEvent(display, alt, True, CurrentTime);
    XTestFakeKeyEvent(display, tab, True, CurrentTime);
    XTestFakeKeyEvent(display, tab, False, CurrentTime);
    XTestFakeKeyEvent(display, alt, False, CurrentTime);
    XSync(display, False);
    XCloseDisplay(display);
    return 0;
  }

  if (argc == 4) {
    const Window target = static_cast<Window>(std::strtoul(argv[3], nullptr, 0));
    XMapRaised(display, target);
    const Atom active_window = XInternAtom(display, "_NET_ACTIVE_WINDOW", False);
    XEvent event{};
    event.xclient.type = ClientMessage;
    event.xclient.window = target;
    event.xclient.message_type = active_window;
    event.xclient.format = 32;
    event.xclient.data.l[0] = 2;
    event.xclient.data.l[1] = CurrentTime;
    XSendEvent(display, DefaultRootWindow(display), False,
               SubstructureRedirectMask | SubstructureNotifyMask, &event);
    XSync(display, False);
    std::this_thread::sleep_for(std::chrono::milliseconds(120));
  }

  const int x = std::atoi(argv[1]);
  const int y = std::atoi(argv[2]);
  XTestFakeMotionEvent(display, -1, x, y, CurrentTime);
  XSync(display, False);
  std::this_thread::sleep_for(std::chrono::milliseconds(80));

  XTestFakeButtonEvent(display, 1, True, CurrentTime);
  XSync(display, False);
  std::this_thread::sleep_for(std::chrono::milliseconds(90));
  XTestFakeButtonEvent(display, 1, False, CurrentTime);
  XSync(display, False);

  XCloseDisplay(display);
  return 0;
}
