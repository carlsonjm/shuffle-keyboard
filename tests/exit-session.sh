#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Runs inside the compositor verify-exit.sh starts, with the Keyboard as its
# input method. Raises the keys so they hold the bottom region, then ends the
# session with them up. The Bottom Surface stand-in takes the hand-back but
# never answers it, as a surface behind a waiting compositor cannot.

set -uo pipefail

tests_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
stand_in_log="${PROBE_ROOT}/stand-in.log"
kadunce_log="${PROBE_ROOT}/kadunce.log"

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

tray_entry() {
    gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
        --method org.freedesktop.DBus.ListNames | grep -oE 'org\.kde\.StatusNotifierItem-[0-9]+-1' | head -1
}

gdbus call --session --dest org.kde.KWin --object-path /VirtualKeyboard \
    --method org.freedesktop.DBus.Properties.Set \
    org.kde.kwin.VirtualKeyboard mode "<uint32 2>" > /dev/null 2>&1

STAND_IN_HOLD_RELEASE=1 python3 "${tests_dir}/bottom-surface-stand-in.py" > "${stand_in_log}" 2>&1 &
python3 "${tests_dir}/kadunce-stand-in.py" > "${kadunce_log}" 2>&1 &
wait_for "${stand_in_log}" '^ready' && wait_for "${kadunce_log}" '^ready' \
    || { echo "A stand-in never took its name." >&2; exit 1; }

QML_XHR_ALLOW_FILE_READ=1 qml6 "${tests_dir}/app-stand-in.qml" -- "${PROBE_ROOT}/app-type" \
    > "${PROBE_ROOT}/app.log" 2>&1 &
sleep 2

gdbus call --session --dest studio.warbler.BottomSurface --object-path /BottomSurface \
    --method studio.warbler.test.Control.report true 60 544 920 > /dev/null 2>&1
gdbus call --session --dest studio.warbler.test.Kadunce --object-path /Kadunce \
    --method studio.warbler.test.Control.setAsking true > /dev/null 2>&1
gdbus call --session --dest "$(tray_entry)" --object-path /StatusNotifierItem \
    --method org.kde.StatusNotifierItem.Activate 0 0 > /dev/null 2>&1

if wait_for "${stand_in_log}" '^yielded=1' 80; then
    echo up > "${PROBE_ROOT}/raised"
fi
date +%s.%N > "${PROBE_ROOT}/ended"
