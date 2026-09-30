/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

/*
 * A physical keyboard, mouse and touchscreen, as far as a private compositor
 * can tell: KWin's fake-input protocol, read one command a line from stdin.
 *
 *   key CODE 1|0          an evdev key code pressed or released
 *   abs X Y               the pointer to a point on the output
 *   down | up             the left button
 *   tdown ID X Y          a finger down
 *   tmove ID X Y          that finger moved
 *   tup ID                that finger lifted
 *   wait MS               nothing, for that long
 *
 * Each command reaches the compositor before the next is read. The compositor
 * has to run with KWIN_WAYLAND_NO_PERMISSION_CHECKS=1, which only a private
 * one ever should.
 */

#include "fake-input-client-protocol.h"

#include <stdio.h>
#include <string.h>
#include <time.h>
#include <wayland-client.h>

static struct org_kde_kwin_fake_input *fake;

static void on_global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version)
{
    (void)data;
    if (strcmp(interface, org_kde_kwin_fake_input_interface.name) == 0) {
        fake = wl_registry_bind(registry, name, &org_kde_kwin_fake_input_interface, version < 4 ? version : 4);
    }
}

static void on_global_remove(void *data, struct wl_registry *registry, uint32_t name)
{
    (void)data;
    (void)registry;
    (void)name;
}

static const struct wl_registry_listener registry_listener = {on_global, on_global_remove};

static void pause_ms(long ms)
{
    struct timespec span = {ms / 1000, (ms % 1000) * 1000000L};
    nanosleep(&span, NULL);
}

int main(void)
{
    struct wl_display *display = wl_display_connect(NULL);
    if (!display) {
        fprintf(stderr, "fake-input: no compositor\n");
        return 1;
    }
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    wl_display_roundtrip(display);
    if (!fake) {
        fprintf(stderr, "fake-input: the compositor offers no fake input\n");
        return 1;
    }
    org_kde_kwin_fake_input_authenticate(fake, "shuffle-keyboard-test", "sealed session test input");
    wl_display_roundtrip(display);
    printf("ready\n");
    fflush(stdout);

    char line[256];
    while (fgets(line, sizeof line, stdin)) {
        unsigned code, state, id;
        double x, y;
        long ms;
        if (sscanf(line, "key %u %u", &code, &state) == 2) {
            org_kde_kwin_fake_input_keyboard_key(fake, code, state);
        } else if (sscanf(line, "abs %lf %lf", &x, &y) == 2) {
            org_kde_kwin_fake_input_pointer_motion_absolute(fake, wl_fixed_from_double(x), wl_fixed_from_double(y));
        } else if (strncmp(line, "down", 4) == 0) {
            org_kde_kwin_fake_input_button(fake, 0x110, 1);
        } else if (strncmp(line, "up", 2) == 0) {
            org_kde_kwin_fake_input_button(fake, 0x110, 0);
        } else if (sscanf(line, "tdown %u %lf %lf", &id, &x, &y) == 3) {
            org_kde_kwin_fake_input_touch_down(fake, id, wl_fixed_from_double(x), wl_fixed_from_double(y));
            org_kde_kwin_fake_input_touch_frame(fake);
        } else if (sscanf(line, "tmove %u %lf %lf", &id, &x, &y) == 3) {
            org_kde_kwin_fake_input_touch_motion(fake, id, wl_fixed_from_double(x), wl_fixed_from_double(y));
            org_kde_kwin_fake_input_touch_frame(fake);
        } else if (sscanf(line, "tup %u", &id) == 1) {
            org_kde_kwin_fake_input_touch_up(fake, id);
            org_kde_kwin_fake_input_touch_frame(fake);
        } else if (sscanf(line, "wait %ld", &ms) == 1) {
            pause_ms(ms);
            continue;
        } else {
            continue;
        }
        wl_display_roundtrip(display);
    }

    wl_display_roundtrip(display);
    wl_display_disconnect(display);
    return 0;
}
