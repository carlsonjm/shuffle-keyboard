#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Runs inside the compositor verify-latch.sh starts, with the Keyboard as its
# input method. Nothing here reaches the running session.
#
# The handle puts the keys away, and they stay away until a text field or the
# tray entry asks for them again. The trackpad latch keeps the keys up while
# the pointer clicks into other applications; it is no reason to bring them
# back once the handle has put them away. An application holds a focused
# field, stand-ins answer for Kadunce and for the pointer portal, and the
# handle is tapped with the mouse or dragged down by a finger.

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
    if [[ "${LATCH_PATH}" == drag ]]; then
        send "tdown 1 ${x} ${y}" "wait 60" "tup 1"
    else
        send "abs ${x} ${y}" "wait 60" "down" "wait 60" "up"
    fi
}

# The handle takes the keys away: a click on it with the mouse, or a finger
# carrying them down half their height and letting go.
handle_away() {
    local x="$1" y="$2"
    if [[ "${LATCH_PATH}" == drag ]]; then
        send "tdown 1 ${x} ${y}" "wait 40"
        local step
        for step in 1 2 3 4 5 6 7 8 9 10; do
            send "tmove 1 ${x} $((y + step * 20))" "wait 16"
        done
        send "tup 1"
    else
        tap_at "${x}" "${y}"
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
# A dock is published, so the handle takes the dock row's place and width.
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
if [[ "${LATCH_PATH}" == drag ]]; then
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
# The handle is the dock row the keys cover, 544 to 920, in the keys' top
# strip.
handle_x=732
handle_y=$((frame_y + 13))
# The latch is the square at the space bar's right end, one key row tall. At
# this output's size and the default height its centre is 379 px right of the
# keys' centre and 50 px above their bottom edge.
latch_x=$((frame_x + frame_w / 2 + 379))
latch_y=$((frame_y + frame_h - 50))

if [[ "${LATCH_PATH}" == drag ]]; then
    gesture="dragged down by a finger"
else
    gesture="clicked"
fi

echo
echo "Unlatched, the handle ${gesture} puts the keys away"
before=$(raise_requests)
handle_away "${handle_x}" "${handle_y}"
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
echo "Latched, the handle ${gesture} puts the keys away and they stay away"
before=$(raise_requests)
signals_before=$(wc -l < "${signal_log}")
put_away_at=$(now_ms)
handle_away "${handle_x}" "${handle_y}"
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

exec 3>&-
kill "${app_pid}" 2>/dev/null

echo
printf '%d passed, %d failed\n' "${pass}" "${fail}"
if ((fail > 0)); then
    echo FAIL > "${PROBE_ROOT}/result"
    exit 1
fi
echo PASS > "${PROBE_ROOT}/result"
