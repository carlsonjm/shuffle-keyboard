// SPDX-FileCopyrightText: 2026 Shuffle Project
// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL

// A band that reserves the bottom of the output and can give the reservation
// up, the way the Bottom Surface does once its presentation has left. The
// session gives it up by creating the file named on the command line; a probe
// has no other channel into a window it did not write.

import QtQuick
import QtQuick.Window

import org.kde.layershell as LayerShell

Window {
    id: band

    readonly property string flag: Qt.application.arguments[Qt.application.arguments.length - 1]
    property bool reserving: true

    width: 100
    height: 60
    color: "#141414"
    visible: true

    LayerShell.Window.anchors: LayerShell.Window.AnchorBottom
                               | LayerShell.Window.AnchorLeft
                               | LayerShell.Window.AnchorRight
    // Plasma's panels are on the top layer, always.
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.exclusionZone: band.reserving ? 60 : 0
    LayerShell.Window.scope: "shuffle-test-band"
    // A dock never takes the keyboard. One that did would be the active client,
    // and the compositor would wait for it to ask for text before raising the
    // Keyboard at all.
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    // Said once the release has gone out with a frame, which is when the
    // Bottom Surface says it too.
    onFrameSwapped: {
        if (!band.reserving && !band.said) {
            band.said = true;
            console.warn("band reserving=false");
        }
    }
    property bool said: false

    Timer {
        interval: 10
        repeat: true
        running: band.reserving
        onTriggered: {
            const request = new XMLHttpRequest();
            request.open("GET", "file://" + band.flag, false);
            try {
                request.send();
                if (request.status === 200 || request.responseText.length > 0) {
                    band.reserving = false;
                    band.update();
                }
            } catch (error) {
                // Not there yet.
            }
        }
    }
}
