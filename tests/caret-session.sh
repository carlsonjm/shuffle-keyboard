#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Runs inside the compositor verify-caret.sh starts, with the Keyboard as its
# input method. Nothing here reaches the running session.
#
# The caret trackpad moves the text cursor the same distance for the same
# finger travel, left or right: a finger drags the space bar a measured way
# left and the same way right, after a hold and as a plain slide, and the
# application's own cursor says how far each went.

set -uo pipefail

# The report is kept apart from the compositor's own log.
exec > "${PROBE_ROOT}/report.log"

tests_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
stand_in_log="${PROBE_ROOT}/stand-in.log"
kadunce_log="${PROBE_ROOT}/kadunce.log"
app_log="${PROBE_ROOT}/app.log"

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

# Where the application's cursor is now, and how many arrows it was sent.
app_cursor() {
    grep -oE 'app cursor=[0-9]+' "${app_log}" | tail -1 | sed 's/^app cursor=//'
}
app_keys() {
    grep -c "app key=$1" "${app_log}" 2>/dev/null
}

# The keys' surface on screen, as the compositor places it.
panels_now() {
    gdbus call --session --dest org.kde.KWin --object-path /Scripting \
        --method org.kde.kwin.Scripting.loadScript \
        "${tests_dir}/panel-probe.js" panelprobe > /dev/null 2>&1
    gdbus call --session --dest org.kde.KWin --object-path /Scripting \
        --method org.kde.kwin.Scripting.start > /dev/null 2>&1
    sleep 0.4
    gdbus call --session --dest org.kde.KWin --object-path /Scripting \
        --method org.kde.kwin.Scripting.unloadScript panelprobe > /dev/null 2>&1
    grep -oE 'record panels .*' "${stand_in_log}" | tail -1 | sed 's/^record panels //'
}

# The touchscreen, fed a line at a time, in the output's own pixels.
send() { printf '%s\n' "$@" >&3; }
px() { python3 -c "import sys; print(round(float(sys.argv[1]) * float(sys.argv[2])))" "$1" "${touch_scale}"; }

