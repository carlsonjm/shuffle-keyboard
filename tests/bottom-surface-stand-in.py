#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
"""A Bottom Surface, as far as the Keyboard can tell.

The real one is a Plasma containment and needs a shell to exist inside. The
Keyboard reads three things from it and calls two methods on it, and this
answers exactly those, from the contract that the downstream repository owns.
It is a stand-in for the producer, never for the Keyboard's own half.
"""

import json
import sys

import gi

gi.require_version("GLib", "2.0")
gi.require_version("Gio", "2.0")
from gi.repository import GLib, Gio  # noqa: E402

SERVICE = "studio.warbler.BottomSurface"
PATH = "/BottomSurface"

INTROSPECTION = """
<node>
  <interface name='studio.warbler.BottomSurface'>
    <method name='dockExtent'>
      <arg type='s' name='outputName' direction='in'/>
      <arg type='s' name='payload' direction='out'/>
    </method>
    <method name='yieldRegion'>
      <arg type='b' name='granted' direction='out'/>
    </method>
    <method name='releaseRegion'>
      <arg type='b' name='released' direction='out'/>
    </method>
    <signal name='dockExtentChanged'>
      <arg type='s' name='outputName'/>
    </signal>
  </interface>
  <interface name='studio.warbler.test.Control'>
    <method name='report'>
      <arg type='b' name='presenting' direction='in'/>
      <arg type='b' name='obscured' direction='in'/>
      <arg type='i' name='band' direction='in'/>
      <arg type='i' name='left' direction='in'/>
      <arg type='i' name='right' direction='in'/>
    </method>
    <method name='setReserving'>
      <arg type='b' name='reserving' direction='in'/>
    </method>
    <method name='record'>
      <arg type='s' name='line' direction='in'/>
    </method>
  </interface>
</node>
"""


class StandIn:
    def __init__(self):
        self.presenting = False
        self.obscured = False
        self.band = 0
        self.left = 0
        self.right = 0
        self.reserving = True
        self.output_width = 1463
        self.holder = None
        self.connection = None

    def payload(self, output_name):
        return json.dumps(
            {
                "schema": "studio.warbler.shuffle.dock-extent",
                "version": 1,
                "output": output_name or "Virtual-1",
                "presenting": self.presenting,
                "obscured": self.obscured,
                "reserving": self.reserving,
                "band": {"height": self.band},
                "dock": {
                    "left": self.left,
                    "right": self.right,
                    "center": self.left + (self.right - self.left) // 2,
                },
                "available": {
                    "left": max(0, self.left),
                    "right": max(0, self.output_width - self.right),
                },
            },
            separators=(",", ":"),
        )

    def say(self, line):
        print(line, flush=True)

    def on_call(self, _connection, sender, _path, interface, method, parameters, invocation):
        if interface == "studio.warbler.BottomSurface":
            if method == "dockExtent":
                invocation.return_value(GLib.Variant("(s)", (self.payload(parameters[0]),)))
                return
            if method == "yieldRegion":
                granted = self.holder in (None, sender)
                if granted:
                    self.holder = sender
                    self.say("yielded=1")
                invocation.return_value(GLib.Variant("(b)", (granted,)))
                return
            if method == "releaseRegion":
                released = self.holder == sender
                if released:
                    self.holder = None
                    self.say("yielded=0")
                invocation.return_value(GLib.Variant("(b)", (released,)))
                return

        if interface == "studio.warbler.test.Control":
            if method == "report":
                self.presenting, self.obscured, self.band, self.left, self.right = parameters
                self.connection.emit_signal(
                    None, PATH, "studio.warbler.BottomSurface",
                    "dockExtentChanged", GLib.Variant("(s)", ("Virtual-1",)),
                )
                invocation.return_value(None)
                return
            if method == "setReserving":
                self.reserving = parameters[0]
                self.connection.emit_signal(
                    None, PATH, "studio.warbler.BottomSurface",
                    "dockExtentChanged", GLib.Variant("(s)", ("Virtual-1",)),
                )
                invocation.return_value(None)
                return
            if method == "record":
                self.say("record " + parameters[0])
                invocation.return_value(None)
                return

        invocation.return_error_literal(
            Gio.dbus_error_quark(), Gio.DBusError.UNKNOWN_METHOD, "no such method")


def main():
    stand_in = StandIn()
    node = Gio.DBusNodeInfo.new_for_xml(INTROSPECTION)
    connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    stand_in.connection = connection

    for interface in node.interfaces:
        connection.register_object(PATH, interface, stand_in.on_call, None, None)

    owned = {"yes": False}

    def acquired(*_args):
        owned["yes"] = True
        stand_in.say("ready")

    Gio.bus_own_name_on_connection(
        connection, SERVICE, Gio.BusNameOwnerFlags.NONE, acquired, None)

    GLib.MainLoop().run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
