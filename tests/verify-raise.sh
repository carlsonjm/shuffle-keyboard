#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Raises the Keyboard the way a tap on its tray entry does, in a compositor of
# its own, with the Keyboard as that compositor's input method and an
# application holding the focus, and asks the compositor where the focus is at
# each step. A stand-in for Kadunce answers as Kadunce does.
# Nothing here reaches the running session: its own compositor, its own bus,
# its own runtime and config directories, all thrown away afterwards.
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

keep="${SHUFFLE_RAISE_KEEP:-}"
probe_roots=()
trap 'cleanup; [[ -n "${keep}" ]] || for root in "${probe_roots[@]}"; do rm -rf -- "${root}"; done' EXIT

# Runs the session once along one raise path: "direct", where Kadunce's ask of
# the compositor shows the keys and the focus stays where it was, or "cold",
# where that ask shows nothing, as straight after signing in, so the
# focus-holding raise the Keyboard does for a cold start is the one exercised.
run_path() {
    local path="$1"
    probe_root="$(mktemp -d "${TMPDIR:-/tmp}/shuffle-raise-run.XXXXXX")"
    probe_roots+=("${probe_root}")
    mkdir -p "${probe_root}/runtime" "${probe_root}/config"
    chmod 700 "${probe_root}/runtime"

    echo
    echo "=== ${path} raise ==="
    # The tablet's own logical size, so the numbers this prints are the numbers a
    # reader can compare against the ones the surface publishes on hardware.
    timeout 120s env \
        XDG_RUNTIME_DIR="${probe_root}/runtime" \
        XDG_CONFIG_HOME="${probe_root}/config" \
        XDG_DATA_HOME="${probe_root}/data" \
        PROBE_ROOT="${probe_root}" \
        KEYBOARD_BIN="${keyboard_bin}" \
        RAISE_PATH="${path}" \
        QT_QPA_PLATFORM=wayland \
        QT_FORCE_STDERR_LOGGING=1 \
        SHUFFLE_PROBE_KADUNCE_SERVICE=studio.warbler.test.Kadunce \
        SHUFFLE_PROBE_HOLD=1 \
        SHUFFLE_PROBE_TEXT=hold \
        SHUFFLE_PROBE_DELAY=4000 \
        dbus-run-session -- kwin_wayland \
            --virtual --width 1463 --height 915 \
            --no-lockscreen --no-global-shortcuts --no-kactivities \
            --inputmethod "${keyboard_bin}" \
            --exit-with-session "${tests_dir}/raise-session.sh" \
        > "${probe_root}/compositor.log" 2>&1 || true

    if [[ "$(cat "${probe_root}/result" 2>/dev/null)" != "PASS" ]]; then
        echo "The ${path} raise probe did not pass." >&2
        echo "--- compositor and session ---" >&2
        tail -60 "${probe_root}/compositor.log" >&2
        if [[ -s "${probe_root}/keyboard.log" ]]; then
            echo "--- the Keyboard said ---" >&2
            tail -40 "${probe_root}/keyboard.log" >&2
        fi
        exit 1
    fi
    tail -40 "${probe_root}/compositor.log"
}

run_path direct
run_path cold
echo
echo "A raise from the tray entry leaves the focus where it was; a cold start"
echo "holds it only while the Keyboard is up."
echo "Whether Plasma allows it straight after signing in needs a finger, and"
echo "is not this."
