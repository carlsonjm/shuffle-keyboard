#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
"""Kadunce, as far as the Keyboard's raise can tell.

The Keyboard asks for the keys through Kadunce, which marks the request as the
person's and asks the compositor itself. Kadunce answers from the compositor's
own bus name, which nothing else can hold, so this answers under a name of its
own on the same path and interface, and the Keyboard is told that name for the
test. Like Kadunce it asks the compositor for the keys; told to stay quiet, it
answers without asking, as Kadunce's ask shows nothing straight after signing
in.
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
    <method name='raiseKeyboard'/>
    <method name='keyboardHeading'>
      <arg type='d' direction='in'/>
      <arg type='i' direction='in'/>
    </method>
  </interface>
  <interface name='studio.warbler.test.Control'>
    <method name='setAsking'>
      <arg type='b' direction='in'/>
    </method>
  </interface>
</node>
"""


def main():
    node = Gio.DBusNodeInfo.new_for_xml(INTROSPECTION)
    connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)

    asking = {"value": True}

    def on_call(_connection, _sender, _path, interface, method, parameters, invocation):
        if interface == "studio.warbler.test.Control" and method == "setAsking":
            asking["value"] = parameters.unpack()[0]
            invocation.return_value(None)
            return
        if interface == "studio.warbler.Kadunce" and method == "raiseKeyboard":
            print("raiseKeyboard asking=%s" % asking["value"], flush=True)
            if asking["value"]:
                connection.call_sync("org.kde.KWin", "/VirtualKeyboard", "org.kde.kwin.VirtualKeyboard",
                                     "forceActivate", None, None, Gio.DBusCallFlags.NONE, -1, None)
            invocation.return_value(None)
            return
        if interface == "studio.warbler.Kadunce" and method == "keyboardHeading":
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