# One finger down on the space bar, held or not, carried sideways by a
# distance in small even steps, and lifted.
drag() {
    local hold="$1" distance="$2" x="${space_x}" i
    local steps=$(((${distance#-} + 2) / 3)) step=$((distance < 0 ? -3 : 3))
    local y
    y=$(px "${row_y}")
    send "tdown 1 $(px "${x}") ${y}" "wait ${hold}"
    for ((i = 0; i < steps; i++)); do
        x=$((x + step))
        send "tmove 1 $(px "${x}") ${y}" "wait 8"
    done
    send "wait 150" "tup 1"
    settle
}

# The application takes its arrows a while after the finger lifts; wait until
# it has been quiet for a second.
settle() {
    local lines=-1 waited=0
    while ((waited < 100)); do
        sleep 1
        local now
        now=$(wc -l < "${app_log}")
        ((now == lines)) && return 0
        lines=${now}
        waited=$((waited + 1))
    done
}

# A compositor with no touch device leaves its virtual keyboard to tablet
# mode, which this one is never in. Mode 2 offers it regardless.
gdbus call --session --dest org.kde.KWin --object-path /VirtualKeyboard \
    --method org.freedesktop.DBus.Properties.Set \
    org.kde.kwin.VirtualKeyboard mode "<uint32 2>" > /dev/null 2>&1

python3 "${tests_dir}/bottom-surface-stand-in.py" > "${stand_in_log}" 2>&1 &
python3 "${tests_dir}/kadunce-stand-in.py" > "${kadunce_log}" 2>&1 &
for log in "${stand_in_log}" "${kadunce_log}"; do
    if ! wait_for "${log}" '^ready'; then
        echo "A stand-in never took its name: ${log##*/}." >&2
        echo FAIL > "${PROBE_ROOT}/result"
        exit 1
    fi
done
# A dock is published, as on the tablet.
gdbus call --session --dest studio.warbler.BottomSurface --object-path /BottomSurface \
    --method studio.warbler.test.Control.report true 60 544 920 > /dev/null 2>&1

QML_XHR_ALLOW_FILE_READ=1 qml6 "${tests_dir}/caret-app-stand-in.qml" -- "${PROBE_ROOT}/app-type" \
    > "${app_log}" 2>&1 &
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
# The touchscreen only appears with its first touch, which reaches no
# window; that one lands in an empty corner.
send "tdown 9 1450 10" "wait 60" "tup 9"
sleep 0.3

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
# A scaled output may report the keys in its pixels rather than in the
# logical size the touches use.
touch_scale=1
if ((frame_w > 1463)); then
    touch_scale=1.75
    read -r frame_x frame_y frame_w frame_h <<< "$(python3 -c "import sys; print(*(round(float(v) / 1.75) for v in sys.argv[1:]))" "${frame_x}" "${frame_y}" "${frame_w}" "${frame_h}")"
    printf '  in logical size, %s,%s %sx%s\n' "${frame_x}" "${frame_y}" "${frame_w}" "${frame_h}"
fi
# The space bar's centre and one caret step, by the Keyboard's own sizes
# (src/qml/main.qml, src/qml/KeyField.qml), as latch-session.sh reads them.
# The drag is two keys wide and stays on the space bar either way.
read -r space_x row_y distance expected <<< "$(python3 - "${frame_x}" "${frame_y}" "${frame_w}" "${frame_h}" "${SCREEN_HEIGHT}" <<'PY'
import math
import sys
x, y, w, h, screen_h = map(float, sys.argv[1:])
gap = max(5, min(10, w * 0.0062))
outer = max(6, min(12, w * 0.007))
panel = round(screen_h * 44 / 100)
row = (panel - 26 - gap * 3 - outer) / 4
unit = max(1, min(row, (w - 20 - outer * 2 + gap) / 12.5 - gap))
pitch = unit + gap
left = x + w / 2 - (12.5 * pitch - gap) / 2
space = left + 3 * pitch + (6.5 * pitch - gap - row) / 2
row_y = y + h - outer - row / 2
distance = round(2 * pitch / 3) * 3
print(round(space), round(row_y), distance, math.floor(distance / (unit * 0.15)))
PY
)"
printf '  each drag is %s px, about %s caret steps\n' "${distance}" "${expected}"

for start in hold slide; do
    if [[ "${start}" == hold ]]; then
        hold=500
        echo
        echo "Held still first, the same travel moves the cursor as far either way"
    else
        hold=40
        echo
        echo "Slid at once, the same travel moves the cursor as far either way"
    fi
    before="$(app_cursor)"
    lefts=$(app_keys left)
    drag "${hold}" "-${distance}"
    went_left=$((before - $(app_cursor)))
    sent_left=$(($(app_keys left) - lefts))
    before="$(app_cursor)"
    rights=$(app_keys right)
    drag "${hold}" "${distance}"
    went_right=$(($(app_cursor) - before))
    sent_right=$(($(app_keys right) - rights))
    printf '  left: %s arrows, cursor %s back; right: %s arrows, cursor %s on\n' \
        "${sent_left}" "${went_left}" "${sent_right}" "${went_right}"
    check "the cursor came back to where it started" "${went_right}" "${went_left}"
    check "the application was sent as many Rights as Lefts" "${sent_right}" "${sent_left}"
    # A slide spends its first fifth of a key starting the trackpad, which
    # costs it a step or two that a hold does not.
    slack=$([[ "${start}" == hold ]] && echo 1 || echo 3)
    near=$((went_left >= expected - slack && went_left <= expected + 1))
    check "the cursor moved one character per step" "${near}" "1"
done

exec 3>&-
kill "${app_pid}" 2>/dev/null

echo
printf '%d passed, %d failed\n' "${pass}" "${fail}"
if ((fail > 0)); then
    echo FAIL > "${PROBE_ROOT}/result"
    exit 1
fi
echo PASS > "${PROBE_ROOT}/result"
