#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Raises the Keyboard from its handle in a compositor of its own, with the
# Keyboard as that compositor's input method and an application holding the
# focus, and asks the compositor where the focus is at each step. Nothing here reaches the running
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
    scratch="$(mktemp -d "${TMPDIR:-/tmp}/shuffle-raise.XXXXXX")"
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

probe_root="$(mktemp -d "${TMPDIR:-/tmp}/shuffle-raise-run.XXXXXX")"
keep="${SHUFFLE_RAISE_KEEP:-}"
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
    SHUFFLE_PROBE_RAISE=1500 \
    SHUFFLE_PROBE_HANDLE=1 \
    SHUFFLE_PROBE_TEXT=hold \
    SHUFFLE_PROBE_DELAY=4000 \
    dbus-run-session -- kwin_wayland \
        --virtual --width 1463 --height 915 \
        --no-lockscreen --no-global-shortcuts --no-kactivities \
        --inputmethod "${keyboard_bin}" \
        --exit-with-session "${tests_dir}/raise-session.sh" \
    > "${probe_root}/compositor.log" 2>&1 || true

if [[ "$(cat "${probe_root}/result" 2>/dev/null)" != "PASS" ]]; then
    echo "The raise probe did not pass." >&2
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
echo "A raise from the handle holds the focus only while the Keyboard is up."
echo "Whether Plasma allows it straight after signing in needs a finger, and"
echo "is not this."
