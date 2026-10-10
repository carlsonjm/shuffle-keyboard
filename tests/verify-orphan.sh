#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Crashes a compositor of its own with the Keyboard running as its input
# method, while a second compositor stands behind the same socket name, as
# kwin_wayland_wrapper keeps the socket and starts KWin again after a crash.
# Plasma asks Qt applications to reconnect when that happens. The Keyboard
# must not: the compositor that comes back starts a Keyboard of its own, and
# the old one, reconnected as an ordinary window, stays running beside it.
# Nothing here reaches the running session.
set -euo pipefail

tests_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
project_dir="$(CDPATH= cd -- "${tests_dir}/.." && pwd)"

build_dir="${SHUFFLE_KEYBOARD_BUILD:-}"
scratch=""
probe_root="$(mktemp -d "${TMPDIR:-/tmp}/shuffle-orphan-run.XXXXXX")"
trap '[[ -n "${scratch}" ]] && rm -rf -- "${scratch}"; [[ -n "${SHUFFLE_ORPHAN_KEEP:-}" ]] || rm -rf -- "${probe_root}"' EXIT

if [[ -z "${build_dir}" ]]; then
    scratch="$(mktemp -d "${TMPDIR:-/tmp}/shuffle-orphan.XXXXXX")"
    build_dir="${scratch}/build"
    echo "Building the Keyboard..."
    cmake -S "${project_dir}" -B "${build_dir}" -G Ninja \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo > "${scratch}/cmake.log" 2>&1 \
        || { cat "${scratch}/cmake.log"; exit 1; }
    cmake --build "${build_dir}" > "${scratch}/build.log" 2>&1 \
        || { tail -40 "${scratch}/build.log"; exit 1; }
fi

keyboard_bin="${build_dir}/bin/shuffle-keyboard"
[[ -x "${keyboard_bin}" ]] || { echo "No Keyboard at ${keyboard_bin}." >&2; exit 1; }

mkdir -p "${probe_root}/runtime" "${probe_root}/config"
chmod 700 "${probe_root}/runtime"

timeout 120s env \
    XDG_RUNTIME_DIR="${probe_root}/runtime" \
    XDG_CONFIG_HOME="${probe_root}/config" \
    XDG_DATA_HOME="${probe_root}/data" \
    PROBE_ROOT="${probe_root}" \
    KEYBOARD_BIN="${keyboard_bin}" \
    QT_FORCE_STDERR_LOGGING=1 \
    dbus-run-session -- "${tests_dir}/orphan-session.sh" \
    > "${probe_root}/session.log" 2>&1 || true

pass=0
fail=0
check() {
    if [[ "$2" == "$3" ]]; then
        printf '  ok   %s\n' "$1"; pass=$((pass + 1))
    else
        printf '  FAIL %s\n         wanted: %s\n         got:    %s\n' "$1" "$3" "$2"; fail=$((fail + 1))
    fi
}

echo "The compositor crashes with the Keyboard running, and another takes its socket"
check "the first compositor started the Keyboard" "$(cat "${probe_root}/started" 2>/dev/null)" "yes"
check "the old Keyboard left with the compositor that started it" \
    "$(cat "${probe_root}/old-keyboard" 2>/dev/null)" "gone"

echo
echo "${pass} passed, ${fail} failed"
if ((fail > 0)); then
    tail -40 "${probe_root}/session.log" >&2
    tail -20 "${probe_root}/first.log" >&2 || true
    exit 1
fi
