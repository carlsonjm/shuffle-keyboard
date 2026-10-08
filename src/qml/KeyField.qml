pragma ComponentBehavior: Bound

/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick

// The keys: the original footprint, twelve and a half units across and centred
// on the card, four rows, and one surface that reads every
// finger on them at once (docs/KEYBOARD-CONTRACT.md § Layout, docs/INPUT.md
// § Keys). It types nothing itself. What a touch means leaves as
// keyRequested, which the window hands to the input method.
Item {
    id: field

    property real keyGap: 8
    property real unitWidth: 100
    // An application that does not share its text: the delete scrub counts on
    // the key instead of selecting, and a word goes with Ctrl+W.
    property bool terminal: false
    // The colours every key, pop-up and panel in the field is drawn with. The
    // window gives the theme's; a field on its own is drawn dark.
    property KeysPalette colours: KeysPalette {}

    property string activeLayer: "letters"
    property bool shiftActive: false
    property bool capsActive: false
    property bool controlActive: false
    property bool altActive: false
    // Ctrl or Alt double-tapped stays on for every key until tapped again or
    // the keys go away, as a double-tapped Shift is Caps Lock.
    property bool controlLocked: false
    property bool altLocked: false
    property int markCount: 0
    readonly property bool caretMoving: caretCount > 0

    signal keyRequested(int key, string text, int modifiers)
    signal hideRequested()
    signal metaRequested()

    readonly property real totalUnits: 12.5
    readonly property real unitPitch: unitWidth + keyGap
    readonly property real rowHeight: (height - keyGap * 3) / 4
    implicitWidth: totalUnits * unitPitch - keyGap

    // Distances, from the key's own size so they hold at any scale.
    // A flick down fires at nearly half a key's height, as its grey character
    // finishes growing, so a thumb rolling as it lifts types the key itself.
    readonly property real flickDistance: rowHeight * 0.45
    readonly property real slideSlop: unitWidth * 0.1
    readonly property real caretSlide: unitWidth * 0.22
    readonly property real caretStepX: unitWidth * 0.15
    readonly property real caretStepY: rowHeight * 0.42
    readonly property real deleteStart: unitWidth * 0.13
    readonly property real deleteStep: unitWidth * 0.18
    readonly property real wordFlick: unitWidth * 0.33
    readonly property int caretHold: 320
    readonly property int accentHold: 460
    readonly property int deleteHold: 480
    readonly property int arrowHold: 430

    // Each mark's ANSI shift, typed by Shift and by a flick down.
    readonly property var ansiShift: ({
        ",": "<", ".": ">", "/": "?", "[": "{", "]": "}", "\\": "|", "`": "~",
        ";": ":", "'": "\"", "-": "_", "=": "+"
    })
    readonly property var flicks: Object.assign({
        q: "1", w: "2", e: "3", r: "4", t: "5", y: "6", u: "7", i: "8", o: "9", p: "0",
        a: "!", s: "@", d: "#", f: "$", g: "%", h: "^", j: "&", k: "*", l: "(",
        z: ")", x: "~", c: "`", v: "€", b: "£", n: "§", m: "…"
    }, ansiShift)
    readonly property var accents: ({
        a: "àáâäãåæ", e: "èéêëē", i: "ìíîï", o: "òóôöõøœ", u: "ùúûü",
        n: "ñń", c: "çć", s: "ßś", y: "ÿý"
    })

    // Rows as [kind, span] for the named keys, a string for a run of one-unit
    // character keys, and ["char", ch, span] for a wider character key.
    readonly property var bottomRow: [["ctrl", 1.5], ["alt", 1.5], ["space", 6.5], ["dot", 1.5], ["hide", 1.5]]
    readonly property var rowsByLayer: ({
        letters: [
            [["num", 1], "qwertyuiop", ["delete", 1.5]],
            [["tab", 1.25], "asdfghjkl", ["enter", 2.25]],
            [["shift", 1.75], "zxcvbnm,.", ["char", "/", 1.75]],
            bottomRow
        ],
        // The marks the letters leave out, each with its ANSI shift on a
        // flick down, as the letters carry theirs.
        symbols: [
            [["num", 1], "1234567890", ["delete", 1.5]],
            [["esc", 1.25], "-=[]\\;'`/", ["enter", 2.25]],
            [["emoji", 1.75], "!@#$%^&*(", ["char", ")", 1.75]],
            bottomRow
        ],
        // While emoji show, the bottom row's first key returns to the letters.
        emoji: [[], [], [], [["num", 1.5]].concat(bottomRow.slice(1))]
    })

    function buildKeys(layerName, pitch, rowH, gap) {
        const out = [];
        const rows = rowsByLayer[layerName];
        for (let r = 0; r < rows.length; ++r) {
            let column = 0;
            const y = r * (rowH + gap);
            for (const item of rows[r]) {
                if (typeof item === "string") {
                    for (const ch of item) {
                        out.push({ id: r + ":" + column, kind: "char", ch: ch, span: 1, row: r,
                                   x: column * pitch, y: y, w: pitch - gap, h: rowH });
                        column += 1;
                    }
                    continue;
                }
                if (item[0] === "char") {
                    out.push({ id: r + ":" + column, kind: "char", ch: item[1], span: item[2], row: r,
                               x: column * pitch, y: y, w: item[2] * pitch - gap, h: rowH });
                    column += item[2];
                    continue;
                }
                const kind = item[0], span = item[1];
                if (kind === "updown") {
                    // A ThinkPad's inverted T: ↑ over ↓ in one unit.
                    const half = (rowH - gap / 2) / 2;
                    out.push({ id: r + ":" + column + "u", kind: "up", span: 1, row: r,
                               x: column * pitch, y: y, w: pitch - gap, h: half });
                    out.push({ id: r + ":" + column + "d", kind: "down", span: 1, row: r,
                               x: column * pitch, y: y + half + gap / 2, w: pitch - gap, h: half });
                } else {
                    out.push({ id: r + ":" + column, kind: kind, span: span, row: r,
                               x: column * pitch, y: y, w: span * pitch - gap, h: rowH });
                }
                column += span;
            }
        }
        return out;
    }
    readonly property var keys: buildKeys(activeLayer, unitPitch, rowHeight, keyGap)

    function keyOfKind(kind) {
        for (const key of keys) {
            if (key.kind === kind) return key;
        }
        return null;
    }
    // The trackpad mark at the space bar's right end, which the window's
    // latch covers. A touch that begins on it is the latch's, not a space.
    readonly property rect markRect: {
        const space = keyOfKind("space");
        return space ? Qt.rect(space.x + space.w - space.h, space.y, space.h, space.h) : Qt.rect(0, 0, 0, 0);
    }

    // The Hide key, which stays live over the trackpad while it is latched.
    readonly property rect hideRect: {
        const hide = keyOfKind("hide");
        return hide ? Qt.rect(hide.x, hide.y, hide.w, hide.h) : Qt.rect(0, 0, 0, 0);
    }

    // A finger belongs to the key whose cell it lands in, gaps included.
    function keyAt(x, y) {
        const half = keyGap / 2;
        for (const key of keys) {
            if (x >= key.x - half && x < key.x + key.w + half && y >= key.y - half && y < key.y + key.h + half) {
                return key;
            }
        }
        return null;
    }
    function inside(key, x, y, slop) {
        return x >= key.x - slop && x <= key.x + key.w + slop && y >= key.y - slop && y <= key.y + key.h + slop;
    }

    // ---- What reaches the application ----

    function modifierMask(withShift) {
        return (withShift ? Qt.ShiftModifier : Qt.NoModifier)
             | (controlActive || controlLocked ? Qt.ControlModifier : Qt.NoModifier)
             | (altActive || altLocked ? Qt.AltModifier : Qt.NoModifier);
    }
    function keyCodeFor(text) {
        if (text === " ") return Qt.Key_Space;
        const code = text.toUpperCase().codePointAt(0);
        return code > 0xffff ? Qt.Key_unknown : code;
    }
    function clearOneShots() {
        shiftActive = false;
        controlActive = false;
        altActive = false;
    }
    // A character key. A flick types its character as it is and leaves a
    // pending Shift pending.
    function typeCharacter(ch, flicked) {
        const letter = /^[a-z]$/.test(ch);
        const upper = letter && !flicked && (shiftActive !== capsActive);
        const shiftedMark = !flicked && shiftActive && ansiShift[ch] !== undefined;
        const text = shiftedMark ? ansiShift[ch] : (upper ? ch.toUpperCase() : ch);
        keyRequested(keyCodeFor(text), text, modifierMask(upper || shiftedMark));
        controlActive = false;
        altActive = false;
        if (!flicked) shiftActive = false;
    }
    function typeText(text) {
        keyRequested(keyCodeFor(text), text, modifierMask(text !== text.toLowerCase()));
        clearOneShots();
    }
    function sendSpecial(key, text) {
        keyRequested(key, text, modifierMask(shiftActive));
        clearOneShots();
    }
    // A key leaves as a key press with its modifiers held whenever a modifier
    // must reach the application: any Ctrl or Alt chord, and Shift with a key
    // that types no letter (Go, Tab, Space, Esc, Delete, the caret's arrows).
    // Shift with a letter or mark is the shifted character itself, typed.
    function asShortcut(key, text, modifiers) {
        if (modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return true;
        return (modifiers & Qt.ShiftModifier) !== 0 && (text === "" || text === "\n" || text === "\t" || text === " ");
    }
    // Keys the gestures send step by step, which leave the modifiers alone.
    function sendStep(key, modifiers) {
        keyRequested(key, "", modifiers);
    }
    function deleteOne() {
        sendSpecial(Qt.Key_Backspace, "");
    }
    function deleteWord() {
        if (terminal) keyRequested(Qt.Key_W, "w", Qt.ControlModifier);
        else keyRequested(Qt.Key_Backspace, "", Qt.ControlModifier);
    }
    function arrow(kind) {
        sendSpecial({ left: Qt.Key_Left, up: Qt.Key_Up, down: Qt.Key_Down, right: Qt.Key_Right }[kind], "");
    }
    function tapShift() {
        const now = Date.now();
        if (capsActive) {
            capsActive = false;
            shiftActive = false;
        } else if (shiftActive && now - lastShiftTap < 350) {
            shiftActive = false;
            capsActive = true;
        } else {
            shiftActive = !shiftActive;
        }
        lastShiftTap = now;
    }
    property real lastShiftTap: 0

    function tapControl() {
        const now = Date.now();
        if (controlLocked) {
            controlLocked = false;
            controlActive = false;
        } else if (controlActive && now - lastControlTap < 350) {
            controlActive = false;
            controlLocked = true;
        } else {
            controlActive = !controlActive;
        }
        lastControlTap = now;
    }
    property real lastControlTap: 0

    function tapAlt() {
        const now = Date.now();
        if (altLocked) {
            altLocked = false;
            altActive = false;
        } else if (altActive && now - lastAltTap < 350) {
            altActive = false;
            altLocked = true;
        } else {
            altActive = !altActive;
        }
        lastAltTap = now;
    }
    property real lastAltTap: 0

    // The keys going away let go of a held Ctrl or Alt, so nothing hidden
    // turns the next typing into shortcuts.
    function releaseHolds() {
        controlLocked = false;
        altLocked = false;
    }

    function activate(key) {
        switch (key.kind) {
        case "char": typeCharacter(key.ch, false); break;
        case "space":
            if (shiftActive) sendSpecial(Qt.Key_Space, " ");
            else typeCharacter(" ", false);
            break;
        case "esc": sendSpecial(Qt.Key_Escape, ""); break;
        case "tab": sendSpecial(Qt.Key_Tab, ""); break;
        case "enter": sendSpecial(Qt.Key_Return, "\n"); break;
        case "delete": deleteOne(); break;
        case "shift": tapShift(); break;
        case "ctrl": tapControl(); break;
        case "alt": tapAlt(); break;
        case "num":
            activeLayer = activeLayer === "letters" ? "symbols" : "letters";
            clearOneShots();
            break;
        case "emoji": activeLayer = "emoji"; break;
        case "hide": hideRequested(); break;
        case "dot": metaRequested(); break;
        case "left": case "right": case "up": case "down": arrow(key.kind); break;
        }
    }
    function commitEmoji(text) {
        keyRequested(keyCodeFor(text), text, Qt.NoModifier);
    }

    // ---- Fingers ----

    property var touches: ({})
    property int touchRevision: 0
    property int activeCount: 0
    property int caretCount: 0
    // The accents for the key held, while they show.
    property var accentPopup: null

    function stateOn(keyId) {
        void touchRevision;
        for (const id in touches) {
            const state = touches[id];
            if (state.key && state.key.id === keyId && !state.done) return state;
        }
        return null;
    }

    function flickable(key) {
        // 123 sits where Esc does on a keyboard, and a flick down is Esc.
        if (key.kind === "num") return activeLayer === "letters" || activeLayer === "symbols";
        if (activeLayer === "symbols") return key.kind === "char" && ansiShift[key.ch] !== undefined;
        return activeLayer === "letters" && ((key.kind === "char" && flicks[key.ch] !== undefined)
                                       || key.kind === "left" || key.kind === "right");
    }
    // How far a flick has come, from 0 to 1. Only a move mostly downward
    // counts, so a slide sideways never grows the grey character.
    function flickProgress(state) {
        if (state.dy <= 0 || state.dy < Math.abs(state.dx) * 1.5) return 0;
        return Math.min(1, state.dy / flickDistance);
    }

    function press(point) {
        // A finger landing types whatever character another is still on, so
        // overlapping thumbs keep their order.
        for (const id in touches) {
            const other = touches[id];
            if (other.done || !other.key) continue;
            if ((other.key.kind === "char" && !other.popup && other.dy < flickDistance * 0.4)
                    || (other.key.kind === "space" && !other.caret && Math.abs(other.dx) < caretSlide)) {
                activate(other.key);
                other.done = true;
            }
        }
        const key = keyAt(point.x, point.y);
        const state = { key: key, x0: point.x, y0: point.y, lx: point.x, ly: point.y, dx: 0, dy: 0,
                        t0: Date.now(), ax: 0, ay: 0, flick: 0, caret: false, scrub: false,
                        repeating: false, nextRepeat: 0, repeats: 0, popup: false, done: !key };
        if (key && key.kind === "space" && point.x >= markRect.x) state.done = true;
        touches[point.pointId] = state;
        activeCount += 1;
        touchRevision += 1;
    }

    function move(point) {
        const state = touches[point.pointId];
        if (!state || state.done) return;
        const mx = point.x - state.lx, my = point.y - state.ly;
        state.lx = point.x;
        state.ly = point.y;
        state.dx = point.x - state.x0;
        state.dy = point.y - state.y0;
        const kind = state.key.kind;

        if (state.popup) {
            pickAccent(point.x);
        } else if (flickable(state.key) && !state.repeating) {
            state.flick = flickProgress(state);
        } else if (kind === "space") {
            if (!state.caret && Math.abs(state.dx) > caretSlide) beginCaret(state);
            if (state.caret) {
                state.ax += mx;
                state.ay += my;
                while (state.ax >= caretStepX) { sendStep(Qt.Key_Right, state.mods); state.ax -= caretStepX; }
                while (state.ax <= -caretStepX) { sendStep(Qt.Key_Left, state.mods); state.ax += caretStepX; }
                while (state.ay >= caretStepY) { sendStep(Qt.Key_Down, state.mods); state.ay -= caretStepY; }
                while (state.ay <= -caretStepY) { sendStep(Qt.Key_Up, state.mods); state.ay += caretStepY; }
            }
        } else if (kind === "delete" && !state.repeating) {
            if (state.dx < -deleteStart) state.scrub = true;
            if (state.scrub) {
                setMarks(state.dx < -deleteStart ? Math.floor((-state.dx - deleteStart) / deleteStep) + 1 : 0);
            }
        }
        touchRevision += 1;
    }

    function release(point) {
        const state = touches[point.pointId];
        if (!state) return;
        finish(point.pointId);
        if (state.done) return;
        const key = state.key;
        // A flickable key keeps a lift short of a flick below it, so a thumb
        // rolling down as it lifts types the key rather than nothing.
        const within = inside(key, point.x, point.y, slideSlop)
                    || (flickable(key) && point.y > key.y && point.y <= key.y + key.h + flickDistance
                        && inside(key, point.x, key.y, slideSlop));

        if (state.popup) {
            // Lifted on the accents or the key: the accent picked. Lifted
            // off them: nothing.
            const popup = accentPopup;
            accentPopup = null;
            const onAccents = popup && point.y >= popup.y - slideSlop && point.y <= key.y + key.h + slideSlop;
            if (onAccents && popup.pick >= 0) typeText(popup.chars[popup.pick]);
            return;
        }
        if (state.repeating) return;
        if (flickable(key) && flickProgress(state) >= 1) {
            if (key.kind === "char") typeCharacter(activeLayer === "symbols" ? ansiShift[key.ch] : flicks[key.ch], true);
            else if (key.kind === "num") sendSpecial(Qt.Key_Escape, "");
            else sendSpecial(key.kind === "left" ? Qt.Key_Home : Qt.Key_End, "");
            return;
        }
        if (key.kind === "space" && state.caret) {
            endCaret(state);
            return;
        }
        if (key.kind === "delete" && state.scrub) {
            const quick = Date.now() - state.t0 < 240 && state.dx < -wordFlick;
            if (quick) {
                collapseMarks();
                deleteWord();
            } else if (markCount > 0) {
                if (terminal) {
                    for (let i = 0; i < markCount; ++i) sendStep(Qt.Key_Backspace, Qt.NoModifier);
                } else {
                    sendStep(Qt.Key_Backspace, Qt.NoModifier);
                }
                markCount = 0;
            }
            return;
        }
        if (within) activate(key);
    }

    function cancel(point) {
        const state = touches[point.pointId];
        if (!state) return;
        finish(point.pointId);
        if (state.caret) endCaret(state);
        if (state.scrub) collapseMarks();
        if (state.popup) accentPopup = null;
    }

    function finish(pointId) {
        delete touches[pointId];
        activeCount = Math.max(0, activeCount - 1);
        touchRevision += 1;
    }

    // Time-held behaviour, read every frame while a finger is down.
    function tick() {
        const now = Date.now();
        for (const id in touches) {
            const state = touches[id];
            if (state.done) continue;
            const held = now - state.t0;
            const still = Math.hypot(state.dx, state.dy) < caretSlide;
            const kind = state.key.kind;
            if (kind === "space" && !state.caret && held >= caretHold && still) {
                beginCaret(state);
            } else if (kind === "char" && activeLayer === "letters" && accents[state.key.ch] && !state.popup
                       && held >= accentHold && still && state.dy < flickDistance * 0.4) {
                showAccents(state);
            } else if (kind === "delete" && !state.scrub && held >= deleteHold && still) {
                if (!state.repeating) {
                    state.repeating = true;
                    state.nextRepeat = now;
                }
                while (now >= state.nextRepeat) {
                    state.repeats += 1;
                    // By characters, then by words.
                    if (state.repeats <= 14) deleteOne();
                    else if (state.repeats % 3 === 0) deleteWord();
                    state.nextRepeat += 70;
                }
            } else if ((kind === "left" || kind === "right" || kind === "up" || kind === "down")
                       && held >= arrowHold && state.flick < 0.6 && still) {
                if (!state.repeating) {
                    state.repeating = true;
                    state.nextRepeat = now;
                    state.flick = 0;
                }
                while (now >= state.nextRepeat) {
                    arrow(kind);
                    state.nextRepeat += 52;
                }
            }
        }
    }

    // A pending Shift, Ctrl or Alt rides on every step, so Shift selects and
    // Ctrl moves by words, and lets go when the finger lifts.
    function beginCaret(state) {
        state.caret = true;
        state.mods = modifierMask(shiftActive);
        caretCount += 1;
    }
    function endCaret(state) {
        if (!state.caret) return;
        state.caret = false;
        caretCount = Math.max(0, caretCount - 1);
        if (state.mods !== Qt.NoModifier) clearOneShots();
    }

    // Marks are a selection grown with Shift+Left, so the application shows
    // exactly what lifting deletes; a terminal has none, and counts.
    function setMarks(count) {
        count = Math.max(0, count);
        if (!terminal) {
            for (let i = markCount; i < count; ++i) sendStep(Qt.Key_Left, Qt.ShiftModifier);
            for (let i = markCount; i > count; --i) sendStep(Qt.Key_Right, Qt.ShiftModifier);
        }
        markCount = count;
    }
    function collapseMarks() {
        if (!terminal && markCount > 0) sendStep(Qt.Key_Right, Qt.NoModifier);
        markCount = 0;
    }

    function showAccents(state) {
        const upper = shiftActive !== capsActive;
        const chars = Array.from(accents[state.key.ch]).map(c => upper ? c.toUpperCase() : c);
        const cellWidth = unitWidth * 0.78, cellHeight = rowHeight * 0.8, pad = 6;
        const width = chars.length * cellWidth + pad * 2;
        const x = Math.max(0, Math.min(field.width - width, state.key.x + state.key.w / 2 - width / 2));
        // Wholly above the key held, so the finger on it never covers them.
        // Over the top row they reach past the card, over the window above,
        // for as long as the key is held.
        const y = state.key.y - cellHeight - pad * 2 - 6;
        state.popup = true;
        accentPopup = { chars: chars, x: x, y: y, cellWidth: cellWidth, cellHeight: cellHeight, pad: pad, pick: -1 };
        pickAccent(state.lx);
    }
    function pickAccent(x) {
        if (!accentPopup) return;
        const p = accentPopup;
        const pick = Math.max(0, Math.min(p.chars.length - 1, Math.floor((x - p.x - p.pad) / p.cellWidth)));
        if (pick !== p.pick) accentPopup = Object.assign({}, p, { pick: pick });
    }

    Timer {
        interval: 16
        repeat: true
        running: field.activeCount > 0
        onTriggered: field.tick()
    }

    // ---- Drawing ----

    function labelFor(key) {
        switch (key.kind) {
        case "char": return /^[a-z]$/.test(key.ch) && (shiftActive !== capsActive) ? key.ch.toUpperCase() : key.ch;
        case "esc": return "Esc";
        case "tab": return "Tab";
        case "enter": return "Go";
        case "shift": return "Shift";
        case "ctrl": return "Ctrl";
        case "alt": return "Alt";
        case "space": return "Space";
        case "num": return activeLayer === "letters" ? "123" : "ABC";
        case "delete": return terminal && markCount > 0 ? String(markCount) : "";
        }
        return "";
    }
    function glyphFor(key) {
        if (key.kind === "delete") return terminal && markCount > 0 ? "" : "delete";
        if (key.kind === "emoji") return "emoji";
        if (["left", "right", "up", "down", "hide"].indexOf(key.kind) >= 0) return key.kind;
        return "";
    }
    function secondaryFor(key) {
        if (key.kind === "num") return activeLayer === "letters" || activeLayer === "symbols" ? "Esc" : "";
        if (activeLayer === "symbols") return key.kind === "char" ? (ansiShift[key.ch] || "") : "";
        if (activeLayer !== "letters") return "";
        if (key.kind === "char") return flicks[key.ch] || "";
        if (key.kind === "left") return "Home";
        if (key.kind === "right") return "End";
        return "";
    }

    Repeater {
        model: field.keys

        KeyCap {
            id: cap
            required property var modelData
            readonly property var touch: field.stateOn(modelData.id)
            colours: field.colours
            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h
            label: field.labelFor(modelData)
            glyph: field.glyphFor(modelData)
            secondaryLabel: field.secondaryFor(modelData)
            dotGlyph: modelData.kind === "dot"
            wordLabel: modelData.kind !== "char" && modelData.kind !== "delete"
            down: touch !== null
            flick: {
                void field.touchRevision;
                return touch ? touch.flick : 0;
            }
            active: (modelData.kind === "shift" && field.shiftActive && !field.capsActive)
                    || (modelData.kind === "ctrl" && field.controlActive)
                    || (modelData.kind === "alt" && field.altActive)
                    || (modelData.kind === "num" && field.activeLayer !== "letters")
            locked: (modelData.kind === "shift" && field.capsActive)
                    || (modelData.kind === "ctrl" && field.controlLocked)
                    || (modelData.kind === "alt" && field.altLocked)
            emphasised: modelData.kind === "enter"
            quiet: field.caretMoving

            Accessible.role: Accessible.Button
            Accessible.name: modelData.kind === "hide" ? qsTr("Put the keyboard away") : label
            Accessible.onPressAction: field.activate(modelData)

            // The trackpad mark at the space bar's right end.
            Rectangle {
                visible: cap.modelData.kind === "space"
                anchors.right: parent.right
                anchors.rightMargin: (parent.height - width) / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 14
                radius: 3
                color: "transparent"
                border.width: 1.5
                border.color: field.colours.ink
                opacity: 0.55
            }
        }
    }

    MultiPointTouchArea {
        id: surface
        anchors.fill: parent
        z: 1
        maximumTouchPoints: 10
        onPressed: points => { for (const point of points) field.press(point); }
        onUpdated: points => { for (const point of points) field.move(point); }
        onReleased: points => { for (const point of points) field.release(point); }
        onCanceled: points => { for (const point of points) field.cancel(point); }
    }

    EmojiPanel {
        z: 2
        visible: field.activeLayer === "emoji"
        x: 0
        y: 0
        width: field.width
        height: field.rowHeight * 3 + field.keyGap * 2
        cellWidth: field.unitWidth * 0.8
        colours: field.colours
        onPicked: text => field.commitEmoji(text)
    }

    // The accents, above the key held.
    Rectangle {
        z: 3
        visible: field.accentPopup !== null
        x: field.accentPopup ? field.accentPopup.x : 0
        y: field.accentPopup ? field.accentPopup.y : 0
        width: field.accentPopup ? field.accentPopup.chars.length * field.accentPopup.cellWidth + field.accentPopup.pad * 2 : 0
        height: field.accentPopup ? field.accentPopup.cellHeight + field.accentPopup.pad * 2 : 0
        radius: 10
        color: field.colours.raised
        border.width: 1
        border.color: field.colours.raisedEdge

        Row {
            x: field.accentPopup ? field.accentPopup.pad : 0
            y: x
            Repeater {
                model: field.accentPopup ? field.accentPopup.chars : []
                Rectangle {
                    id: accentCell
                    required property string modelData
                    required property int index
                    readonly property bool picked: field.accentPopup !== null && field.accentPopup.pick === index
                    width: field.accentPopup ? field.accentPopup.cellWidth : 0
                    height: field.accentPopup ? field.accentPopup.cellHeight : 0
                    radius: 7
                    color: picked ? field.colours.ink : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: accentCell.modelData
                        color: accentCell.picked ? field.colours.ground : field.colours.ink
                        font.pixelSize: Math.max(14, Math.min(parent.height * 0.4, 30))
                    }
                }
            }
        }
    }
}
