#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Runs inside the compositor verify-raise.sh starts, with the Keyboard as its
# input method. Nothing here reaches the running session.
#
# Plasma shows a raised keyboard only once a text field has asked for it, so
# the handle raises by taking typing focus into a field of its own. That is
# only acceptable if the focus goes back where it was when the keyboard goes.
# An application holds the focus here, the handle raises, and the compositor
# is asked who holds the focus at each step.

set -uo pipefail

tests_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
stand_in_log="${PROBE_ROOT}/stand-in.log"
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
    gdbus call --session --dest studio.warbler.BottomSurface \
        --object-path /BottomSurface \
        --method "studio.warbler.test.Control.$1" "${@:2}" > /dev/null 2>&1
}

focus_now() {
    script_count=$((script_count + 1))
    local name="raiseprobe${script_count}"
    gdbus call --session --dest org.kde.KWin --object-path /Scripting \
        --method org.kde.kwin.Scripting.loadScript \
        "${tests_dir}/raise-probe.js" "${name}" > /dev/null 2>&1
    gdbus call --session --dest org.kde.KWin --object-path /Scripting \
        --method org.kde.kwin.Scripting.start > /dev/null 2>&1
    sleep 0.4
    gdbus call --session --dest org.kde.KWin --object-path /Scripting \
        --method org.kde.kwin.Scripting.unloadScript "${name}" > /dev/null 2>&1
    grep -oE 'record focus .*' "${stand_in_log}" | tail -1 | sed 's/^record focus //'
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

# A compositor with no touch device leaves its virtual keyboard to tablet
# mode, which this one is never in. Mode 2 offers it regardless.
gdbus call --session --dest org.kde.KWin --object-path /VirtualKeyboard \
    --method org.freedesktop.DBus.Properties.Set \
    org.kde.kwin.VirtualKeyboard mode "<uint32 2>" > /dev/null 2>&1

python3 "${tests_dir}/bottom-surface-stand-in.py" > "${stand_in_log}" 2>&1 &
if ! wait_for "${stand_in_log}" '^ready'; then
    echo "The Bottom Surface stand-in never took its name." >&2
    echo FAIL > "${PROBE_ROOT}/result"
    exit 1
fi

QML_XHR_ALLOW_FILE_READ=1 qml6 "${tests_dir}/app-stand-in.qml" -- "${PROBE_ROOT}/app-type" \
    > "${PROBE_ROOT}/app.log" 2>&1 &
app_pid=$!
sleep 2

echo
echo "An application holds the focus"
check "the application is focused" "$(focus_now)" "app"

echo
echo "The handle raises the Keyboard by taking the focus"
# Publishing a dock is what puts the handle on screen, and the probe raises
# from it a moment later, the way a finger would.
control report true false 60 544 920
wait_keyboard true
check "the Keyboard is up" "$(keyboard visible)" "(<true>,)"
check "a text field is what asked for it" "$(keyboard activeClientSupportsTextInput)" "(<true>,)"
focus="$(focus_now)"
if [[ "${focus}" != "app" && "${focus}" != "none" ]]; then
    printf '  ok   %s\n' "the handle holds the focus while it is up (${focus})"
    pass=$((pass + 1))
else
    printf '  FAIL %s\n         got: %s\n' "the handle holds the focus while it is up" "${focus}"
    fail=$((fail + 1))
fi

echo
echo "Dismissing the Keyboard gives the focus back"
gdbus call --session --dest org.kde.KWin --object-path /VirtualKeyboard \
    --method org.freedesktop.DBus.Properties.Set \
    org.kde.kwin.VirtualKeyboard active "<false>" > /dev/null 2>&1
wait_keyboard false
check "the Keyboard is down" "$(keyboard visible)" "(<false>,)"
sleep 0.5
check "the application has the focus again" "$(focus_now)" "app"

echo
echo "The Keyboard still types into an application afterwards"
# The handle's focus moved this process's own focus with it. If it did not
# come back, the Keyboard would show for a text field and type nowhere.
echo type > "${PROBE_ROOT}/app-type"
wait_keyboard true
check "a text field in the application raises it" "$(keyboard visible)" "(<true>,)"
if wait_for "${PROBE_ROOT}/app.log" "app text=${SHUFFLE_PROBE_TEXT}" 150; then
    printf '  ok   %s\n' "what is typed reaches the application"
    pass=$((pass + 1))
else
    printf '  FAIL %s\n         got: %s\n' "what is typed reaches the application" \
        "$(grep -oE 'app text=.*' "${PROBE_ROOT}/app.log" | tail -1)"
    fail=$((fail + 1))
fi

kill "${app_pid}" 2>/dev/null

echo
printf '%d passed, %d failed\n' "${pass}" "${fail}"
if ((fail > 0)); then
    echo FAIL > "${PROBE_ROOT}/result"
    exit 1
fi
echo PASS > "${PROBE_ROOT}/result"
