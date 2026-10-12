#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Runs inside the compositor verify-feedback.sh starts, with the Keyboard as
# its input method. Nothing here reaches the running session.
#
# A finger on a key shows on screen: the key it is on is drawn pressed, a
# flick down grows the key's grey character, and a held e brings its accents
# up above the key. Each is a picture the compositor shows, so the compositor
# is asked for the screen before the touch and during it, and the pixels where
# the feedback belongs are compared.

set -uo pipefail

# The report is kept apart from the compositor's own log.
exec > "${PROBE_ROOT}/report.log"

tests_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
stand_in_log="${PROBE_ROOT}/stand-in.log"
kadunce_log="${PROBE_ROOT}/kadunce.log"
app_log="${PROBE_ROOT}/app.log"
shots="${PROBE_ROOT}/shots"
mkdir -p "${shots}"
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

grab() { python3 "${tests_dir}/screen-probe.py" grab "${shots}/$1" >> "${PROBE_ROOT}/grab.log" 2>&1; }
differ() { python3 "${tests_dir}/screen-probe.py" differ "${shots}/$1" "${shots}/$2" "${@:3}"; }

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
# Where q and e sit, and the band above the top row the accents rise into,
# by the Keyboard's own sizes as verify-latch.sh reads them: q and e are the
# second and fourth keys of the top row, after 123.
read -r q_x e_x top_y key_w key_h band_y <<< "$(python3 - "${origin%,*}" "${origin#*,}" "${size%x*}" "${size#*x}" "${SCREEN_HEIGHT}" <<'PY'
import sys
x, y, w, h, screen_h = map(float, sys.argv[1:])
gap = max(5, min(10, w * 0.0062))
outer = max(6, min(12, w * 0.007))
panel = round(screen_h * 44 / 100)
row = (panel - 26 - gap * 3 - outer) / 4
unit = max(1, min(row, (w - 20 - outer * 2 + gap) / 12.5 - gap))
pitch = unit + gap
left = x + w / 2 - (12.5 * pitch - gap) / 2
bottom = y + h - outer - row / 2
top = bottom - 3 * (row + gap)
q = left + 1 * pitch + unit / 2
e = left + 3 * pitch + unit / 2
print(round(q), round(e), round(top), round(unit), round(row), round(top - row / 2 - row * 0.8 - 18))
PY
)"
printf '  q at %s,%s and e at %s,%s; keys %sx%s\n' "${q_x}" "${top_y}" "${e_x}" "${top_y}" "${key_w}" "${key_h}"
key_rect() { echo "$(($1 - key_w / 2)) $((top_y - key_h / 2)) ${key_w} ${key_h}"; }

if ! grab rest.raw; then
    echo "  the compositor gave no screenshot; nothing here can be read" >&2
    echo "The compositor gave no screenshot, so the screen cannot be read."
    echo SKIP > "${PROBE_ROOT}/result"
    exit 0
fi
sleep 0.3
grab rest-again.raw
# A caret blinking in the application is the only thing that moves at rest,
# and it is nowhere near the keys.
check "the keys hold still at rest" "$(differ rest.raw rest-again.raw $(key_rect "${e_x}"))" "0"

echo
echo "A finger resting on e draws it pressed"
send "tdown 1 ${e_x} ${top_y}"
sleep 0.25
grab pressed.raw
changed="$(differ rest.raw pressed.raw $(key_rect "${e_x}"))"
printf '  %s pixels of e changed\n' "${changed}"
check "e is drawn pressed" "$((changed > 50))" "1"

echo
echo "Held on e, its accents rise above it"
sleep 0.6
grab accents.raw
changed="$(differ rest.raw accents.raw $((e_x - key_w * 3)) "${band_y}" $((key_w * 6)) "${key_h}")"
printf '  %s pixels above e changed\n' "${changed}"
check "the accents are drawn above e" "$((changed > 200))" "1"
send "tup 1"
sleep 0.5
before_flick="$(app_text)"
printf '  lifting on e typed: %s\n' "${before_flick}"

echo
echo "Part way through a flick down on q, its grey 1 grows"
send "tdown 2 ${q_x} $((top_y - key_h / 4))"
sleep 0.1
grab flick-start.raw
send "tmove 2 ${q_x} $((top_y + key_h / 8))"
sleep 0.25
grab flick-mid.raw
changed="$(differ flick-start.raw flick-mid.raw $(key_rect "${q_x}"))"
printf '  %s pixels of q changed\n' "${changed}"
check "the flick is drawn as it grows" "$((changed > 50))" "1"
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
