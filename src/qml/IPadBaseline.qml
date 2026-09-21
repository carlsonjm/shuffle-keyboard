pragma ComponentBehavior: Bound

/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.VirtualKeyboard
import QtQuick.VirtualKeyboard.Settings

import org.kde.plasma.keyboard

InputPanelWindow {
    id: root

    width: Screen.width
    height: Screen.height
    color: "transparent"

    property bool shiftActive: false
    property bool capsActive: false
    property bool symbolLayer: false
    property real dragStartY: 0
    property real dragStartHeight: 0
    property bool resizeMoved: false
    property real requestedHeight: PlasmaKeyboardSettings.keyboardHeight

    readonly property real minimumPanelHeight: Math.min(300, root.height * 0.5)
    readonly property real maximumPanelHeight: Math.max(minimumPanelHeight, Math.min(720, root.height * 0.72))
    readonly property real panelHeight: Math.round(Math.max(minimumPanelHeight, Math.min(maximumPanelHeight, requestedHeight)))
    readonly property real outerGap: Math.max(5, Math.min(9, panelHeight * 0.018))
    readonly property real keyGap: Math.max(4, Math.min(8, panelHeight * 0.014))
    // Establish the character grid first, then let function keys consume the
    // remaining edges. This preserves a physical-keyboard stagger without
    // changing the pitch from row to row:
    // Q starts at 1.00, A at 1.25, and Z at 1.75 units.
    readonly property real totalUnits: 13.5

    readonly property var qRow: [
        { primary: "tab", kind: "tab", weight: 1, special: true },
        { primary: "q", value: "q", weight: 1 }, { primary: "w", value: "w", weight: 1 },
        { primary: "e", value: "e", weight: 1 }, { primary: "r", value: "r", weight: 1 },
        { primary: "t", value: "t", weight: 1 }, { primary: "y", value: "y", weight: 1 },
        { primary: "u", value: "u", weight: 1 }, { primary: "i", value: "i", weight: 1 },
        { primary: "o", value: "o", weight: 1 }, { primary: "p", value: "p", weight: 1 },
        { primary: "delete", kind: "backspace", weight: 2.5, special: true }
    ]

    readonly property var homeRow: [
        { primary: "caps lock", kind: "caps", weight: 1.25, special: true },
        { primary: "a", value: "a", weight: 1 }, { primary: "s", value: "s", weight: 1 },
        { primary: "d", value: "d", weight: 1 }, { primary: "f", value: "f", weight: 1 },
        { primary: "g", value: "g", weight: 1 }, { primary: "h", value: "h", weight: 1 },
        { primary: "j", value: "j", weight: 1 }, { primary: "k", value: "k", weight: 1 },
        { primary: "l", value: "l", weight: 1 },
        { primary: "go", kind: "enter", weight: 3.25, special: true, accent: true }
    ]

    readonly property var lowerRow: [
        { primary: "shift", kind: "shift", weight: 1.75, special: true },
        { primary: "z", value: "z", weight: 1 }, { primary: "x", value: "x", weight: 1 },
        { primary: "c", value: "c", weight: 1 }, { primary: "v", value: "v", weight: 1 },
        { primary: "b", value: "b", weight: 1 }, { primary: "n", value: "n", weight: 1 },
        { primary: "m", value: "m", weight: 1 },
        { primary: ",", secondary: "<", value: ",", shifted: "<", weight: 1 },
        { primary: ".", secondary: ">", value: ".", shifted: ">", weight: 1 },
        { primary: "/", secondary: "?", value: "/", shifted: "?", weight: 1 },
        { primary: "shift", kind: "shift", weight: 1.75, special: true }
    ]

    readonly property var bottomRow: [
        { primary: "☺", kind: "inactive", weight: 1.25, special: true },
        { primary: ".?123", kind: "layer", weight: 1.25, special: true },
        { primary: "🎙", kind: "inactive", weight: 1.25, special: true },
        { primary: "", kind: "space", weight: 5.75 },
        { primary: ".com", kind: "dotcom", weight: 1 },
        { primary: ".?123", kind: "layer", weight: 1.25, special: true },
        { primary: "⌨⌄", kind: "hide", weight: 1.75, special: true }
    ]

    readonly property var symbolQRow: [
        { primary: "#+=", kind: "inactive", weight: 1, special: true },
        { primary: "1", value: "1", weight: 1 }, { primary: "2", value: "2", weight: 1 },
        { primary: "3", value: "3", weight: 1 }, { primary: "4", value: "4", weight: 1 },
        { primary: "5", value: "5", weight: 1 }, { primary: "6", value: "6", weight: 1 },
        { primary: "7", value: "7", weight: 1 }, { primary: "8", value: "8", weight: 1 },
        { primary: "9", value: "9", weight: 1 }, { primary: "0", value: "0", weight: 1 },
        { primary: "delete", kind: "backspace", weight: 2.5, special: true }
    ]

    readonly property var symbolHomeRow: [
        { primary: "#+=", kind: "inactive", weight: 1.25, special: true },
        { primary: "@", value: "@", weight: 1 }, { primary: "#", value: "#", weight: 1 },
        { primary: "$", value: "$", weight: 1 }, { primary: "&", value: "&", weight: 1 },
        { primary: "*", value: "*", weight: 1 }, { primary: "(", value: "(", weight: 1 },
        { primary: ")", value: ")", weight: 1 }, { primary: "'", value: "'", weight: 1 },
        { primary: "\"", value: "\"", weight: 1 },
        { primary: "go", kind: "enter", weight: 3.25, special: true, accent: true }
    ]

    readonly property var symbolLowerRow: [
        { primary: "ABC", kind: "layer", weight: 1.75, special: true },
        { primary: "%", value: "%", weight: 1 }, { primary: "-", value: "-", weight: 1 },
        { primary: "+", value: "+", weight: 1 }, { primary: "=", value: "=", weight: 1 },
        { primary: "/", value: "/", weight: 1 }, { primary: ";", value: ";", weight: 1 },
        { primary: ":", value: ":", weight: 1 }, { primary: "!", value: "!", weight: 1 },
        { primary: "?", value: "?", weight: 1 }, { primary: ",", value: ",", weight: 1 },
        { primary: "ABC", kind: "layer", weight: 1.75, special: true }
    ]

    readonly property var activeQRow: symbolLayer ? symbolQRow : qRow
    readonly property var activeHomeRow: symbolLayer ? symbolHomeRow : homeRow
    readonly property var activeLowerRow: symbolLayer ? symbolLowerRow : lowerRow

    Component.onCompleted: symbolLayer = shuffleProbeLayer > 0

    interactiveRegion: Qt.rect(panel.x, panel.y, panel.width, panel.height)

    function keyCode(text) {
        if (text === " ") return Qt.Key_Space;
        return text.toUpperCase().charCodeAt(0);
    }

    function updateLocales() {
        let locale = Qt.locale().name;
        if (locale === "C") locale = "en_US";
        VirtualKeyboardSettings.activeLocales = PlasmaKeyboardSettings.enabledLocales.length > 0
                                              ? PlasmaKeyboardSettings.enabledLocales : [locale];
    }

    function sendText(text) {
        const uppercase = text.length === 1 && text >= "a" && text <= "z"
                          && (shiftActive || capsActive);
        const output = uppercase ? text.toUpperCase() : text;
        inputEngine.InputContext.inputEngine.virtualKeyClick(keyCode(output), output,
                                                             uppercase ? Qt.ShiftModifier : Qt.NoModifier);
        shiftActive = false;
    }

    function sendString(text) {
        for (let index = 0; index < text.length; ++index) sendText(text.charAt(index));
    }

    function triggerKey(key) {
        const kind = key.kind || "text";
        if (kind === "backspace") inputEngine.InputContext.inputEngine.virtualKeyClick(Qt.Key_Backspace, "", Qt.NoModifier);
        else if (kind === "tab") inputEngine.InputContext.inputEngine.virtualKeyClick(Qt.Key_Tab, "\t", Qt.NoModifier);
        else if (kind === "enter") inputEngine.InputContext.inputEngine.virtualKeyClick(Qt.Key_Return, "\n", Qt.NoModifier);
        else if (kind === "caps") capsActive = !capsActive;
        else if (kind === "shift") shiftActive = !shiftActive;
        else if (kind === "layer") {
            symbolLayer = !symbolLayer;
            shiftActive = false;
        }
        else if (kind === "space") sendText(" ");
        else if (kind === "dotcom") sendString(".com");
        else if (kind === "hide") Qt.inputMethod.hide();
        else if (kind === "inactive") return;
        else sendText(shiftActive && key.shifted ? key.shifted : key.value);
    }

    onPanelHeightChanged: Qt.callLater(refreshInteractiveRegion)

    BottomSurfaceCoordinator {
        requestedVisible: Qt.inputMethod.visible
        onReservationRefreshRequested: Qt.callLater(root.refreshInteractiveRegion)
    }

    InputPanel {
        id: inputEngine
        x: -2
        y: -2
        width: 1
        height: 1
        opacity: 0
        focusPolicy: Qt.NoFocus
        Component.onCompleted: root.updateLocales()
    }

    Connections {
        target: PlasmaKeyboardSettings
        function onEnabledLocalesChanged() { root.updateLocales(); }
    }

    InputListenerItem {
        id: thing
        focus: true
        engine: inputEngine.InputContext.inputEngine
    }

    Rectangle {
        id: panel
        x: 0
        y: root.height - height
        width: root.width
        height: root.panelHeight
        color: "#D1D3D9"

        Rectangle {
            id: resizeHandle
            z: 20
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: 82
            height: 20
            color: "transparent"

            Rectangle {
                anchors.centerIn: parent
                width: 42
                height: 4
                radius: 2
                color: "#7D828A"
                opacity: 0.7
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeVerCursor
                onPressed: mouse => {
                    root.dragStartY = mouse.y;
                    root.dragStartHeight = root.panelHeight;
                    root.resizeMoved = false;
                }
                onPositionChanged: mouse => {
                    if (!pressed) return;
                    if (Math.abs(mouse.y - root.dragStartY) > 4) root.resizeMoved = true;
                    root.requestedHeight = root.dragStartHeight + root.dragStartY - mouse.y;
                }
                onReleased: root.persistKeyboardHeight(root.panelHeight)
                onClicked: {
                    if (!root.resizeMoved) Qt.inputMethod.hide();
                }
            }
        }

        Item {
            id: keyboardBody
            anchors.fill: parent
            anchors.topMargin: 20
            anchors.leftMargin: root.outerGap
            anchors.rightMargin: root.outerGap
            anchors.bottomMargin: root.outerGap

            readonly property real rowHeight: (height - root.keyGap * 3) / 4

            component BaselineRow: Row {
                required property var keyModel
                property real pitch: (width + root.keyGap) / root.totalUnits
                spacing: root.keyGap

                Repeater {
                    model: parent.keyModel

                    IPadKey {
                        required property var modelData
                        width: modelData.weight * parent.pitch - root.keyGap
                        height: parent.height
                        primaryLabel: {
                            if (modelData.kind === "layer") return root.symbolLayer ? "ABC" : modelData.primary;
                            if (modelData.value && modelData.value >= "a" && modelData.value <= "z"
                                    && (root.shiftActive || root.capsActive)) return modelData.primary.toUpperCase();
                            return modelData.primary;
                        }
                        secondaryLabel: modelData.secondary || ""
                        special: modelData.special || false
                        accent: modelData.accent || false
                        active: (modelData.kind === "shift" && root.shiftActive)
                                || (modelData.kind === "caps" && root.capsActive)
                        repeat: modelData.kind === "backspace"
                        onTriggered: root.triggerKey(modelData)
                    }
                }
            }

            BaselineRow {
                x: 0
                y: 0
                width: parent.width
                height: keyboardBody.rowHeight
                keyModel: root.activeQRow
            }

            BaselineRow {
                x: 0
                y: keyboardBody.rowHeight + root.keyGap
                width: parent.width
                height: keyboardBody.rowHeight
                keyModel: root.activeHomeRow
            }

            BaselineRow {
                x: 0
                y: (keyboardBody.rowHeight + root.keyGap) * 2
                width: parent.width
                height: keyboardBody.rowHeight
                keyModel: root.activeLowerRow
            }

            BaselineRow {
                x: 0
                y: (keyboardBody.rowHeight + root.keyGap) * 3
                width: parent.width
                height: keyboardBody.rowHeight
                keyModel: root.bottomRow
            }
        }
    }
}
