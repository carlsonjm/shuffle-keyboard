#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# What the compositor shows, as pixels. "grab <file>" saves the whole screen
# through KWin's screenshot interface; "differ <a> <b> <x> <y> <w> <h>" prints
# how many pixels in that rectangle differ between two grabs. An input method
# never learns what the compositor draws of it, so this asks the compositor.

import os
import struct
import sys

from gi.repository import Gio, GLib


def grab(path):
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    read_fd, write_fd = os.pipe()
    fds = Gio.UnixFDList.new()
    handle = fds.append(write_fd)
    os.close(write_fd)
    reply, _ = bus.call_with_unix_fd_list_sync(
        "org.kde.KWin", "/org/kde/KWin/ScreenShot2", "org.kde.KWin.ScreenShot2",
        "CaptureActiveScreen",
        GLib.Variant("(a{sv}h)", ({}, handle)),
        GLib.VariantType("(a{sv})"), Gio.DBusCallFlags.NONE, 10000, fds, None)
    meta = reply.unpack()[0]
    width, height, stride = meta["width"], meta["height"], meta["stride"]
    data = bytearray()
    with os.fdopen(read_fd, "rb") as pipe:
        while len(data) < stride * height:
            chunk = pipe.read(stride * height - len(data))
            if not chunk:
                break
            data += chunk
    with open(path, "wb") as out:
        out.write(struct.pack("<III", width, height, stride))
        out.write(data)
    print(f"{width}x{height}")


def load(path):
    with open(path, "rb") as source:
        width, height, stride = struct.unpack("<III", source.read(12))
        return width, height, stride, source.read()


def differ(a, b, x, y, w, h):
    width, height, stride, first = load(a)
    _, _, _, second = load(b)
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(width, x + w), min(height, y + h)
    count = 0
    for row in range(y0, y1):
        start = row * stride
        for column in range(x0, x1):
            offset = start + column * 4
            if first[offset:offset + 4] != second[offset:offset + 4]:
                count += 1
    print(count)


if __name__ == "__main__":
    if sys.argv[1] == "grab":
        grab(sys.argv[2])
    else:
        differ(sys.argv[2], sys.argv[3], *map(int, sys.argv[4:8]))
