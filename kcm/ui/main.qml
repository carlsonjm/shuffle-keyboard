/*
    SPDX-FileCopyrightText: 2025 Devin Lin <devin@kde.org>
    SPDX-FileCopyrightText: 2026 Kristen McWilliam <kristen@kde.org>

    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.ScrollViewKCM {
    id: root

    view: LocaleSelectorListView {
        id: list

        Kirigami.Separator {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
        }
    }

    footer: Kirigami.FormLayout {
        id: formLayout

        // Shuffle's keys make no sound, do not vibrate and decide their own
        // capitals (docs/INPUT.md § Keys), so upstream's sound, vibration
        // and auto-capitalization switches are not offered: each would change
        // nothing.
        QQC2.CheckBox {
            id: keyboardNavigationEnabled
            Kirigami.FormData.label: i18n("General:")
            text: i18n("Keyboard navigation")

            checked: kcm.keyboardNavigationEnabled
            onCheckedChanged: {
                kcm.keyboardNavigationEnabled = checked;
                checked = Qt.binding(() => kcm.keyboardNavigationEnabled);
            }
        }
    }
}
