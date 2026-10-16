// SPDX-FileCopyrightText: 2026 Shuffle Project
// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL

// Where the compositor has the pointer.
var at = workspace.cursorPos;
callDBus("co.goodinput.BottomSurface",
         "/BottomSurface",
         "co.goodinput.test.Control",
         "record",
         "cursor " + Math.round(at.x) + " " + Math.round(at.y));
