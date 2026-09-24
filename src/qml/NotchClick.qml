/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick

// The click a notch makes, from the keyboard's own quiet tick. The sound
// lives apart so that a system without Qt Multimedia loses the click and
// nothing else.
Item {
    function play() {
        if (sound.item) {
            sound.item.play();
        }
    }

    Loader {
        id: sound
        source: "NotchSound.qml"
    }
}
