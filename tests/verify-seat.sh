#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Seats the Keyboard in a compositor of its own, as that compositor's input
# method, over a band that reserves the bottom of the output and then gives the
# reservation up.
#
# Where the compositor puts an input panel is decided by the compositor, and
# only a compositor can say where it went. Nothing here reaches the running
# session: its own compositor, its own bus, its own runtime and config
# directories, all thrown away afterwards.
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
    scratch="$(mktemp -d "${TMPDIR:-/tmp}/shuffle-seat.XXXXXX")"
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

probe_root="$(mktemp -d "${TMPDIR:-/tmp}/shuffle-seat-run.XXXXXX")"
keep="${SHUFFLE_SEAT_KEEP:-}"
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
    QT_FORCE_STDERR_LOGGING=1 \
    dbus-run-session -- kwin_wayland \
        --virtual --width 1463 --height 915 \
        --no-lockscreen --no-global-shortcuts --no-kactivities \
        --inputmethod "${keyboard_bin}" \
        --exit-with-session "${tests_dir}/seat-session.sh" \
    > "${probe_root}/compositor.log" 2>&1 || true

if [[ "$(cat "${probe_root}/result" 2>/dev/null)" != "PASS" ]]; then
    echo "The seat probe did not pass." >&2
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
echo "The Keyboard comes down onto the bottom of the output once the band"
echo "gives up its reservation. Whether that reads as one movement is physical,"
echo "and is not this."
