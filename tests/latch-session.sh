#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Runs inside the compositor verify-latch.sh starts, with the Keyboard as its
# input method. Nothing here reaches the running session.
#
# Hide puts the keys away, and they stay away until a text field or the tray
# entry asks for them again. The trackpad latch keeps the keys up while the
# pointer clicks into other applications; it is no reason to bring them back
# once Hide or the tray entry has put them away. An application holds a
# focused field, stand-ins answer for Kadunce and for the pointer portal, and
# Hide is clicked with the mouse or tapped by a finger.

set -uo pipefail

# The report is kept apart from the compositor's own log.
exec > "${PROBE_ROOT}/report.log"

tests_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
stand_in_log="${PROBE_ROOT}/stand-in.log"
kadunce_log="${PROBE_ROOT}/kadunce.log"
portal_log="${PROBE_ROOT}/portal.log"
signal_log="${PROBE_ROOT}/signals.log"
script_count=0

pass=0
fail=0

check() {
    local name="$1" actual="$2" expected="$3"
    if [[ "${actual}" == "${expected}" ]]; then
        printf '  ok   %s\n' "${name}"
        pass=$((pass + 1))
    else
        printf '  FAIL %s\n         wanted: %s\n         got:    %s\n' \
            "${name}" "${expected}" "${actual}"
        fail=$((fail + 1))
    fi
}

wait_for() {
    local file="$1" pattern="$2" tries="${3:-120}"
    local waited=0
    while ((waited < tries)); do
        grep -qE "${pattern}" "${file}" 2>/dev/null && return 0
        sleep 0.1
        waited=$((waited + 1))
    done
    return 1
}

now_ms() {
    echo $(($(date +%s%N) / 1000000))
}

control() {
    gdbus call --session --dest studio.warbler.BottomSurface \
        --object-path /BottomSurface \
        --method "studio.warbler.test.Control.$1" "${@:2}" > /dev/null 2>&1
}

keyboard() {
    gdbus call --session --dest org.kde.KWin --object-path /VirtualKeyboard \
        --method org.freedesktop.DBus.Properties.Get \
        org.kde.kwin.VirtualKeyboard "$1" 2>/dev/null
}

wait_keyboard() {
    local want="$1" waited=0
    until [[ "$(keyboard visible)" == *"${want}"* ]] || ((waited >= 80)); do
        sleep 0.1
        waited=$((waited + 1))
    done
}

# How many Keyboard surfaces the compositor has on screen, and where.
panels_now() {
    script_count=$((script_count + 1))
    local name="panelprobe${script_count}"
    gdbus call --session --dest org.kde.KWin --object-path /Scripting \
        --method org.kde.kwin.Scripting.loadScript \
        "${tests_dir}/panel-probe.js" "${name}" > /dev/null 2>&1
    gdbus call --session --dest org.kde.KWin --object-path /Scripting \
        --method org.kde.kwin.Scripting.start > /dev/null 2>&1
    sleep 0.4
    gdbus call --session --dest org.kde.KWin --object-path /Scripting \
        --method org.kde.kwin.Scripting.unloadScript "${name}" > /dev/null 2>&1
    grep -oE 'record panels .*' "${stand_in_log}" | tail -1 | sed 's/^record panels //'
}

# How often the Keyboard has asked for its keys on the person's behalf.
raise_requests() {
    grep -c '^raiseKeyboard' "${kadunce_log}" 2>/dev/null
}

# The keys' entry in the system tray, by the name the Keyboard gave it.
tray_entry() {
    gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
        --method org.freedesktop.DBus.ListNames | grep -oE 'org\.kde\.StatusNotifierItem-[0-9]+-1' | head -1
}

# The mouse and the touchscreen, fed a line at a time.
send() { printf '%s\n' "$@" >&3; }

tap_at() {
    local x="$1" y="$2"
    if [[ "${LATCH_PATH}" == touch ]]; then
        send "tdown 1 ${x} ${y}" "wait 60" "tup 1"
    else
        send "abs ${x} ${y}" "wait 60" "down" "wait 60" "up"
    fi
}

