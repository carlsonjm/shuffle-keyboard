// SPDX-FileCopyrightText: 2026 Shuffle Project
// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL

// A bottom panel reserving a band, as far as the compositor is concerned.
//
// The real one is the Bottom Surface. What matters to the handle is only that
// something holds a strut at the bottom edge, because the handle asks to be
// placed in what is left after every exclusive zone. Without one in the
// session, a handle sitting at the bottom of the output proves nothing about
// sitting above a dock.
import QtQuick
import QtQuick.Window

import org.kde.layershell as LayerShell

Window {
    id: band

    width: 100
    height: 60
    color: "#141414"
    visible: true

    LayerShell.Window.anchors: LayerShell.Window.AnchorBottom
                               | LayerShell.Window.AnchorLeft
                               | LayerShell.Window.AnchorRight
    LayerShell.Window.layer: LayerShell.Window.LayerBottom
    LayerShell.Window.exclusionZone: 60
    LayerShell.Window.scope: "shuffle-test-band"
}
