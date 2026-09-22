#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Runs inside the nested compositor. Started by verify-handle.sh, never alone.
set -uo pipefail

tests_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
keyboard_log="${PROBE_ROOT}/keyboard.log"
stand_in_log="${PROBE_ROOT}/stand-in.log"

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

contains() {
    local name="$1" haystack="$2" needle="$3"
    if [[ "${haystack}" == *"${needle}"* ]]; then
        printf '  ok   %s\n' "${name}"
        pass=$((pass + 1))
    else
        printf '  FAIL %s\n         wanted to find: %s\n         in: %s\n' \
            "${name}" "${needle}" "${haystack}"
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

# The handle reports on every change, so the last line is what it is doing now.
handle_now() {
    grep -oE 'handle placed=.*' "${keyboard_log}" 2>/dev/null | tail -1
}

# Waits for the handle to settle on a state rather than reading the first one:
# a report crosses a process boundary and a read that elapsed no time can only
# see what came before it.
handle_settles() {
    local name="$1" needle="$2"
    local waited=0 line=""
    while ((waited < 80)); do
        line="$(handle_now)"
        [[ "${line}" == *"${needle}"* ]] && break
        sleep 0.1
        waited=$((waited + 1))
    done
    contains "${name}" "${line}" "${needle}"
}

report() {
    gdbus call --session --dest studio.warbler.BottomSurface \
        --object-path /BottomSurface \
        --method studio.warbler.test.Control.report "$@" > /dev/null 2>&1
}

python3 "${tests_dir}/bottom-surface-stand-in.py" > "${stand_in_log}" 2>&1 &
if ! wait_for "${stand_in_log}" '^ready'; then
    echo "The Bottom Surface stand-in never took its name." >&2
    cat "${stand_in_log}" >&2
    echo FAIL > "${PROBE_ROOT}/result"
    exit 1
fi

# Qt is built against journald here, so an application's own messages go to
# the journal and its stderr stays empty. A probe that reads stdout has to say
# it wants stdout.
QT_FORCE_STDERR_LOGGING=1 SHUFFLE_PREVIEW_MODE=1 SHUFFLE_PROBE_HANDLE=1 \
    "${KEYBOARD_BIN}" > "${keyboard_log}" 2>&1 &
keyboard_pid=$!

echo
echo "The Keyboard can have a surface of its own"
if ! wait_for "${keyboard_log}" 'handle placed='; then
    echo "  FAIL the handle window was never created"
    sed -n '1,40p' "${keyboard_log}"
    echo FAIL > "${PROBE_ROOT}/result"
    exit 1
fi
contains "the compositor gave it a layer surface" "$(handle_now)" "placed=true"
contains "with no surface to report a dock, it stays away" "$(handle_now)" "visible=false"

echo
echo "It takes its width from the published dock"
report true false 60 544 920
handle_settles "it appears once a dock is published" "visible=true"
contains "it is as wide as the application row" "$(handle_now)" "width=376"
contains "it starts where the row starts" "$(handle_now)" "left=544"
contains "it is the height of the gutter" "$(handle_now)" "height=10"

echo
echo "It retires before the region darkens"
report true true 60 544 920
handle_settles "a blackout takes the handle with it" "visible=false"
report true false 60 544 920
handle_settles "and it comes back when the region clears" "visible=true"

echo
echo "It follows the row as it grows"
report true false 60 500 964
handle_settles "a wider dock is a wider handle" "width=464"

echo
echo "It sits above a reserved band, not on top of it"
qml6 "${tests_dir}/reserved-band-stand-in.qml" > "${PROBE_ROOT}/band.log" 2>&1 &
band_pid=$!
sleep 2

echo
echo "The compositor put it where it was asked to"
if gdbus call --session --dest org.kde.KWin --object-path /Scripting \
        --method org.kde.kwin.Scripting.loadScript \
        "${tests_dir}/handle-probe.js" "handleprobe" > /dev/null 2>&1 \
    && gdbus call --session --dest org.kde.KWin --object-path /Scripting \
        --method org.kde.kwin.Scripting.start > /dev/null 2>&1; then
    sleep 1
    placement="$(grep -oE 'record window [0-9-]+,[0-9-]+ [0-9]+x10' "${stand_in_log}" | tail -1)"
    # Nothing reserves a strut in here, so the gutter the handle asks for is
    # measured from the bottom of the output itself: 915 less its own 10. The
    # surface spans the output; the handle inside it does not.
    # The output is 915 tall, the band reserves 60 of it, and the handle asks
    # for the ten above that. A handle that ignored the reservation would be
    # at 905, which is what it measured before anything reserved anything.
    check "it is the gutter above the reserved band, across the output" \
        "${placement}" "record window 0,845 1463x10"
    # The bar reserves its own six pixels on top of the band's sixty, so the
    # work area stops at the bar's top edge: 915 less 66.
    check "the work area stops at the top of the bar" \
        "$(grep -oE 'record area bottom=[0-9]+' "${stand_in_log}" | tail -1)" \
        "record area bottom=849"
else
    echo "  FAIL the compositor would not run the placement script"
    fail=$((fail + 1))
fi

kill "${band_pid}" 2>/dev/null

echo
echo "The compositor offers what the handle asks it for"
if gdbus introspect --session --dest org.kde.KWin \
        --object-path /VirtualKeyboard 2>/dev/null | grep -q 'forceActivate'; then
    echo "  ok   the keyboard can be raised with nothing asking for text"
    pass=$((pass + 1))
else
    echo "  FAIL this compositor has no forceActivate, so the handle cannot raise"
    fail=$((fail + 1))
fi

echo
echo "It is still there after all of that"
if kill -0 "${keyboard_pid}" 2>/dev/null; then
    echo "  ok   the Keyboard is still running"
    pass=$((pass + 1))
else
    echo "  FAIL the Keyboard exited"
    fail=$((fail + 1))
fi

kill "${keyboard_pid}" 2>/dev/null

echo
printf '%d passed, %d failed\n' "${pass}" "${fail}"
if ((fail > 0)); then
    echo FAIL > "${PROBE_ROOT}/result"
    exit 1
fi
echo PASS > "${PROBE_ROOT}/result"
