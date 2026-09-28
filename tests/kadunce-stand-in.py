#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
"""Kadunce, as far as the Keyboard's raise can tell.

Kadunce is a compositor effect and announces a swipe up from the bottom bezel
from the compositor's own bus name, which nothing else can hold. This answers
under a name of its own on the same path and interface, and the Keyboard is
told that name for the test. It emits the announcement when the session asks,
and nothing more: asking the compositor for the keys, as Kadunce also does, is
left to the session.
"""

import sys

import gi

gi.require_version("GLib", "2.0")
gi.require_version("Gio", "2.0")
from gi.repository import GLib, Gio  # noqa: E402

SERVICE = "studio.warbler.test.Kadunce"
PATH = "/Kadunce"

INTROSPECTION = """
<node>
  <interface name='studio.warbler.Kadunce'>
    <signal name='keysRequested'/>
  </interface>
  <interface name='studio.warbler.test.Control'>
    <method name='requestKeys'/>
  </interface>
</node>
"""


def main():
    node = Gio.DBusNodeInfo.new_for_xml(INTROSPECTION)
    connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)

    def on_call(_connection, _sender, _path, interface, method, _parameters, invocation):
        if interface == "studio.warbler.test.Control" and method == "requestKeys":
            connection.emit_signal(None, PATH, "studio.warbler.Kadunce", "keysRequested", None)
            print("keysRequested", flush=True)
            invocation.return_value(None)
            return
        invocation.return_error_literal(
            Gio.dbus_error_quark(), Gio.DBusError.UNKNOWN_METHOD, "no such method")

    for interface in node.interfaces:
        connection.register_object(PATH, interface, on_call, None, None)

    Gio.bus_own_name_on_connection(
        connection, SERVICE, Gio.BusNameOwnerFlags.NONE,
        lambda *_args: print("ready", flush=True), None)

    GLib.MainLoop().run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
