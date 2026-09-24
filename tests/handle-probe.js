// SPDX-FileCopyrightText: 2026 Shuffle Project
// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL

// Asks the compositor where it actually put things. A client never learns its
// own position on Wayland, so the handle's own report can say it is placed and
// how big it is, and nothing more. This is the other half.
var area = workspace.clientArea(KWin.MaximizeArea, workspace.activeScreen, workspace.currentDesktop);
callDBus("studio.warbler.BottomSurface",
         "/BottomSurface",
         "studio.warbler.test.Control",
         "record",
         "area bottom=" + (area.y + area.height));

workspace.windowList().forEach(function (window) {
    var frame = window.frameGeometry;
    callDBus("studio.warbler.BottomSurface",
             "/BottomSurface",
             "studio.warbler.test.Control",
             "record",
             "window " + frame.x + "," + frame.y
                 + " " + frame.width + "x" + frame.height
                 + " on " + (window.output ? window.output.name : "-"));
});
