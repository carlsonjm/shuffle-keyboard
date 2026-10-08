#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Runs inside the compositor verify-raise.sh starts, with the Keyboard as its
# input method. Nothing here reaches the running session.
#
# A tap on the keys' tray entry asks for them through Kadunce, which asks the
# compositor. Plasma shows a raised keyboard only once a text field has asked
# for it, so on a cold start the Keyboard raises by taking typing focus into a
# field of its own. That is only acceptable if the focus goes back where it was
# when the keyboard goes. An application holds the focus here, a stand-in for
# Kadunce answers the request, and the compositor is asked who holds the focus
# at each step.

set -uo pipefail

tests_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
stand_in_log="${PROBE_ROOT}/stand-in.log"
kadunce_log="${PROBE_ROOT}/kadunce.log"
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

# The keys' entry in the system tray, by the name the Keyboard gave it.
tray_entry() {
    gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
        --method org.freedesktop.DBus.ListNames | grep -oE 'org\.kde\.StatusNotifierItem-[0-9]+-1' | head -1
}

# A tap on the entry. On a cold start Kadunce's ask of the compositor shows
# nothing, and the Keyboard's own hold is left to raise the keys.
tray_tap() {
    gdbus call --session --dest co.goodinput.test.Kadunce --object-path /Kadunce \
        --method co.goodinput.test.Control.setAsking "$([[ "$1" == ask ]] && echo true || echo false)" > /dev/null 2>&1
    gdbus call --session --dest "$(tray_entry)" --object-path /StatusNotifierItem \
        --method org.kde.StatusNotifierItem.Activate 0 0 > /dev/null 2>&1
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

python3 "${tests_dir}/kadunce-stand-in.py" > "${kadunce_log}" 2>&1 &
if ! wait_for "${kadunce_log}" '^ready'; then
    echo "The Kadunce stand-in never took its name." >&2
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

# A dock is published, so the keys take its region while they are up.
control report true 60 544 920
echo
echo "The keys have an entry in the system tray"
check "the entry is on the bus" "$([[ -n "$(tray_entry)" ]] && echo yes)" "yes"
check "it is called Keyboard" "$(gdbus call --session --dest "$(tray_entry)" --object-path /StatusNotifierItem \
    --method org.freedesktop.DBus.Properties.Get org.kde.StatusNotifierItem Title 2>/dev/null)" "(<'Keyboard'>,)"
if [[ "${RAISE_PATH:-cold}" == direct ]]; then
    echo
    echo "A tap on the tray entry raises the Keyboard and leaves the focus where it was"
    tray_tap ask
    wait_keyboard true
    check "the Keyboard is up" "$(keyboard visible)" "(<true>,)"
    check "the application keeps the focus" "$(focus_now)" "app"
else
    echo
    echo "A cold start raises the Keyboard by taking the focus"
    tray_tap quiet
    wait_keyboard true
    check "the Keyboard is up" "$(keyboard visible)" "(<true>,)"
    check "a text field is what asked for it" "$(keyboard activeClientSupportsTextInput)" "(<true>,)"
    focus="$(focus_now)"
    if [[ "${focus}" != "app" && "${focus}" != "none" ]]; then
        printf '  ok   %s\n' "the Keyboard holds the focus while it is up (${focus})"
        pass=$((pass + 1))
    else
        printf '  FAIL %s\n         got: %s\n' "the Keyboard holds the focus while it is up" "${focus}"
        fail=$((fail + 1))
    fi
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
# The dock steps aside only while the keys are up. The application's field is
# still focused, so this is the keys going, not the request.
check "the dock comes back" "$(grep -oE '^yielded=[01]' "${stand_in_log}" | tail -1)" "yielded=0"

echo
echo "The Keyboard still types into an application afterwards"
# The hold's focus moved this process's own focus with it. If it did not come
# back, the Keyboard would show for a text field and type nowhere.
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

echo
echo "A tap on the tray entry with the keys up puts them away"
tray_tap ask
wait_keyboard false
check "the Keyboard is down" "$(keyboard visible)" "(<false>,)"
sleep 0.5
check "the application keeps the focus" "$(focus_now)" "app"

echo
echo "A tap on the tray entry with a text box ready leaves it the focus"
tray_tap ask
wait_keyboard true
check "the tap brings the Keyboard up" "$(keyboard visible)" "(<true>,)"
sleep 0.5
check "the text box keeps the focus" "$(focus_now)" "app"

kill "${app_pid}" 2>/dev/null

echo
printf '%d passed, %d failed\n' "${pass}" "${fail}"
if ((fail > 0)); then
    echo FAIL > "${PROBE_ROOT}/result"
    exit 1
fi
echo PASS > "${PROBE_ROOT}/result"
