#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Runs inside the bus verify-orphan.sh starts. A second compositor waits on
# its own socket; the first runs the Keyboard. The first one's socket name is
# pointed at the second, as the wrapper's socket outlives a crashed KWin, and
# then the first is killed outright.

set -uo pipefail

runtime="${XDG_RUNTIME_DIR}"
compositor=(kwin_wayland --virtual --width 1280 --height 800
            --no-lockscreen --no-global-shortcuts --no-kactivities)

# What Plasma sets for the whole session, so applications survive a KWin
# restart.
export QT_WAYLAND_RECONNECT=1

"${compositor[@]}" --socket wayland-next > "${PROBE_ROOT}/second.log" 2>&1 &
second=$!
"${compositor[@]}" --socket wayland-orphan --inputmethod "${KEYBOARD_BIN}" \
    > "${PROBE_ROOT}/first.log" 2>&1 &
first=$!

keyboard=""
for _ in $(seq 150); do
    keyboard="$(pgrep -P "${first}" -f "${KEYBOARD_BIN}" | head -1)"
    [[ -n "${keyboard}" ]] && break
    sleep 0.1
done
if [[ -z "${keyboard}" ]]; then
    echo no > "${PROBE_ROOT}/started"
    kill "${first}" "${second}" 2>/dev/null
    exit 1
fi
echo yes > "${PROBE_ROOT}/started"
# Connected and drawn before the crash.
sleep 3

for _ in $(seq 50); do
    [[ -S "${runtime}/wayland-next" ]] && break
    sleep 0.1
done
ln -sfn wayland-next "${runtime}/wayland-orphan"
kill -9 "${first}"

gone=alive
for _ in $(seq 80); do
    if ! kill -0 "${keyboard}" 2>/dev/null; then
        gone=gone
        break
    fi
    sleep 0.1
done
echo "${gone}" > "${PROBE_ROOT}/old-keyboard"

kill -9 "${keyboard}" 2>/dev/null
kill "${second}" 2>/dev/null
wait 2>/dev/null
exit 0
