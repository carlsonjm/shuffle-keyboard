// SPDX-FileCopyrightText: 2026 Shuffle Project
// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL

// Which window holds the focus, as the compositor sees it.
var active = workspace.activeWindow;
callDBus("co.goodinput.BottomSurface",
         "/BottomSurface",
         "co.goodinput.test.Control",
         "record",
         "focus " + (active ? (active.caption === "app-stand-in" ? "app"
                                : (active.resourceClass + ":" + active.caption)) : "none"));
