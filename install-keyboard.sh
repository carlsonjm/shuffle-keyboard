#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Builds this fork and replaces the installed one, in your own prefix. No
# password, nothing outside your home directory, and no panels touched.
#
# Where the sign-in screen has its own copy under /usr/local, put there by
# Shuffle's install-signin-keyboard.sh, that copy is brought level too.
#
# It does not restart anything. The compositor started the Keyboard it is
# running and keeps that copy until the session does, so a file on disk is not
# a Keyboard in use until you have signed out and back in.
set -euo pipefail

project_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
prefix="${SHUFFLE_KEYBOARD_PREFIX:-${HOME}/.local}"
installed="${prefix}/bin/shuffle-keyboard"

before="missing"
if [[ -f "${installed}" ]]; then
    before="$(sha256sum "${installed}" | cut -d' ' -f1)"
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/shuffle-keyboard-install.XXXXXX")"
trap 'rm -rf -- "${work}"' EXIT

echo "[1/6] Building..."
# Configured for the system prefix and installed into yours, which is what the
# copy already on this machine was built by. It is not a detail: the system
# prefix is what makes the KDE install rules lay Qt's directories out Qt's way,
# and configuring straight for a home prefix puts the QML modules somewhere
# else entirely, beside the ones already there rather than over them.
cmake -S "${project_dir}" -B "${work}/build" -G Ninja \
    -DBUILD_TESTING=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    > "${work}/cmake.log" 2>&1 \
    || { tail -30 "${work}/cmake.log" >&2; exit 1; }
cmake --build "${work}/build" > "${work}/build.log" 2>&1 \
    || { tail -40 "${work}/build.log" >&2; exit 1; }

echo "[2/6] Laying the new one out beside the old..."
# Staged rather than written straight over the top, so that a build which
# half-installs cannot leave a mixture behind.
cmake --install "${work}/build" --prefix "${work}/staged" > /dev/null

staged_root="${work}/staged"
staged="${staged_root}/bin/shuffle-keyboard"
[[ -x "${staged}" ]] || {
    echo "The build produced no Keyboard. Nothing was replaced." >&2
    exit 1
}
after="$(sha256sum "${staged}" | cut -d' ' -f1)"

echo "[3/6] Replacing it..."
# Each destination is unlinked before it is written. The Keyboard you are
# using has its own binary open, and writing over a running executable is
# refused outright.
mkdir -p "${prefix}"
cp -a --remove-destination "${staged_root}/." "${prefix}/"

echo "[4/6] Checking what is actually on disk..."
[[ -f "${installed}" ]] || {
    echo "The Keyboard is not at ${installed}. Nothing will start." >&2
    exit 1
}
landed="$(sha256sum "${installed}" | cut -d' ' -f1)"
# Where the QML modules land matters as much as the binary: one laid out the
# other way is a second copy that nothing loads.
if [[ ! -f "${prefix}/lib/qt6/qml/org/kde/plasma/keyboard/lib/qmldir" ]]; then
    echo "The QML modules are not where Qt looks for them. Do not sign out yet." >&2
    exit 1
fi
if [[ "${landed}" != "${after}" ]]; then
    echo "What is on disk is not what was built. Do not sign out yet." >&2
    exit 1
fi
if [[ "${before}" == "${landed}" ]]; then
    echo "      byte for byte what was already there; nothing changed."
else
    echo "      replaced: ${before:0:12} -> ${landed:0:12}"
fi

echo "[5/6] Telling the desktop the entry is there..."
kbuildsycoca6 > /dev/null 2>&1 || true

echo "[6/6] Bringing the sign-in screen's copy level with it..."
# The sign-in screen, and every other account on this machine, cannot see the
# copy in your home directory and runs the one under /usr/local instead. Left
# behind, that copy keeps calling names the rest of the suite has moved on
# from: the dock no longer steps aside for its keys, and Kadunce takes its
# requests for keys as unasked and puts them away.
signin_copy=/usr/local/bin/shuffle-keyboard
signin_installer="${SHUFFLE_DIR:-${project_dir}/../shuffle}/install-signin-keyboard.sh"
if [[ ! -e "${signin_copy}" ]]; then
    echo "      no copy under /usr/local; nothing to bring level."
elif [[ -x "${signin_installer}" ]]; then
    SHUFFLE_KEYBOARD_DIR="${project_dir}" "${signin_installer}" \
        || echo "The copy under /usr/local was not replaced and is still the old one." >&2
else
    echo "${signin_copy} is an older copy, and install-signin-keyboard.sh is not at" >&2
    echo "${signin_installer} to replace it. Other accounts and the sign-in screen" >&2
    echo "keep the old Keyboard until it is run." >&2
fi

cat <<'DONE'

The Shuffle Keyboard on disk is now this build. The one you are typing on is
still the previous copy, because the compositor started it and holds it for
the life of the session. Signing out and back in is what makes it the one in
use.
DONE
