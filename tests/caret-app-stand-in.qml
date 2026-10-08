// SPDX-FileCopyrightText: 2026 Shuffle Project
// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL

// An application with a line of text and the cursor in its middle, so a probe
// can drag the caret trackpad and read how far the cursor went. It reports
// every arrow key it is sent and every place the cursor lands. Its field takes
// the focus when the file named on the command line appears.

import QtQuick
import QtQuick.Window

Window {
    id: app

    readonly property string flag: Qt.application.arguments[Qt.application.arguments.length - 1]

    title: "caret-app-stand-in"
    width: 600
    height: 400
    color: "#303030"
    visible: true

    TextInput {
        id: field

        width: 580
        height: 40
        color: "white"
        text: "abcdefghij".repeat(8)
        onCursorPositionChanged: console.warn("app cursor=" + field.cursorPosition)
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Left) console.warn("app key=left");
            else if (event.key === Qt.Key_Right) console.warn("app key=right");
            event.accepted = false;
        }
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
                    field.cursorPosition = 40;
                }
            } catch (error) {
                // Not there yet.
            }
        }
    }
}
