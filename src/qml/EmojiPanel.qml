pragma ComponentBehavior: Bound

/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick

// The emoji panel over the three upper rows: a row of categories above a grid
// that scrolls sideways. It only commits the characters it shows, each one a
// single code point, so every application receives exactly one character
// (docs/KEYBOARD-CONTRACT.md § 1.0 boundaries).
Item {
    id: root

    property real cellWidth: 80
    signal picked(string text)

    readonly property var categories: [
        ["Frequent", "👍😂🙏🔥✅👀🎉😅🤔💯🙌😊"],
        ["Smileys", "😀😃😄😁😆😅🤣😂🙂😉😊😇🥰😍🤩😘😋😛😜🤪🤨🧐🤓😎🥳😏😒😞😔😟😕🙁😣😖😫😩🥺😢😭😤😠😡🤯😳🥵🥶😱😨😰🤗🤭🤫🤥😶😐😑😬🙄😯😴🤤😪😵🤐🥴🤢🤮🤧😷🤒🤕"],
        ["People", "👋🤚✋🖖👌🤌🤏🤞🤟🤘🤙👈👉👆👇👍👎✊👊🤛🤜👏🙌👐🤲🤝🙏💪🧠👀👅👄"],
        ["Nature", "🐶🐱🐭🐹🐰🦊🐻🐼🐨🐯🦁🐮🐷🐸🐵🐔🐧🐦🦆🦉🐺🐗🐴🦄🐝🦋🐌🐞🌵🌲🌳🌴🌱🌿🍀🍁🍂🌸🌼🌻🌞🌝🌙⭐🌈⛅🌊"],
        ["Food", "🍏🍎🍐🍊🍋🍌🍉🍇🍓🫐🍒🍑🥭🍍🥥🥝🍅🥑🥦🌽🥕🧄🥐🍞🧀🥚🍳🥓🍔🍟🍕🌮🍣🍜🍪🎂☕🍵🍺🍷"],
        ["Objects", "⌚📱💻📷🎧🎮🔋🔌💡🔦📚📎🔒🔑🔨🧲🧪📦📅📌"],
        ["Symbols", "🧡💛💚💙💜🖤🤍💔💕✨⚡💥💫⭕❌❗❓➕➖➗🔴🟢🔵⚪⚫"]
    ]
    readonly property var entries: {
        const out = [];
        for (let c = 0; c < categories.length; ++c) {
            for (const ch of categories[c][1]) out.push({ text: ch, category: c });
        }
        return out;
    }
    function firstOf(category) {
        for (let i = 0; i < entries.length; ++i) {
            if (entries[i].category === category) return i;
        }
        return 0;
    }
    property int currentCategory: 0

    Row {
        id: tabs
        height: Math.round(root.height * 0.18)
        spacing: 6

        Repeater {
            model: root.categories

            Rectangle {
                id: tab
                required property var modelData
                required property int index
                width: label.implicitWidth + 32
                height: tabs.height
                radius: 8
                color: "transparent"
                border.width: 1
                border.color: root.currentCategory === index ? "#383838" : "transparent"

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: tab.modelData[0]
                    color: "#F8F8FF"
                    opacity: root.currentCategory === tab.index ? 0.9 : 0.55
                    font.pixelSize: Math.max(12, Math.min(tabs.height * 0.42, 18))
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.currentCategory = tab.index;
                        grid.positionViewAtIndex(root.firstOf(tab.index), GridView.Beginning);
                    }
                }
            }
        }
    }

    GridView {
        id: grid
        anchors.top: tabs.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        flow: GridView.FlowTopToBottom
        cellWidth: root.cellWidth
        // Rows as near square as the panel allows, never fewer than three: a
        // tall, narrow panel (a portrait screen) takes more rows rather than
        // stretching each cell into a column.
        cellHeight: Math.floor(height / Math.max(3, Math.floor(height / (root.cellWidth * 1.25))))
        boundsBehavior: Flickable.StopAtBounds
        model: root.entries
        onContentXChanged: {
            const index = indexAt(contentX + 1, 1);
            if (index >= 0) root.currentCategory = root.entries[index].category;
        }

        delegate: Item {
            id: cell
            required property var modelData
            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 8
                color: "#383838"
                opacity: tap.pressed ? 1 : 0
            }
            Text {
                anchors.centerIn: parent
                text: cell.modelData.text
                // No wider than its cell, so neighbours never overlap.
                font.pixelSize: Math.max(14, Math.min(cell.height * 0.5, cell.width * 0.75, 44))
            }
            MouseArea {
                id: tap
                anchors.fill: parent
                onClicked: root.picked(cell.modelData.text)
            }
        }
    }
}
