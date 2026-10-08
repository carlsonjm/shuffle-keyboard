/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtTest
import "../../src/qml"

// The keys' colours: dark exactly as they have always been, and light ones
// whose every label reads on what it is drawn on.
Item {
    KeysPalette { id: dark }
    KeysPalette { id: light; light: true }
    // A light style whose views are darker than its window still gives the
    // accents' pop-up a ground its ink reads on.
    KeysPalette { id: breeze; light: true; themeGround: "#EFF0F1"; themeInk: "#232629"; themeRaised: "#FFFFFF" }

    TestCase {
        name: "KeysPalette"

        function luminance(c) {
            const linear = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
            return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b);
        }
        function contrast(a, b) {
            const la = luminance(a), lb = luminance(b);
            return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
        }

        function test_darkIsUnchanged() {
            compare(String(dark.ground), "#141414");
            compare(String(dark.ink), "#f8f8ff");
            compare(String(dark.edge), "#333333");
            compare(String(dark.outline), "#383838");
            compare(String(dark.raised), "#26272b");
            compare(String(dark.raisedEdge), "#44464c");
            compare(String(dark.recessed), "#12151a");
            compare(String(dark.recessedEdge), "#30353c");
            compare(String(dark.recessedInk), "#f8f8f4");
            compare(String(dark.wash(0xB3 / 255)), "#b3f8f8ff");
        }

        function test_lightReads_data() {
            return [{ tag: "Shuffle Light", p: light }, { tag: "Breeze", p: breeze }];
        }
        function test_lightReads(data) {
            const p = data.p;
            verify(luminance(p.ground) > luminance(p.ink));
            // Labels on the card, on a key held down, on the pop-up and on the trackpad.
            verify(contrast(p.ink, p.ground) >= 4.5);
            verify(contrast(p.ink, p.outline) >= 4.5);
            verify(contrast(p.ink, p.raised) >= 4.5);
            verify(contrast(p.recessedInk, p.recessed) >= 4.5);
            // A lit key's label is the ground on the ink.
            verify(contrast(p.ground, Qt.tint(p.ground, p.wash(0xB3 / 255))) >= 3);
        }
    }
}