# A compositor with no touch device leaves its virtual keyboard to tablet
# mode, which this one is never in. Mode 2 offers it regardless.
gdbus call --session --dest org.kde.KWin --object-path /VirtualKeyboard \
    --method org.freedesktop.DBus.Properties.Set \
    org.kde.kwin.VirtualKeyboard mode "<uint32 2>" > /dev/null 2>&1

# Every change of the keys' visibility, as the compositor announces it.
gdbus monitor --session --dest org.kde.KWin --object-path /VirtualKeyboard 2>/dev/null \
    | while IFS= read -r line; do
        [[ "${line}" == *visibleChanged* ]] && echo "$(now_ms)"
    done > "${signal_log}" &

python3 "${tests_dir}/bottom-surface-stand-in.py" > "${stand_in_log}" 2>&1 &
python3 "${tests_dir}/kadunce-stand-in.py" > "${kadunce_log}" 2>&1 &
python3 "${tests_dir}/portal-stand-in.py" > "${portal_log}" 2>&1 &
for log in "${stand_in_log}" "${kadunce_log}" "${portal_log}"; do
    if ! wait_for "${log}" '^ready'; then
        echo "A stand-in never took its name: ${log##*/}." >&2
        echo FAIL > "${PROBE_ROOT}/result"
        exit 1
    fi
done
# A dock is published, as on the tablet.
control report true 60 544 920

QML_XHR_ALLOW_FILE_READ=1 qml6 "${tests_dir}/app-stand-in.qml" -- "${PROBE_ROOT}/app-type" \
    > "${PROBE_ROOT}/app.log" 2>&1 &
app_pid=$!
sleep 2

mkfifo "${PROBE_ROOT}/input"
"${FAKE_INPUT_BIN}" < "${PROBE_ROOT}/input" > "${PROBE_ROOT}/input.log" 2>&1 &
exec 3> "${PROBE_ROOT}/input"
if ! wait_for "${PROBE_ROOT}/input.log" '^ready' 50; then
    echo "The compositor took no fake input." >&2
    cat "${PROBE_ROOT}/input.log" >&2
    echo FAIL > "${PROBE_ROOT}/result"
    exit 1
fi
if [[ "${LATCH_PATH}" == touch ]]; then
    # The touchscreen only appears with its first touch, which reaches no
    # window; that one lands in an empty corner.
    send "tdown 9 1450 10" "wait 60" "tup 9"
    sleep 0.3
fi

echo
echo "A text field brings the keys up"
echo type > "${PROBE_ROOT}/app-type"
wait_keyboard true
check "the keys are up" "$(keyboard visible)" "(<true>,)"
sleep 1
panels="$(panels_now)"
printf '  the keys are at %s\n' "${panels#* }"
read -r _ origin size <<< "${panels}"
frame_x="${origin%,*}"
frame_y="${origin#*,}"
frame_w="${size%x*}"
frame_h="${size#*x}"
# Where Hide and the trackpad mark sit, by the Keyboard's own sizes
# (src/qml/main.qml, src/qml/KeyField.qml): the card fills the frame's width
# less a gutter at either side, the twelve-and-a-half-unit block is centred
# on it, and the bottom row is Ctrl, Alt, the space bar, the Tette Dot and
# Hide, at 1.5, 1.5, 6.5, 1.5 and 1.5 units. The mark is the square at the
# space bar's right end.
read -r hide_x mark_x row_y <<< "$(python3 - "${frame_x}" "${frame_y}" "${frame_w}" "${frame_h}" "${SCREEN_HEIGHT}" <<'PY'
import sys
x, y, w, h, screen_h = map(float, sys.argv[1:])
gap = max(5, min(10, w * 0.0062))
outer = max(6, min(12, w * 0.007))
panel = round(screen_h * 44 / 100)
row = (panel - 26 - gap * 3 - outer) / 4
unit = max(1, min(row, (w - 20 - outer * 2 + gap) / 12.5 - gap))
pitch = unit + gap
left = x + w / 2 - (12.5 * pitch - gap) / 2
hide = left + 11 * pitch + (1.5 * pitch - gap) / 2
mark = left + 3 * pitch + (6.5 * pitch - gap) - row / 2
row_y = y + h - outer - row / 2
print(round(hide), round(mark), round(row_y))
PY
)"
latch_x="${mark_x}"
latch_y="${row_y}"

