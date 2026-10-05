#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Runs inside the compositor verify-hold.sh starts, with the Keyboard as its
# input method. Nothing here reaches the running session.
#
# While a text field is focused, every key of a physical keyboard passes
# through the Keyboard on its way to the application, whether the keys are on
# screen or not. A physical key held down is an ordinary held key: it opens no
# accent chooser. A chooser nobody can see would still take the next key, so a
# digit typed after the hold would replace the held letter with an accented
# one instead of arriving as a digit.

set -uo pipefail

# The report is kept apart from the compositor's own log.
exec > "${PROBE_ROOT}/report.log"

tests_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
stand_in_log="${PROBE_ROOT}/stand-in.log"
app_log="${PROBE_ROOT}/app.log"
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

keyboard() {
    gdbus call --session --dest org.kde.KWin --object-path /VirtualKeyboard \
        --method org.freedesktop.DBus.Properties.Get \
        org.kde.kwin.VirtualKeyboard "$1" 2>/dev/null
}

wait_keyboard() {
    local property="$1" want="$2" waited=0
    until [[ "$(keyboard "${property}")" == *"${want}"* ]] || ((waited >= 80)); do
        sleep 0.1
        waited=$((waited + 1))
    done
}

# What the application's field holds now.
app_text() {
    grep -oE 'app text=.*' "${app_log}" | tail -1 | sed 's/^app text=//'
}

wait_text_change() {
    local before="$1" waited=0
    while [[ "$(app_text)" == "${before}" ]] && ((waited < 30)); do
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

# A physical keyboard: one device for the whole session, fed a line at a time.
press() { echo "key $1 1" >&3; }
release() { echo "key $1 0" >&3; }
tap() {
    press "$1"
    echo "wait 60" >&3
    release "$1"
}

# Evdev key codes.
KEY_1=2
KEY_E=18
KEY_O=24
KEY_A=30
KEY_B=48

if [[ "${HOLD_PATH}" == up ]]; then
    # A compositor with no touch device leaves its virtual keyboard to tablet
    # mode, which this one is never in. Mode 2 offers it regardless.
    gdbus call --session --dest org.kde.KWin --object-path /VirtualKeyboard \
        --method org.freedesktop.DBus.Properties.Set \
        org.kde.kwin.VirtualKeyboard mode "<uint32 2>" > /dev/null 2>&1
fi

python3 "${tests_dir}/bottom-surface-stand-in.py" > "${stand_in_log}" 2>&1 &
if ! wait_for "${stand_in_log}" '^ready'; then
    echo "The Bottom Surface stand-in never took its name." >&2
    echo FAIL > "${PROBE_ROOT}/result"
    exit 1
fi

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

echo
if [[ "${HOLD_PATH}" == up ]]; then
    echo "A text field is focused, with the keys on screen"
else
    echo "A text field is focused, with a physical keyboard and the keys down"
fi
echo type > "${PROBE_ROOT}/app-type"
wait_keyboard active true
check "the Keyboard is taking the field's typing" "$(keyboard active)" "(<true>,)"
if [[ "${HOLD_PATH}" == up ]]; then
    wait_keyboard visible true
    check "the keys are on screen" "$(keyboard visible)" "(<true>,)"
else
    sleep 1
    check "the keys are not on screen" "$(keyboard visible)" "(<false>,)"
fi
sleep 0.5

echo
echo "A physical key reaches the application"
tap "${KEY_A}"
wait_for "${app_log}" 'app text=a$' 30
check "a tapped key types itself" "$(app_text)" "a"

echo
echo "A physical key held past the hold time opens no chooser"
panels_before="$(panels_now)"
held_from=$(now_ms)
press "${KEY_E}"
# Past the Keyboard's hold time, which is 600 ms unless configured, and
# short of the second after it that a chooser stays open for a held key. The
# compositor is asked what is on screen while the key is still down.
sleep 0.7
panels_now > "${PROBE_ROOT}/panels-during" &
probe_pid=$!
sleep 0.2
release "${KEY_E}"
held_for=$(($(now_ms) - held_from))
wait "${probe_pid}"
panels_during="$(cat "${PROBE_ROOT}/panels-during")"
sleep 0.4
after_hold="$(app_text)"
printf '  held for %d ms; the field then read: %s\n' "${held_for}" "${after_hold}"
# A held key may repeat, as any held key does; it types only its own letter.
check "the hold typed only its own letter" \
    "$([[ "${after_hold}" =~ ^ae+$ ]] && echo yes || echo "no: ${after_hold}")" "yes"
printf '  Keyboard surfaces on screen before the hold: %s\n' "${panels_before}"
printf '  Keyboard surfaces on screen during the hold: %s\n' "${panels_during}"
check "nothing new is on screen during the hold" "${panels_during%% *}" "${panels_before%% *}"
tap "${KEY_1}"
wait_text_change "${after_hold}"
sleep 0.3
check "a digit typed next arrives as a digit" "$(app_text)" "${after_hold}1"
if grep -qE 'Committing overlay selection' "${PROBE_ROOT}/compositor.log" 2>/dev/null; then
    printf '  the Keyboard says: %s\n' \
        "$(grep -oE 'Committing overlay selection.*' "${PROBE_ROOT}/compositor.log" | tail -1)"
fi

echo
echo "For the record, not checked: a two-second hold"
# A held key with no accents is left to the application, which repeats it. A
# held key with accents is measured the same way, for comparison.
for pair in "b ${KEY_B}" "o ${KEY_O}"; do
    letter="${pair%% *}"
    code="${pair##* }"
    before="$(app_text)"
    press "${code}"
    sleep 2
    release "${code}"
    sleep 0.5
    after="$(app_text)"
    typed="${after#"${before}"}"
    printf '  %s held for two seconds typed %d characters\n' "${letter}" "${#typed}"
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
