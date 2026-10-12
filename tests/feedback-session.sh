#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Runs inside the compositor verify-feedback.sh starts, with the Keyboard as
# its input method. Nothing here reaches the running session.
#
# A finger on a key shows on screen: the key it is on is drawn pressed, a
# flick down grows the key's grey character, and a held e brings its accents
# up above the key. The Keyboard as built says what it draws, through its
# feedback log, and the session reads that while the finger is down.

set -uo pipefail

# The report is kept apart from the compositor's own log.
exec > "${PROBE_ROOT}/report.log"

tests_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
stand_in_log="${PROBE_ROOT}/stand-in.log"
kadunce_log="${PROBE_ROOT}/kadunce.log"
app_log="${PROBE_ROOT}/app.log"
keyboard_log="${PROBE_ROOT}/compositor.log"
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

control() {
    gdbus call --session --dest co.goodinput.BottomSurface \
        --object-path /BottomSurface \
        --method "co.goodinput.test.Control.$1" "${@:2}" > /dev/null 2>&1
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

app_text() {
    grep -oE 'app text=.*' "${app_log}" | tail -1 | sed 's/^app text=//'
}

# The touchscreen, fed a line at a time.
send() { printf '%s\n' "$@" >&3; }

# Whether the Keyboard has said a line since the mark was taken.
mark() { wc -l < "${keyboard_log}"; }
said_since() {
    local from="$1" pattern="$2" waited=0
    while ((waited < 10)); do
        tail -n +"$((from + 1))" "${keyboard_log}" | grep -qE "${pattern}" && { echo yes; return; }
        sleep 0.1
        waited=$((waited + 1))
    done
    echo no
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
control report true 60 544 920

QML_XHR_ALLOW_FILE_READ=1 qml6 "${tests_dir}/app-stand-in.qml" -- "${PROBE_ROOT}/app-type" \
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
# The touchscreen only appears with its first touch, which reaches no window;
# that one lands in an empty corner.
send "tdown 9 1450 10" "wait 60" "tup 9"
sleep 0.3

echo
echo "A text field brings the keys up"
echo type > "${PROBE_ROOT}/app-type"
wait_keyboard true
check "the keys are up" "$(keyboard visible)" "(<true>,)"
sleep 1.5
panels="$(panels_now)"
printf '  the keys are at %s\n' "${panels#* }"
read -r _ origin size <<< "${panels}"
# Where q and e sit, by the Keyboard's own sizes as verify-latch.sh reads
# them: the second and fourth keys of the top row, after 123.
read -r q_x e_x top_y key_h <<< "$(python3 - "${origin%,*}" "${origin#*,}" "${size%x*}" "${size#*x}" "${SCREEN_HEIGHT}" <<'PY'
import sys
x, y, w, h, screen_h = map(float, sys.argv[1:])
gap = max(5, min(10, w * 0.0062))
outer = max(6, min(12, w * 0.007))
panel = round(screen_h * 44 / 100)
row = (panel - 26 - gap * 3 - outer) / 4
unit = max(1, min(row, (w - 20 - outer * 2 + gap) / 12.5 - gap))
pitch = unit + gap
left = x + w / 2 - (12.5 * pitch - gap) / 2
top = y + h - outer - row / 2 - 3 * (row + gap)
print(round(left + pitch + unit / 2), round(left + 3 * pitch + unit / 2), round(top), round(row))
PY
)"
printf '  q at %s,%s and e at %s,%s\n' "${q_x}" "${top_y}" "${e_x}" "${top_y}"

echo
echo "A finger resting on e draws it pressed"
from=$(mark)
send "tdown 1 ${e_x} ${top_y}"
check "e is drawn pressed" "$(said_since "${from}" 'key e down true')" "yes"

echo
echo "Held on e, its accents rise above it"
check "the accents are shown" "$(said_since "${from}" 'accents shown true')" "yes"
from=$(mark)
send "tup 1"
check "e is let go" "$(said_since "${from}" 'key e down false')" "yes"
check "the accents go" "$(said_since "${from}" 'accents shown false')" "yes"
sleep 0.3
before_flick="$(app_text)"
printf '  lifting on e typed: %s\n' "${before_flick}"

echo
echo "Part way through a flick down on q, its grey 1 grows"
from=$(mark)
send "tdown 2 ${q_x} $((top_y - key_h / 4))" "wait 60" "tmove 2 ${q_x} $((top_y + key_h / 8))"
check "q is drawn pressed" "$(said_since "${from}" 'key q down true')" "yes"
check "the flick is drawn as it grows" "$(said_since "${from}" 'key q flick 0\.[1-9]')" "yes"
send "tmove 2 ${q_x} $((top_y + key_h))" "wait 30" "tup 2"
sleep 0.5
check "the flick still types 1" "$(app_text)" "${before_flick}1"

exec 3>&-
kill "${app_pid}" 2>/dev/null

echo
printf '%d passed, %d failed\n' "${pass}" "${fail}"
if ((fail > 0)); then
    echo FAIL > "${PROBE_ROOT}/result"
    exit 1
fi
echo PASS > "${PROBE_ROOT}/result"
