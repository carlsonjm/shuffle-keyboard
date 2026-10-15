#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
"""The desktop's RemoteDesktop portal, as far as the precision surface can tell.

The precision surface asks the portal for the pointer once, and on a device
where the person has allowed it the portal says yes without asking again. This
says yes the same way, and as soon as it can: each request answers on the
object the portal names after the request's handle_token, before the call that
made it has returned, so a Keyboard that listened only once the call returned
would never hear it. The pointer events the surface sends afterwards are
logged and dropped.
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

    def answer_first(sender, options, results):
        # The path every portal since 0.9 uses, from the caller's unique
        # name and the token it chose.
        token = options.get("handle_token") or "r%d" % counter["requests"]
        counter["requests"] += 1
        path = "/org/freedesktop/portal/desktop/request/%s/%s" % (
            sender.lstrip(":").replace(".", "_"), token)
        connection.emit_signal(None, path, "org.freedesktop.portal.Request", "Response",
                               GLib.Variant("(ua{sv})", (0, results)))
        return GLib.Variant("(o)", (path,))

    def on_call(_connection, sender, _path, _interface, method, parameters, invocation):
        print("portal %s" % method, flush=True)
        if method == "CreateSession":
            invocation.return_value(answer_first(sender, parameters[0], {
                "session_handle": GLib.Variant(
                    "o", "/org/freedesktop/portal/desktop/session/test/s1")}))
            return
        if method == "SelectDevices":
            invocation.return_value(answer_first(sender, parameters[1], {}))
            return
        if method == "Start":
            invocation.return_value(answer_first(sender, parameters[2], {
                "devices": GLib.Variant("u", POINTER),
                "restore_token": GLib.Variant("s", "test-restore")}))
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
