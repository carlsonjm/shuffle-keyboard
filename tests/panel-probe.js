// SPDX-FileCopyrightText: 2026 Shuffle Project
// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL

// Every surface the Keyboard has on screen, as the compositor sees it: the
// keys, and anything that opens over them. An input method never learns what
// the compositor shows of it, so this asks the compositor.
var shown = [];
workspace.stackingOrder.forEach(function (window) {
    if (!window.inputMethod || window.hidden) {
        return;
    }
    var frame = window.frameGeometry;
    shown.push(frame.x + "," + frame.y + " " + frame.width + "x" + frame.height);
});
callDBus("co.goodinput.BottomSurface",
         "/BottomSurface",
         "co.goodinput.test.Control",
         "record",
         "panels " + shown.length + (shown.length ? " " + shown.join(" ") : ""));
