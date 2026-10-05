#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Ends a compositor of its own with the Keyboard up as its input method, and
# times how long the compositor takes to go. KWin stops its input method with
# SIGTERM and waits for it, up to 30 seconds, holding the whole session still,
# so a Keyboard slow to leave is a slow sign-out. The Bottom Surface stand-in
# never answers the region's hand-back, as a surface that needs the waiting
# compositor cannot. Nothing here reaches the running session.
set -euo pipefail

tests_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
project_dir="$(CDPATH= cd -- "${tests_dir}/.." && pwd)"

build_dir="${SHUFFLE_KEYBOARD_BUILD:-}"
scratch=""
probe_root="$(mktemp -d "${TMPDIR:-/tmp}/shuffle-exit-run.XXXXXX")"
trap '[[ -n "${scratch}" ]] && rm -rf -- "${scratch}"; [[ -n "${SHUFFLE_EXIT_KEEP:-}" ]] || rm -rf -- "${probe_root}"' EXIT

if [[ -z "${build_dir}" ]]; then
    scratch="$(mktemp -d "${TMPDIR:-/tmp}/shuffle-exit.XXXXXX")"
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
    QT_QPA_PLATFORM=wayland \
    QT_FORCE_STDERR_LOGGING=1 \
    SHUFFLE_PROBE_KADUNCE_SERVICE=studio.warbler.test.Kadunce \
    SHUFFLE_PROBE_TEXT=exit \
    dbus-run-session -- kwin_wayland \
        --virtual --width 1463 --height 915 \
        --no-lockscreen --no-global-shortcuts --no-kactivities \
        --inputmethod "${keyboard_bin}" \
        --exit-with-session "${tests_dir}/exit-session.sh" \
    > "${probe_root}/compositor.log" 2>&1 || true
gone="$(date +%s.%N)"

pass=0
fail=0
check() {
    if [[ "$2" == "$3" ]]; then
        printf '  ok   %s\n' "$1"; pass=$((pass + 1))
    else
        printf '  FAIL %s\n         wanted: %s\n         got:    %s\n' "$1" "$3" "$2"; fail=$((fail + 1))
    fi
}

echo "The session ends with the keys up"
check "the keys took the bottom region" "$(cat "${probe_root}/raised" 2>/dev/null)" "up"
check "the Keyboard handed the region back on its way out" \
    "$(grep -c '^release asked' "${probe_root}/stand-in.log" 2>/dev/null)" "1"
took="$(python3 -c "print(round(${gone} - $(cat "${probe_root}/ended" 2>/dev/null || echo "${gone}"), 1))")"
check "the compositor was gone within 5 seconds (took ${took} s)" \
    "$(python3 -c "print(${took} < 5)")" "True"

echo
echo "${pass} passed, ${fail} failed"
if ((fail > 0)); then
    tail -40 "${probe_root}/compositor.log" >&2
    exit 1
fi
