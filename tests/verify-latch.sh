#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Puts the keys away with Hide and with the tray entry while the trackpad is
# latched, in a compositor of its own with the Keyboard as that compositor's
# input method, once clicking Hide with a mouse and once tapping it with a
# finger, and asks the compositor whether the keys stay away.
# Nothing here reaches the running session: its own compositor, its own bus,
# its own runtime and config directories, all thrown away afterwards.
set -euo pipefail

tests_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
project_dir="$(CDPATH= cd -- "${tests_dir}/.." && pwd)"

build_dir="${SHUFFLE_KEYBOARD_BUILD:-}"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/shuffle-latch.XXXXXX")"
keep="${SHUFFLE_LATCH_KEEP:-}"
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

# The mouse and the finger are KWin's fake-input protocol.
protocol="$(pkg-config --variable=pkgdatadir plasma-wayland-protocols 2>/dev/null || true)/fake-input.xml"
[[ -f "${protocol}" ]] || protocol=/usr/share/plasma-wayland-protocols/fake-input.xml
if [[ ! -f "${protocol}" ]] || ! command -v wayland-scanner > /dev/null; then
    echo "Skipped: no fake-input protocol or wayland-scanner, so Hide cannot be touched." >&2
    exit 77
fi
wayland-scanner client-header "${protocol}" "${scratch}/fake-input-client-protocol.h"
wayland-scanner private-code "${protocol}" "${scratch}/fake-input-protocol.c"
cc -I"${scratch}" -o "${scratch}/fake-input" "${tests_dir}/fake-input.c" \
    "${scratch}/fake-input-protocol.c" -lwayland-client -lm

# The session's bus starts nothing on its own, so the pointer portal that
# answers the latch is the stand-in, never a real portal whose permission
# prompt would open inside the session and take the focus.
cat > "${scratch}/bus.conf" <<'EOF'
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>session</type>
  <keep_umask/>
  <listen>unix:tmpdir=/tmp</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow send_destination="*" eavesdrop="true"/>
    <allow eavesdrop="true"/>
    <allow own="*"/>
  </policy>
</busconfig>
EOF

run_path() {
    local path="$1"
    probe_root="$(mktemp -d "${TMPDIR:-/tmp}/shuffle-latch-run.XXXXXX")"
    probe_roots+=("${probe_root}")
    mkdir -p "${probe_root}/runtime" "${probe_root}/config"
    chmod 700 "${probe_root}/runtime"

    echo
    echo "=== Hide by ${path} ==="
    # The tablet's own logical size, as the other sealed sessions use.
    timeout 120s env \
        XDG_RUNTIME_DIR="${probe_root}/runtime" \
        XDG_CONFIG_HOME="${probe_root}/config" \
        XDG_DATA_HOME="${probe_root}/data" \
        PROBE_ROOT="${probe_root}" \
        LATCH_PATH="${path}" \
        SCREEN_HEIGHT=915 \
        FAKE_INPUT_BIN="${scratch}/fake-input" \
        KWIN_WAYLAND_NO_PERMISSION_CHECKS=1 \
        QT_QPA_PLATFORM=wayland \
        QT_FORCE_STDERR_LOGGING=1 \
        SHUFFLE_PROBE_KADUNCE_SERVICE=studio.warbler.test.Kadunce \
        dbus-run-session --config-file="${scratch}/bus.conf" -- kwin_wayland \
            --virtual --width 1463 --height 915 \
            --no-lockscreen --no-global-shortcuts --no-kactivities \
            --inputmethod "${keyboard_bin}" \
            --exit-with-session "${tests_dir}/latch-session.sh" \
        > "${probe_root}/compositor.log" 2>&1 || true

    cat "${probe_root}/report.log" 2>/dev/null || true
    if [[ "$(cat "${probe_root}/result" 2>/dev/null)" != "PASS" ]]; then
        echo "The latch probe with Hide by ${path} did not pass." >&2
        if ! grep -qE 'passed, .* failed$' "${probe_root}/report.log" 2>/dev/null; then
            echo "--- compositor and session ---" >&2
            tail -60 "${probe_root}/compositor.log" >&2
        fi
        failed=1
    fi
}

failed=0
run_path click
run_path touch
echo
if ((failed)); then
    exit 1
fi
echo "Hide and the tray entry put the keys away with the trackpad latched, by"
echo "click or by touch, and they stay away. How Hide feels under a finger is"
echo "physical, and is not this."
