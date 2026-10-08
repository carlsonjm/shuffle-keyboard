// SPDX-FileCopyrightText: 2026 Shuffle Project
// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL

// Where the compositor has seated the Keyboard. An input panel never learns
// its own position, so this asks the compositor rather than the Keyboard.

// The work area first, so a reading can say whether the reservation had
// actually gone when the Keyboard was measured.
var area = workspace.clientArea(KWin.MaximizeArea, workspace.activeScreen, workspace.currentDesktop);
callDBus("co.goodinput.BottomSurface",
         "/BottomSurface",
         "co.goodinput.test.Control",
         "record",
         "area bottom=" + (area.y + area.height));

workspace.stackingOrder.forEach(function (window) {
    if (!window.inputMethod) {
        return;
    }
    var frame = window.frameGeometry;
    callDBus("co.goodinput.BottomSurface",
             "/BottomSurface",
             "co.goodinput.test.Control",
             "record",
             "keyboard " + frame.x + "," + frame.y
                 + " " + frame.width + "x" + frame.height
                 + " bottom=" + (frame.y + frame.height));
});
