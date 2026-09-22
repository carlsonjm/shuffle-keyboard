#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Runs the drag handle in a compositor of its own.
#
# The handle is a layer surface created by a process whose other window is an
# input panel, and whether those two shell protocols can live in one client is
# the question this answers before anything is installed. Nothing here reaches
# the running session: its own compositor, its own bus, its own runtime and
# config directories, all thrown away afterwards.
set -euo pipefail

tests_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
project_dir="$(CDPATH= cd -- "${tests_dir}/.." && pwd)"

build_dir="${SHUFFLE_KEYBOARD_BUILD:-}"
scratch=""
cleanup() {
    [[ -n "${scratch}" && -d "${scratch}" ]] && rm -rf -- "${scratch}"
    return 0
}
trap cleanup EXIT

if [[ -z "${build_dir}" ]]; then
    scratch="$(mktemp -d "${TMPDIR:-/tmp}/shuffle-handle.XXXXXX")"
    build_dir="${scratch}/build"
    echo "Building the Keyboard..."
    cmake -S "${project_dir}" -B "${build_dir}" -G Ninja \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo > "${scratch}/cmake.log" 2>&1 \
        || { cat "${scratch}/cmake.log"; exit 1; }
    cmake --build "${build_dir}" > "${scratch}/build.log" 2>&1 \
        || { tail -40 "${scratch}/build.log"; exit 1; }
fi

keyboard_bin="${build_dir}/bin/shuffle-keyboard"
[[ -x "${keyboard_bin}" ]] || {
    echo "No Keyboard at ${keyboard_bin}." >&2
    exit 1
}

probe_root="$(mktemp -d "${TMPDIR:-/tmp}/shuffle-handle-run.XXXXXX")"
keep="${SHUFFLE_HANDLE_KEEP:-}"
trap 'cleanup; [[ -n "${keep}" ]] || rm -rf -- "${probe_root}"' EXIT
mkdir -p "${probe_root}/runtime" "${probe_root}/config"
chmod 700 "${probe_root}/runtime"

# The tablet's own logical size, so the numbers this prints are the numbers a
# reader can compare against the ones the surface publishes on hardware.
timeout 120s env \
    XDG_RUNTIME_DIR="${probe_root}/runtime" \
    XDG_CONFIG_HOME="${probe_root}/config" \
    XDG_DATA_HOME="${probe_root}/data" \
    PROBE_ROOT="${probe_root}" \
    KEYBOARD_BIN="${keyboard_bin}" \
    QT_QPA_PLATFORM=wayland \
    dbus-run-session -- kwin_wayland \
        --virtual --width 1463 --height 915 \
        --no-lockscreen --no-global-shortcuts --no-kactivities \
        --exit-with-session "${tests_dir}/handle-session.sh" \
    > "${probe_root}/compositor.log" 2>&1 || true

if [[ "$(cat "${probe_root}/result" 2>/dev/null)" != "PASS" ]]; then
    echo "The handle probe did not pass." >&2
    echo "--- compositor and session ---" >&2
    tail -60 "${probe_root}/compositor.log" >&2
    if [[ -s "${probe_root}/keyboard.log" ]]; then
        echo "--- the Keyboard said ---" >&2
        tail -40 "${probe_root}/keyboard.log" >&2
    fi
    exit 1
fi

tail -40 "${probe_root}/compositor.log"
echo
echo "The handle runs as its own layer surface, sized from the published dock,"
echo "and the compositor places it in the gutter above a reserved band."
echo "How it feels to reach for is physical, and is not this."
