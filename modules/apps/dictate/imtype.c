#define _DEFAULT_SOURCE
#include <string.h>
#include <unistd.h>
#include <wayland-client.h>
#include "im.h"

static struct wl_seat *seat;
static struct zwp_input_method_manager_v2 *manager;
static int pending, active, gone;
static unsigned serial;

static void global(void *d, struct wl_registry *r, uint32_t name, const char *iface, uint32_t v) {
	if (!strcmp(iface, wl_seat_interface.name) && !seat)
		seat = wl_registry_bind(r, name, &wl_seat_interface, 1);
	else if (!strcmp(iface, zwp_input_method_manager_v2_interface.name))
		manager = wl_registry_bind(r, name, &zwp_input_method_manager_v2_interface, 1);
}
static void global_remove(void *d, struct wl_registry *r, uint32_t name) {}
static const struct wl_registry_listener registry_listener = {global, global_remove};

static void activate(void *d, struct zwp_input_method_v2 *im) { pending = 1; }
static void deactivate(void *d, struct zwp_input_method_v2 *im) { pending = 0; }
static void surrounding(void *d, struct zwp_input_method_v2 *im, const char *t, uint32_t c, uint32_t a) {}
static void cause(void *d, struct zwp_input_method_v2 *im, uint32_t c) {}
static void content(void *d, struct zwp_input_method_v2 *im, uint32_t h, uint32_t p) {}
static void done(void *d, struct zwp_input_method_v2 *im) { serial++; active = pending; }
static void unavailable(void *d, struct zwp_input_method_v2 *im) { gone = 1; }
static const struct zwp_input_method_v2_listener im_listener = {
	activate, deactivate, surrounding, cause, content, done, unavailable};

int main(int argc, char **argv) {
	struct wl_display *display = wl_display_connect(NULL);
	if (!display) return 1;
	wl_registry_add_listener(wl_display_get_registry(display), &registry_listener, NULL);
	wl_display_roundtrip(display);
	if (!seat || !manager) return 1;
	struct zwp_input_method_v2 *im = zwp_input_method_manager_v2_get_input_method(manager, seat);
	zwp_input_method_v2_add_listener(im, &im_listener, NULL);
	// activate arrives only after the focused app answers, a few ms after binding.
	for (int i = 0; i < 50 && !active && !gone; i++) {
		wl_display_roundtrip(display);
		if (!active) usleep(4000);
	}
	if (gone || !active) return 1;
	if (argc > 1 && *argv[1]) {
		zwp_input_method_v2_commit_string(im, argv[1]);
		zwp_input_method_v2_commit(im, serial);
	}
	zwp_input_method_v2_destroy(im);
	wl_display_roundtrip(display);
	return 0;
}
