#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Runs inside the compositor verify-seat.sh starts, with the Keyboard as its
# input method. Nothing here reaches the running session.
#
# The Keyboard is raised over a band that reserves the bottom of the output.
# The band then does what the Bottom Surface does once its presentation has
# left: it gives up the reservation, and says so. The compositor seats an input
# panel on the bottom of the work area and does not move it when the work area
# grows, so unless the Keyboard asks to be placed again once the reservation
# has gone it stays a band's height short of the bottom, over nothing.

set -uo pipefail

tests_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
stand_in_log="${PROBE_ROOT}/stand-in.log"
band_flag="${PROBE_ROOT}/band-released"
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

# The bottom edge the compositor has given the Keyboard, as it stands now.
seated_bottom() {
    script_count=$((script_count + 1))
    local name="seatprobe${script_count}"
    gdbus call --session --dest org.kde.KWin --object-path /Scripting \
        --method org.kde.kwin.Scripting.loadScript \
        "${tests_dir}/seat-probe.js" "${name}" > /dev/null 2>&1
    gdbus call --session --dest org.kde.KWin --object-path /Scripting \
        --method org.kde.kwin.Scripting.start > /dev/null 2>&1
    sleep 0.4
    gdbus call --session --dest org.kde.KWin --object-path /Scripting \
        --method org.kde.kwin.Scripting.unloadScript "${name}" > /dev/null 2>&1
    grep -oE 'record keyboard .* bottom=[0-9-]+' "${stand_in_log}" \
        | tail -1 | grep -oE 'bottom=[0-9-]+'
}

keyboard_visible() {
    gdbus call --session --dest org.kde.KWin --object-path /VirtualKeyboard \
        --method org.freedesktop.DBus.Properties.Get \
        org.kde.kwin.VirtualKeyboard visible 2>/dev/null
}

# A compositor with no touch device leaves its virtual keyboard to tablet
# mode, which this one is never in. Mode 2 offers it regardless, and it has to
# be asked for before anything else runs: set later, the Keyboard never shows.
gdbus call --session --dest org.kde.KWin --object-path /VirtualKeyboard \
    --method org.freedesktop.DBus.Properties.Set \
    org.kde.kwin.VirtualKeyboard mode "<uint32 2>" > /dev/null 2>&1

python3 "${tests_dir}/bottom-surface-stand-in.py" > "${stand_in_log}" 2>&1 &
if ! wait_for "${stand_in_log}" '^ready'; then
    echo "The Bottom Surface stand-in never took its name." >&2
    echo FAIL > "${PROBE_ROOT}/result"
    exit 1
fi
control report true 60 544 920

QML_XHR_ALLOW_FILE_READ=1 qml6 "${tests_dir}/seat-band-stand-in.qml" -- "${band_flag}" \
    > "${PROBE_ROOT}/band.log" 2>&1 &
band_pid=$!
sleep 2

echo
echo "The Keyboard comes up over a reserved band"
gdbus call --session --dest org.kde.KWin --object-path /VirtualKeyboard \
    --method org.kde.kwin.VirtualKeyboard.forceActivate > /dev/null 2>&1
waited=0
until [[ "$(keyboard_visible)" == *true* ]] || ((waited >= 80)); do
    sleep 0.1
    waited=$((waited + 1))
done
check "it is up" "$(keyboard_visible)" "(<true>,)"
if ! wait_for "${stand_in_log}" '^yielded=1'; then
    echo "  FAIL the Keyboard never asked the surface for the region"
    fail=$((fail + 1))
fi
sleep 0.5
check "while the band holds its reservation, it sits on the band" \
    "$(seated_bottom)" "bottom=855"

echo
echo "The band gives up the reservation, and the Keyboard comes down"
# The surface's presentation has already left by the time it gives the
# reservation up, and it says so the moment the release has gone out with a
# frame, with nothing added for the compositor to catch up.
echo released > "${band_flag}"
wait_for_now() {
    local file="$1" pattern="$2" tries="$3" waited=0
    while ((waited < tries)); do
        grep -qE "${pattern}" "${file}" 2>/dev/null && return 0
        sleep 0.005
        waited=$((waited + 1))
    done
    return 1
}
wait_for_now "${PROBE_ROOT}/band.log" 'reserving=false' 400 || true
control setReserving false
sleep 1
check "it sits on the bottom of the output" "$(seated_bottom)" "bottom=915"

kill "${band_pid}" 2>/dev/null

echo
printf '%d passed, %d failed\n' "${pass}" "${fail}"
if ((fail > 0)); then
    echo FAIL > "${PROBE_ROOT}/result"
    exit 1
fi
echo PASS > "${PROBE_ROOT}/result"
