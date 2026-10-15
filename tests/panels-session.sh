#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Runs inside the compositor verify-panels.sh starts, with the Keyboard as its
# input method and no Bottom Surface on the bus. Nothing here reaches the
# running session.

set -uo pipefail

# The report is kept apart from the compositor's own log.
exec > "${PROBE_ROOT}/report.log"

tests_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
shell_log="${PROBE_ROOT}/shell.log"

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

# Waits until a pattern has been logged at least `count` times.
wait_count() {
    local file="$1" pattern="$2" count="$3" tries="${4:-100}" waited=0
    while ((waited < tries)); do
        (($(grep -cE "${pattern}" "${file}" 2>/dev/null) >= count)) && return 0
        sleep 0.1
        waited=$((waited + 1))
    done
    return 1
}

keyboard_visible() {
    gdbus call --session --dest org.kde.KWin --object-path /VirtualKeyboard \
        --method org.freedesktop.DBus.Properties.Get \
        org.kde.kwin.VirtualKeyboard visible 2>/dev/null
}

wait_keyboard() {
    local want="$1" waited=0
    until [[ "$(keyboard_visible)" == *"${want}"* ]] || ((waited >= 80)); do
        sleep 0.1
        waited=$((waited + 1))
    done
}

tray_entry() {
    gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
        --method org.freedesktop.DBus.ListNames | grep -oE 'org\.kde\.StatusNotifierItem-[0-9]+-1' | head -1
}

# Where the Keyboard keeps the panels' own modes while they are changed.
kept_modes() {
    local file
    file="$(find "${PROBE_ROOT}/state" -name bottom-panels.json 2>/dev/null | head -1)"
    if [[ -n "${file}" ]]; then
        cat "${file}"
    else
        echo "nothing"
    fi
}

wait_nothing_kept() {
    local waited=0
    until [[ "$(kept_modes)" == nothing ]] || ((waited >= 30)); do
        sleep 0.1
        waited=$((waited + 1))
    done
}

# A compositor with no touch device leaves its virtual keyboard to tablet
# mode, which this one is never in. Mode 2 offers it regardless.
gdbus call --session --dest org.kde.KWin --object-path /VirtualKeyboard \
    --method org.freedesktop.DBus.Properties.Set \
    org.kde.kwin.VirtualKeyboard mode "<uint32 2>" > /dev/null 2>&1

python3 "${tests_dir}/plasmashell-stand-in.py" > "${shell_log}" 2>&1 &
if ! wait_count "${shell_log}" '^ready' 1; then
    echo "The shell stand-in never took its name."
    echo FAIL > "${PROBE_ROOT}/result"
    exit 1
fi
# The Keyboard started before the shell, as it does on a real sign-in.
sleep 2

echo
echo "The keys come up with no Bottom Surface installed"
gdbus call --session --dest org.kde.KWin --object-path /VirtualKeyboard \
    --method org.kde.kwin.VirtualKeyboard.forceActivate > /dev/null 2>&1
wait_keyboard true
check "they are up" "$(keyboard_visible)" "(<true>,)"
wait_count "${shell_log}" '^panel 1 hiding=autohide' 1 \
    && check "the bottom panel autohides" yes yes \
    || check "the bottom panel autohides" no yes
check "its own mode is kept on disk" "$(kept_modes)" '[{"hiding":"none","id":1}]'
check "the top panel is left alone" "$(grep -c '^panel 2' "${shell_log}")" "0"

echo
echo "The tray entry puts them away"
gdbus call --session --dest "$(tray_entry)" --object-path /StatusNotifierItem \
    --method org.kde.StatusNotifierItem.Activate 0 0 > /dev/null 2>&1
wait_keyboard false
check "they are down" "$(keyboard_visible)" "(<false>,)"
wait_count "${shell_log}" '^panel 1 hiding=none' 1 \
    && check "the bottom panel is back to its own mode" yes yes \
    || check "the bottom panel is back to its own mode" no yes
wait_nothing_kept
check "nothing is left on disk" "$(kept_modes)" "nothing"

echo
echo "Killed with the keys up, the next Keyboard puts the panel back"
gdbus call --session --dest org.kde.KWin --object-path /VirtualKeyboard \
    --method org.kde.kwin.VirtualKeyboard.forceActivate > /dev/null 2>&1
wait_keyboard true
if wait_count "${shell_log}" '^panel 1 hiding=autohide' 2; then
    first="$(pgrep -f "^${KEYBOARD_BIN}" | head -1)"
    kill -9 "${first}" 2>/dev/null
    waited=0
    next=""
    while ((waited < 100)); do
        next="$(pgrep -f "^${KEYBOARD_BIN}" | head -1)"
        [[ -n "${next}" && "${next}" != "${first}" ]] && break
        next=""
        sleep 0.1
        waited=$((waited + 1))
    done
    if [[ -z "${next}" ]]; then
        # KWin starting its input method again after a crash is KWin's
        # choice, not the Keyboard's; without it this path cannot be seen.
        echo "  note this KWin started no new Keyboard after the kill; not checked"
    else
        wait_count "${shell_log}" '^panel 1 hiding=none' 2 \
            && check "the bottom panel is back to its own mode" yes yes \
            || check "the bottom panel is back to its own mode" no yes
    fi
else
    check "the bottom panel autohides again" no yes
fi

echo
printf '%d passed, %d failed\n' "${pass}" "${fail}"
if ((fail > 0)); then
    echo FAIL > "${PROBE_ROOT}/result"
    exit 1
fi
echo PASS > "${PROBE_ROOT}/result"
