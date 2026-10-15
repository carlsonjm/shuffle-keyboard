#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Raises and puts away the Keyboard in a compositor of its own, as that
# compositor's input method, with no Bottom Surface installed: plain Plasma,
# which is a supported setup and not a degraded one. A stand-in for Plasma's
# shell keeps a bottom panel and a top panel and says what happens to them.
# The bottom panel must autohide while the keys are up and come back to its own
# mode afterwards, and come back too when the Keyboard is killed with the keys
# up. Nothing here reaches the running session: its own compositor, its own
# bus, its own runtime, config and state directories, all thrown away
# afterwards.
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
    scratch="$(mktemp -d "${TMPDIR:-/tmp}/shuffle-panels.XXXXXX")"
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

probe_root="$(mktemp -d "${TMPDIR:-/tmp}/shuffle-panels-run.XXXXXX")"
keep="${SHUFFLE_PANELS_KEEP:-}"
trap 'cleanup; [[ -n "${keep}" ]] || rm -rf -- "${probe_root}"' EXIT
mkdir -p "${probe_root}/runtime" "${probe_root}/config" "${probe_root}/state"
chmod 700 "${probe_root}/runtime"

# The state directory is the session's own: the Keyboard keeps the panels'
# modes there, and a run must never find or leave one in the real home.
timeout 120s env \
    XDG_RUNTIME_DIR="${probe_root}/runtime" \
    XDG_CONFIG_HOME="${probe_root}/config" \
    XDG_DATA_HOME="${probe_root}/data" \
    XDG_STATE_HOME="${probe_root}/state" \
    PROBE_ROOT="${probe_root}" \
    KEYBOARD_BIN="${keyboard_bin}" \
    QT_QPA_PLATFORM=wayland \
    QT_FORCE_STDERR_LOGGING=1 \
    dbus-run-session -- kwin_wayland \
        --virtual --width 1463 --height 915 \
        --no-lockscreen --no-global-shortcuts --no-kactivities \
        --inputmethod "${keyboard_bin}" \
        --exit-with-session "${tests_dir}/panels-session.sh" \
    > "${probe_root}/compositor.log" 2>&1 || true

cat "${probe_root}/report.log" 2>/dev/null || true
if [[ "$(cat "${probe_root}/result" 2>/dev/null)" != "PASS" ]]; then
    echo "The panel probe did not pass." >&2
    echo "--- the shell stand-in saw ---" >&2
    cat "${probe_root}/shell.log" >&2 2>/dev/null || true
    echo "--- compositor and session ---" >&2
    tail -60 "${probe_root}/compositor.log" >&2
    exit 1
fi

echo
echo "With no Bottom Surface, Plasma's bottom panel steps aside for the keys and"
echo "comes back to its own mode. Whether that reads as one movement is physical,"
echo "and is not this."