if [[ "${LATCH_PATH}" == touch ]]; then
    gesture="tapped by a finger"
else
    gesture="clicked"
fi

echo
echo "Unlatched, Hide ${gesture} puts the keys away"
before=$(raise_requests)
tap_at "${hide_x}" "${row_y}"
sleep 1
check "the keys are down" "$(keyboard visible)" "(<false>,)"
sleep 1.5
check "they are still down" "$(keyboard visible)" "(<false>,)"
check "nothing asked for them again" "$(($(raise_requests) - before))" "0"

echo
echo "The tray entry brings them back, and the latch holds them as a trackpad"
gdbus call --session --dest "$(tray_entry)" --object-path /StatusNotifierItem \
    --method org.kde.StatusNotifierItem.Activate 0 0 > /dev/null 2>&1
wait_keyboard true
check "the keys are up" "$(keyboard visible)" "(<true>,)"
sleep 1
tap_at "${latch_x}" "${latch_y}"
if wait_for "${portal_log}" '^portal Start' 30; then
    printf '  ok   %s\n' "the latch took: the trackpad asked for the pointer"
    pass=$((pass + 1))
else
    printf '  FAIL %s\n         portal: %s\n' "the latch took: the trackpad asked for the pointer" \
        "$(grep -oE '^portal .*' "${portal_log}" | tr '\n' ' ')"
    fail=$((fail + 1))
fi
sleep 1
check "the keys are up" "$(keyboard visible)" "(<true>,)"

echo
echo "Latched, Hide ${gesture} puts the keys away and they stay away"
before=$(raise_requests)
signals_before=$(wc -l < "${signal_log}")
put_away_at=$(now_ms)
tap_at "${hide_x}" "${row_y}"
sleep 1
check "the keys are down" "$(keyboard visible)" "(<false>,)"
sleep 1.5
check "they are still down" "$(keyboard visible)" "(<false>,)"
check "nothing asked for them again" "$(($(raise_requests) - before))" "0"
changes=""
while read -r at; do
    changes+=" +$((at - put_away_at))ms"
done < <(tail -n +"$((signals_before + 1))" "${signal_log}")
printf '  the compositor announced a change of visibility at:%s\n' "${changes:- nothing}"

echo
echo "Latched again, the tray entry puts the keys away and they stay away"
gdbus call --session --dest "$(tray_entry)" --object-path /StatusNotifierItem \
    --method org.kde.StatusNotifierItem.Activate 0 0 > /dev/null 2>&1
wait_keyboard true
check "the tray entry brought the keys up" "$(keyboard visible)" "(<true>,)"
sleep 1
starts_before=$(grep -c '^portal Start' "${portal_log}" 2>/dev/null)
tap_at "${latch_x}" "${latch_y}"
waited=0
until (($(grep -c '^portal Start' "${portal_log}" 2>/dev/null) > starts_before)) || ((waited >= 30)); do
    sleep 0.1
    waited=$((waited + 1))
done
check "the latch took again" "$(($(grep -c '^portal Start' "${portal_log}" 2>/dev/null) > starts_before))" "1"
sleep 1
before=$(raise_requests)
gdbus call --session --dest "$(tray_entry)" --object-path /StatusNotifierItem \
    --method org.kde.StatusNotifierItem.Activate 0 0 > /dev/null 2>&1
sleep 1
check "the keys are down" "$(keyboard visible)" "(<false>,)"
sleep 1.5
check "they are still down" "$(keyboard visible)" "(<false>,)"
check "nothing asked for them again" "$(($(raise_requests) - before))" "0"

exec 3>&-
kill "${app_pid}" 2>/dev/null

echo
printf '%d passed, %d failed\n' "${pass}" "${fail}"
if ((fail > 0)); then
    echo FAIL > "${PROBE_ROOT}/result"
    exit 1
fi
echo PASS > "${PROBE_ROOT}/result"
