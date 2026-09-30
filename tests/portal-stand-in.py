#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
"""The desktop's RemoteDesktop portal, as far as the precision surface can tell.

The precision surface asks the portal for the pointer once, and on a device
where the person has allowed it the portal says yes without asking again. This
says yes the same way: each request answers a moment after it is made, since
the Keyboard listens for the answer only once the request has returned. The
pointer events the surface sends afterwards are logged and dropped.
"""

import sys

import gi

gi.require_version("GLib", "2.0")
gi.require_version("Gio", "2.0")
from gi.repository import GLib, Gio  # noqa: E402

SERVICE = "org.freedesktop.portal.Desktop"
PATH = "/org/freedesktop/portal/desktop"
POINTER = 2

INTROSPECTION = """
<node>
  <interface name='org.freedesktop.portal.RemoteDesktop'>
    <method name='CreateSession'>
      <arg type='a{sv}' direction='in'/>
      <arg type='o' direction='out'/>
    </method>
    <method name='SelectDevices'>
      <arg type='o' direction='in'/>
      <arg type='a{sv}' direction='in'/>
      <arg type='o' direction='out'/>
    </method>
    <method name='Start'>
      <arg type='o' direction='in'/>
      <arg type='s' direction='in'/>
      <arg type='a{sv}' direction='in'/>
      <arg type='o' direction='out'/>
    </method>
    <method name='NotifyPointerMotion'>
      <arg type='o' direction='in'/>
      <arg type='a{sv}' direction='in'/>
      <arg type='d' direction='in'/>
      <arg type='d' direction='in'/>
    </method>
    <method name='NotifyPointerButton'>
      <arg type='o' direction='in'/>
      <arg type='a{sv}' direction='in'/>
      <arg type='i' direction='in'/>
      <arg type='u' direction='in'/>
    </method>
    <method name='NotifyPointerAxis'>
      <arg type='o' direction='in'/>
      <arg type='a{sv}' direction='in'/>
      <arg type='d' direction='in'/>
      <arg type='d' direction='in'/>
    </method>
  </interface>
</node>
"""


def main():
    node = Gio.DBusNodeInfo.new_for_xml(INTROSPECTION)
    connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    counter = {"requests": 0}

    def answer_later(path, results):
        def answer():
            connection.emit_signal(None, path, "org.freedesktop.portal.Request", "Response",
                                   GLib.Variant("(ua{sv})", (0, results)))
            return False

        GLib.timeout_add(150, answer)

    def request_path():
        counter["requests"] += 1
        return "/org/freedesktop/portal/desktop/request/test/r%d" % counter["requests"]

    def on_call(_connection, _sender, _path, _interface, method, parameters, invocation):
        print("portal %s" % method, flush=True)
        if method == "CreateSession":
            path = request_path()
            invocation.return_value(GLib.Variant("(o)", (path,)))
            answer_later(path, {"session_handle": GLib.Variant(
                "o", "/org/freedesktop/portal/desktop/session/test/s1")})
            return
        if method == "SelectDevices":
            path = request_path()
            invocation.return_value(GLib.Variant("(o)", (path,)))
            answer_later(path, {})
            return
        if method == "Start":
            path = request_path()
            invocation.return_value(GLib.Variant("(o)", (path,)))
            answer_later(path, {"devices": GLib.Variant("u", POINTER),
                                "restore_token": GLib.Variant("s", "test-restore")})
            return
        invocation.return_value(None)

    for interface in node.interfaces:
        connection.register_object(PATH, interface, on_call, None, None)

    Gio.bus_own_name_on_connection(
        connection, SERVICE, Gio.BusNameOwnerFlags.NONE,
        lambda *_args: print("ready", flush=True), None)

    GLib.MainLoop().run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
