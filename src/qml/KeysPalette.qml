/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick

// Every colour the keys draw with. Dark keys keep the values they have always
// had; light keys take their ground and ink from the Plasma style's colours,
// which KeysTheme reads, and mix every other tone from those two, so the ink
// is the one colour that has to read on the ground. Whether the keys are light
// is decided once, as a whole, so a key's ink and its ground can never come
// from different looks.
QtObject {
    property bool light: false
    // The Plasma style's window ground and text, and the ground of a view
    // inside it, which the accents' pop-up stands on.
    property color themeGround: "#E0E0E0"
    property color themeInk: "#102729"
    property color themeRaised: "#FFFFFF"

    // The card the keys sit on, and what is drawn on a lit key.
    readonly property color ground: light ? themeGround : "#141414"
    // Labels, marks and a lit key's face.
    readonly property color ink: light ? themeInk : "#F8F8FF"
    // The card's own edge.
    readonly property color edge: light ? mix(0.18) : "#333333"
    // Each key's outline, and a key held down.
    readonly property color outline: light ? mix(0.2) : "#383838"
    // The accents' pop-up, raised above the keys.
    readonly property color raised: light ? themeRaised : "#26272B"
    readonly property color raisedEdge: light ? mix(0.26) : "#44464C"
    // The trackpad, set into the card.
    readonly property color recessed: light ? mix(0.06) : "#12151A"
    readonly property color recessedEdge: light ? mix(0.2) : "#30353C"
    readonly property color recessedInk: light ? themeInk : "#F8F8F4"

    // The ink at a strength, for washes over the ground.
    function wash(alpha: real): color {
        return Qt.rgba(ink.r, ink.g, ink.b, alpha);
    }
    function mix(alpha: real): color {
        return Qt.tint(ground, wash(alpha));
    }
}
