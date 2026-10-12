#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Touches the keys in a compositor of its own, with the Keyboard as that
# compositor's input method, and asks the compositor for the screen while the
# finger is down: a pressed key, a growing flick and a held key's accents must
# each show. This runs the Keyboard as built, with its interface compiled the
# way it ships, which the key field's own test, reading the source, does not.
# Nothing here reaches the running session: its own compositor, its own bus,
# its own runtime and config directories, all thrown away afterwards.
set -euo pipefail

tests_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
project_dir="$(CDPATH= cd -- "${tests_dir}/.." && pwd)"

build_dir="${SHUFFLE_KEYBOARD_BUILD:-}"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/shuffle-feedback.XXXXXX")"
keep="${SHUFFLE_FEEDBACK_KEEP:-}"
probe_roots=()
cleanup() {
    rm -rf -- "${scratch}"
    [[ -n "${keep}" ]] || for root in "${probe_roots[@]}"; do rm -rf -- "${root}"; done
    return 0
}
trap cleanup EXIT

if [[ -z "${build_dir}" ]]; then
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

# The finger is KWin's fake-input protocol.
protocol="$(pkg-config --variable=pkgdatadir plasma-wayland-protocols 2>/dev/null || true)/fake-input.xml"
[[ -f "${protocol}" ]] || protocol=/usr/share/plasma-wayland-protocols/fake-input.xml
if [[ ! -f "${protocol}" ]] || ! command -v wayland-scanner > /dev/null; then
    echo "Skipped: no fake-input protocol or wayland-scanner, so no key can be touched." >&2
    exit 77
fi
if ! python3 -c 'from gi.repository import Gio' 2> /dev/null; then
    echo "Skipped: no python-gobject, so the screen cannot be read." >&2
    exit 77
fi
wayland-scanner client-header "${protocol}" "${scratch}/fake-input-client-protocol.h"
wayland-scanner private-code "${protocol}" "${scratch}/fake-input-protocol.c"
cc -I"${scratch}" -o "${scratch}/fake-input" "${tests_dir}/fake-input.c" \
    "${scratch}/fake-input-protocol.c" -lwayland-client -lm

# Once as it ships, with the interface compiled ahead of time, and once with
# that compiled code set aside so the engine reads the source, as the key
# field's own test does. A difference between the two is the compiler's.
run_mode() {
    local mode="$1"
    probe_root="$(mktemp -d "${TMPDIR:-/tmp}/shuffle-feedback-run.XXXXXX")"
    probe_roots+=("${probe_root}")
    mkdir -p "${probe_root}/runtime" "${probe_root}/config"
    chmod 700 "${probe_root}/runtime"
    local source_only=()
    [[ "${mode}" == compiled ]] || source_only=(QML_DISABLE_DISK_CACHE=1)

    echo
    echo "=== the interface ${mode} ==="
    # The tablet's own logical size, as the other sealed sessions use.
    timeout 120s env \
        XDG_RUNTIME_DIR="${probe_root}/runtime" \
        XDG_CONFIG_HOME="${probe_root}/config" \
        XDG_DATA_HOME="${probe_root}/data" \
        PROBE_ROOT="${probe_root}" \
        SCREEN_HEIGHT=915 \
        FAKE_INPUT_BIN="${scratch}/fake-input" \
        KWIN_WAYLAND_NO_PERMISSION_CHECKS=1 \
        QT_QPA_PLATFORM=wayland \
        QT_FORCE_STDERR_LOGGING=1 \
        SHUFFLE_PROBE_KADUNCE_SERVICE=co.goodinput.test.Kadunce \
        "${source_only[@]}" \
        dbus-run-session -- kwin_wayland \
            --virtual --width 1463 --height 915 \
            --no-lockscreen --no-global-shortcuts --no-kactivities \
            --inputmethod "${keyboard_bin}" \
            --exit-with-session "${tests_dir}/feedback-session.sh" \
        > "${probe_root}/compositor.log" 2>&1 || true

    cat "${probe_root}/report.log" 2>/dev/null || true
    case "$(cat "${probe_root}/result" 2>/dev/null)" in
        PASS) ;;
        SKIP)
            cat "${probe_root}/grab.log" >&2
            tail -20 "${probe_root}/compositor.log" >&2
            skipped=1
            ;;
        *)
            echo "The press feedback probe with the interface ${mode} did not pass." >&2
            if ! grep -qE 'passed, .* failed$' "${probe_root}/report.log" 2>/dev/null; then
                echo "--- compositor and session ---" >&2
                tail -60 "${probe_root}/compositor.log" >&2
            fi
            grep -iE 'qml|\.js:' "${probe_root}/compositor.log" | tail -20 >&2 || true
            failed=1
            ;;
    esac
}

failed=0
skipped=0
run_mode compiled
run_mode "read from source"
((failed == 0)) || exit 1
((skipped == 0)) || exit 77
echo
echo "A pressed key, a growing flick and a held key's accents all show on"
echo "screen, from the Keyboard as built. How they look under a finger is"
echo "physical, and is not this."
