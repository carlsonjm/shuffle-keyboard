#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
"""Plasma's shell, as far as the Keyboard can tell with no Bottom Surface.

Where no Bottom Surface is installed the Keyboard moves Plasma's bottom panels
itself, through the shell's evaluateScript: it reads their hiding modes, sets
them to autohide while the keys are up, and puts each mode back afterwards.
This keeps a bottom panel and a top panel, runs those three kinds of script
against them the way the shell would, and logs every change, so a session can
ask what the panels went through. It is a stand-in for the shell, never for
the Keyboard's own half.
"""

import json
import re
import sys

import gi

gi.require_version("GLib", "2.0")
gi.require_version("Gio", "2.0")
from gi.repository import GLib, Gio  # noqa: E402

SERVICE = "org.kde.plasmashell"
PATH = "/PlasmaShell"

INTROSPECTION = """
<node>
  <interface name='org.kde.PlasmaShell'>
    <method name='evaluateScript'>
      <arg type='s' name='script' direction='in'/>
      <arg type='s' name='output' direction='out'/>
    </method>
  </interface>
</node>
"""


def say(line):
    print(line, flush=True)


def main():
    panels = {
        1: {"location": "bottom", "hiding": "none"},
        2: {"location": "top", "hiding": "none"},
    }

    def evaluate(script):
        if "print(JSON.stringify(saved))" in script:
            saved = [{"id": pid, "hiding": p["hiding"]}
                     for pid, p in panels.items() if p["location"] == "bottom"]
            say("read %s" % json.dumps(saved, separators=(",", ":")))
            return json.dumps(saved)
        if 'panel.hiding = "autohide"' in script:
            ids = json.loads(re.search(r"const ids = (\[.*?\]);", script).group(1))
            for pid in ids:
                panel = panels.get(pid)
                if panel and panel["location"] == "bottom":
                    panel["hiding"] = "autohide"
                    say("panel %d hiding=autohide" % pid)
            return ""
        if "panel.hiding = entry.hiding" in script:
            saved = json.loads(re.search(r"const saved = (\[.*?\]);", script, re.S).group(1))
            for entry in saved:
                panel = panels.get(entry["id"])
                if panel and panel["location"] == "bottom" and panel["hiding"] == "autohide":
                    panel["hiding"] = entry["hiding"]
                    say("panel %d hiding=%s" % (entry["id"], entry["hiding"]))
            return ""
        say("unknown script")
        return ""

    def on_call(_connection, _sender, _path, _interface, method, parameters, invocation):
        if method == "evaluateScript":
            invocation.return_value(GLib.Variant("(s)", (evaluate(parameters[0]),)))
            return
        invocation.return_error_literal(
            Gio.dbus_error_quark(), Gio.DBusError.UNKNOWN_METHOD, "no such method")

    node = Gio.DBusNodeInfo.new_for_xml(INTROSPECTION)
    connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    for interface in node.interfaces:
        connection.register_object(PATH, interface, on_call, None, None)

    Gio.bus_own_name_on_connection(
        connection, SERVICE, Gio.BusNameOwnerFlags.NONE,
        lambda *_args: say("ready"), None)

    GLib.MainLoop().run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
