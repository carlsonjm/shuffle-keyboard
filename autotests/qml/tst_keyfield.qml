/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtTest
import "../../src/qml"

// The key field against docs/KEYBOARD-CONTRACT.md § Layout and docs/INPUT.md
// § Keys, § Flicks, § Caret trackpad and § Delete, driven by touch.
Item {
    id: window
    width: 1800
    height: 500

    KeyField {
        id: field
        x: 40
        y: 40
        unitWidth: 100
        keyGap: 8
        width: implicitWidth
        height: 4 * 100 + 3 * 8
    }

    SignalSpy { id: sent; target: field; signalName: "keyRequested" }
    SignalSpy { id: hidden; target: field; signalName: "hideRequested" }
    SignalSpy { id: meta; target: field; signalName: "metaRequested" }

    TestCase {
        name: "KeyField"
        when: windowShown

        function init() {
            field.activeLayer = "letters";
            field.shiftActive = false;
            field.capsActive = false;
            field.controlActive = false;
            field.altActive = false;
            field.terminal = false;
            field.markCount = 0;
            field.lastShiftTap = 0;
            sent.clear();
            hidden.clear();
            meta.clear();
        }

        function find(kind, ch) {
            for (const key of field.keys) {
                if (key.kind === kind && (ch === undefined || key.ch === ch)) return key;
            }
            fail("no key " + kind + " " + ch);
        }
        function centre(key) { return Qt.point(key.x + key.w / 2, key.y + key.h / 2); }
        function tap(key) {
            const c = centre(key);
            touchEvent(field).press(0, field, c.x, c.y).commit();
            touchEvent(field).release(0, field, c.x, c.y).commit();
        }
        function tapChar(ch) { tap(find("char", ch)); }
        function texts() {
            const out = [];
            for (let i = 0; i < sent.count; ++i) out.push(sent.signalArguments[i][1]);
            return out;
        }
        function keysSent() {
            const out = [];
            for (let i = 0; i < sent.count; ++i) out.push([sent.signalArguments[i][0], sent.signalArguments[i][2]]);
            return out;
        }

        // ---- Layout ----

        function test_rows_begin_on_the_stagger() {
            const pitch = field.unitPitch;
            compare(find("char", "q").x / pitch, 1.5);
            compare(find("char", "a").x / pitch, 1.75);
            compare(find("char", "z").x / pitch, 2.25);
            compare(field.implicitWidth, 16 * pitch - field.keyGap);
        }

        function test_every_character_key_is_one_unit() {
            for (const key of field.keys) {
                if (key.kind === "char") compare(key.w, field.unitWidth, key.ch);
            }
        }

        function test_right_edge_is_shared() {
            const edge = k => k.x + k.w;
            const right = edge(find("delete"));
            compare(edge(find("enter")), right);
            compare(edge(field.keys.filter(k => k.kind === "shift")[1]), right);
            compare(edge(find("right")), right);
            compare(right, field.implicitWidth);
        }

        function test_rows_read_as_the_contract() {
            const row = r => field.keys.filter(k => k.row === r).map(k => k.kind === "char" ? k.ch : k.kind).join(" ");
            compare(row(0), "esc q w e r t y u i o p [ ] \\ delete");
            compare(row(1), "tab a s d f g h j k l ; ' - enter");
            compare(row(2), "shift z x c v b n m , . / = shift");
            compare(row(3), "ctrl dot alt emoji space num hide left up down right");
        }

        function test_up_and_down_share_one_unit() {
            const up = find("up"), down = find("down");
            compare(up.x, down.x);
            compare(up.w, field.unitWidth);
            verify(up.h < field.rowHeight / 2);
            compare(down.y + down.h, up.y + field.rowHeight);
        }

        // ---- Keys ----

        function test_tap_types_on_lift() {
            const c = centre(find("char", "q"));
            touchEvent(field).press(0, field, c.x, c.y).commit();
            compare(sent.count, 0);
            touchEvent(field).release(0, field, c.x, c.y).commit();
            compare(texts(), ["q"]);
            compare(sent.signalArguments[0][0], Qt.Key_Q);
        }

        function test_overlapping_thumbs_keep_their_order() {
            const a = centre(find("char", "a")), s = centre(find("char", "s"));
            touchEvent(field).press(0, field, a.x, a.y).commit();
            touchEvent(field).stationary(0).press(1, field, s.x, s.y).commit();
            compare(texts(), ["a"]);
            touchEvent(field).release(0, field, a.x, a.y).stationary(1).commit();
            compare(texts(), ["a"]);
            touchEvent(field).release(1, field, s.x, s.y).commit();
            compare(texts(), ["a", "s"]);
        }

        function test_slide_off_types_nothing() {
            const q = centre(find("char", "q"));
            touchEvent(field).press(0, field, q.x, q.y).commit();
            touchEvent(field).move(0, field, q.x + 300, q.y).commit();
            touchEvent(field).release(0, field, q.x + 300, q.y).commit();
            compare(sent.count, 0);
        }

        function test_shift_capitalises_and_lets_go() {
            tap(find("shift"));
            verify(field.shiftActive);
            tapChar("g");
            tapChar("g");
            compare(texts(), ["G", "g"]);
            compare(sent.signalArguments[0][2], Qt.ShiftModifier);
        }

        function test_shift_types_each_marks_ansi_shift() {
            const marks = { ",": "<", ".": ">", "/": "?", "[": "{", "]": "}", "\\": "|", ";": ":", "'": "\"", "-": "_", "=": "+" };
            for (const mark in marks) {
                tap(find("shift"));
                field.lastShiftTap = 0;
                tapChar(mark);
            }
            compare(texts(), Object.keys(marks).map(m => marks[m]));
        }

        function test_double_shift_is_caps_lock_on_either_side() {
            const right = field.keys.filter(k => k.kind === "shift")[1];
            tap(right);
            tap(right);
            verify(field.capsActive);
            tapChar("a");
            tapChar("b");
            compare(texts(), ["A", "B"]);
            tap(right);
            verify(!field.capsActive && !field.shiftActive);
        }

        function test_ctrl_makes_a_chord() {
            tap(find("ctrl"));
            tapChar("c");
            compare(sent.signalArguments[0][0], Qt.Key_C);
            compare(sent.signalArguments[0][2], Qt.ControlModifier);
            verify(!field.controlActive);
        }

        function test_go_tab_and_esc() {
            tap(find("enter"));
            tap(find("tab"));
            tap(find("esc"));
            compare(keysSent().map(k => k[0]), [Qt.Key_Return, Qt.Key_Tab, Qt.Key_Escape]);
        }

        function test_arrows_and_shift_selection() {
            tap(find("left"));
            tap(find("up"));
            tap(find("shift"));
            tap(find("right"));
            tap(find("down"));
            compare(keysSent(), [[Qt.Key_Left, 0], [Qt.Key_Up, 0], [Qt.Key_Right, Qt.ShiftModifier], [Qt.Key_Down, 0]]);
        }

        function test_held_arrow_repeats() {
            const c = centre(find("right"));
            touchEvent(field).press(0, field, c.x, c.y).commit();
            wait(700);
            touchEvent(field).release(0, field, c.x, c.y).commit();
            verify(sent.count >= 3, "repeated " + sent.count);
            verify(keysSent().every(k => k[0] === Qt.Key_Right));
        }

        function test_hide_and_tette_dot() {
            tap(find("hide"));
            tap(find("dot"));
            compare(hidden.count, 1);
            compare(meta.count, 1);
            compare(sent.count, 0);
        }

        // ---- Layers ----

        function test_symbols_layer() {
            tap(find("num"));
            compare(field.activeLayer, "symbols");
            compare(field.labelFor(find("num")), "ABC");
            tapChar("1");
            tap(find("left"));
            tap(find("up"));
            tap(find("down"));
            tap(find("right"));
            tap(find("delete"));
            compare(keysSent().map(k => k[0]),
                    ["1".charCodeAt(0), Qt.Key_Home, Qt.Key_PageUp, Qt.Key_PageDown, Qt.Key_End, Qt.Key_Delete]);
            tap(find("num"));
            compare(field.activeLayer, "letters");
        }

        function test_emoji_panel_replaces_the_upper_rows() {
            tap(find("emoji"));
            compare(field.activeLayer, "emoji");
            compare(field.keys.filter(k => k.row < 3).length, 0);
            compare(field.labelFor(find("emoji")), "ABC");
            tap(find("emoji"));
            compare(field.activeLayer, "letters");
        }

        // ---- Flicks ----

        function test_flick_types_the_grey_character() {
            const q = centre(find("char", "q"));
            touchEvent(field).press(0, field, q.x, q.y).commit();
            touchEvent(field).move(0, field, q.x, q.y + field.flickDistance).commit();
            touchEvent(field).release(0, field, q.x, q.y + field.flickDistance).commit();
            compare(texts(), ["1"]);
        }

        function test_flick_leaves_shift_pending() {
            tap(find("shift"));
            const sc = centre(find("char", ";"));
            touchEvent(field).press(0, field, sc.x, sc.y).commit();
            touchEvent(field).move(0, field, sc.x, sc.y + field.flickDistance).commit();
            touchEvent(field).release(0, field, sc.x, sc.y + field.flickDistance).commit();
            compare(texts(), [":"]);
            verify(field.shiftActive);
        }

        function test_short_flick_is_a_tap() {
            const w = centre(find("char", "w"));
            touchEvent(field).press(0, field, w.x, w.y).commit();
            touchEvent(field).move(0, field, w.x, w.y + field.flickDistance * 0.3).commit();
            touchEvent(field).release(0, field, w.x, w.y + field.flickDistance * 0.3).commit();
            compare(texts(), ["w"]);
        }

        function test_arrow_flicks_are_home_and_end() {
            for (const kind of ["left", "right"]) {
                const c = centre(find(kind));
                touchEvent(field).press(0, field, c.x, c.y - 20).commit();
                touchEvent(field).move(0, field, c.x, c.y - 20 + field.flickDistance).commit();
                touchEvent(field).release(0, field, c.x, c.y - 20 + field.flickDistance).commit();
            }
            compare(keysSent().map(k => k[0]), [Qt.Key_Home, Qt.Key_End]);
        }

        // ---- Accents ----

        function test_held_vowel_offers_accents() {
            const e = find("char", "e");
            const c = centre(e);
            touchEvent(field).press(0, field, c.x, c.y).commit();
            wait(600);
            verify(field.accentPopup !== null);
            const p = field.accentPopup;
            // Above the key held, even on the top row, so the finger on the
            // key never covers them.
            verify(p.y + p.cellHeight + p.pad * 2 <= e.y);
            const second = p.x + p.pad + p.cellWidth * 1.5;
            touchEvent(field).move(0, field, second, c.y).commit();
            touchEvent(field).release(0, field, second, c.y).commit();
            compare(texts(), ["é"]);
            verify(field.accentPopup === null);
        }

        function test_lifting_off_the_accents_types_nothing() {
            const c = centre(find("char", "a"));
            touchEvent(field).press(0, field, c.x, c.y).commit();
            wait(600);
            verify(field.accentPopup !== null);
            touchEvent(field).move(0, field, c.x, c.y + field.rowHeight * 2).commit();
            touchEvent(field).release(0, field, c.x, c.y + field.rowHeight * 2).commit();
            compare(sent.count, 0);
        }

        // ---- Caret trackpad ----

        function test_sliding_space_moves_the_cursor() {
            const space = find("space");
            const start = Qt.point(space.x + space.w * 0.4, space.y + space.h / 2);
            touchEvent(field).press(0, field, start.x, start.y).commit();
            for (let i = 1; i <= 10; ++i) touchEvent(field).move(0, field, start.x + i * 10, start.y).commit();
            verify(field.caretMoving);
            touchEvent(field).release(0, field, start.x + 100, start.y).commit();
            verify(!field.caretMoving);
            verify(keysSent().length >= 4);
            verify(keysSent().every(k => k[0] === Qt.Key_Right && k[1] === 0));
            verify(texts().indexOf(" ") < 0);
        }

        function test_holding_space_moves_the_cursor_up_and_down() {
            const space = find("space");
            const start = Qt.point(space.x + space.w * 0.4, space.y + space.h / 2);
            touchEvent(field).press(0, field, start.x, start.y).commit();
            wait(450);
            verify(field.caretMoving);
            touchEvent(field).move(0, field, start.x, start.y - field.caretStepY * 2.2).commit();
            touchEvent(field).release(0, field, start.x, start.y - field.caretStepY * 2.2).commit();
            compare(keysSent(), [[Qt.Key_Up, 0], [Qt.Key_Up, 0]]);
        }

        function test_tapping_space_types_a_space() {
            tap(find("space"));
            compare(texts(), [" "]);
        }

        function test_the_trackpad_mark_is_not_a_space() {
            const mark = field.markRect;
            touchEvent(field).press(0, field, mark.x + mark.width / 2, mark.y + mark.height / 2).commit();
            touchEvent(field).release(0, field, mark.x + mark.width / 2, mark.y + mark.height / 2).commit();
            compare(sent.count, 0);
        }

        // ---- Delete ----

        function dragDelete(steps, back) {
            const del = centre(find("delete"));
            const to = del.x - field.deleteStart - field.deleteStep * (steps - 0.5);
            touchEvent(field).press(0, field, del.x, del.y).commit();
            for (let x = del.x - 10; x >= to; x -= 10) touchEvent(field).move(0, field, x, del.y).commit();
            let end = to;
            if (back) {
                end = to + field.deleteStep * back;
                for (let x = to; x <= end; x += 10) touchEvent(field).move(0, field, x, del.y).commit();
            }
            wait(260);
            touchEvent(field).release(0, field, end, del.y).commit();
        }

        function test_delete_scrub_selects_then_deletes() {
            dragDelete(5, 2);
            const ks = keysSent();
            const lefts = ks.filter(k => k[0] === Qt.Key_Left && k[1] === Qt.ShiftModifier).length;
            const rights = ks.filter(k => k[0] === Qt.Key_Right && k[1] === Qt.ShiftModifier).length;
            compare(lefts - rights, 3);
            compare(ks[ks.length - 1], [Qt.Key_Backspace, 0]);
            compare(ks.filter(k => k[0] === Qt.Key_Backspace).length, 1);
            compare(field.markCount, 0);
        }

        function test_delete_scrub_counts_in_a_terminal() {
            field.terminal = true;
            dragDelete(4);
            const ks = keysSent();
            compare(ks.length, 4);
            verify(ks.every(k => k[0] === Qt.Key_Backspace && k[1] === 0));
        }

        function test_flicking_delete_deletes_a_word() {
            const del = centre(find("delete"));
            touchEvent(field).press(0, field, del.x, del.y).commit();
            touchEvent(field).move(0, field, del.x - field.wordFlick * 1.5, del.y).commit();
            touchEvent(field).release(0, field, del.x - field.wordFlick * 1.5, del.y).commit();
            const ks = keysSent();
            compare(ks[ks.length - 1], [Qt.Key_Backspace, Qt.ControlModifier]);
            compare(ks.filter(k => k[0] === Qt.Key_Backspace).length, 1);
        }

        function test_terminal_word_is_ctrl_w() {
            field.terminal = true;
            const del = centre(find("delete"));
            touchEvent(field).press(0, field, del.x, del.y).commit();
            touchEvent(field).move(0, field, del.x - field.wordFlick * 1.5, del.y).commit();
            touchEvent(field).release(0, field, del.x - field.wordFlick * 1.5, del.y).commit();
            compare(keysSent(), [[Qt.Key_W, Qt.ControlModifier]]);
        }

        function test_tapping_delete_deletes_one() {
            tap(find("delete"));
            compare(keysSent(), [[Qt.Key_Backspace, 0]]);
        }

        function test_holding_delete_repeats() {
            const del = centre(find("delete"));
            touchEvent(field).press(0, field, del.x, del.y).commit();
            wait(800);
            touchEvent(field).release(0, field, del.x, del.y).commit();
            verify(sent.count >= 3, "repeated " + sent.count);
            verify(keysSent().every(k => k[0] === Qt.Key_Backspace));
        }
    }
}
