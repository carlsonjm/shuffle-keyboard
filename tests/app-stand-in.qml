// SPDX-FileCopyrightText: 2026 Shuffle Project
// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL

// An ordinary application window holding the focus, so a probe can see
// whether a raise from the handle hands it back, and whether the Keyboard
// still types into an application afterwards. Its field takes the focus when
// the file named on the command line appears.

import QtQuick
import QtQuick.Window

Window {
    id: app

    readonly property string flag: Qt.application.arguments[Qt.application.arguments.length - 1]

    title: "app-stand-in"
    width: 600
    height: 400
    color: "#303030"
    visible: true

    TextInput {
        id: field

        width: 400
        height: 40
        color: "white"
        onTextChanged: console.warn("app text=" + field.text)
    }

    Timer {
        interval: 50
        repeat: true
        running: !field.activeFocus
        onTriggered: {
            const request = new XMLHttpRequest();
            request.open("GET", "file://" + app.flag, false);
            try {
                request.send();
                if (request.responseText.length > 0) {
                    field.forceActiveFocus();
                }
            } catch (error) {
                // Not there yet.
            }
        }
    }
}
