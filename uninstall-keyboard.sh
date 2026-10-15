#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Shuffle Project
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Removes the Shuffle Keyboard install-keyboard.sh put in your own prefix:
# exactly the files it listed there, and nothing else. No password, nothing
# outside your home directory.
#
# It leaves the sign-in screen's copy under /usr/local alone; Shuffle's
# uninstall-signin-keyboard.sh removes that one. And it refuses while the
# desktop is still set to start the Shuffle Keyboard, since a tablet that signs
# in with its keyboard gone has no keys to type with.
set -euo pipefail

prefix="${SHUFFLE_KEYBOARD_PREFIX:-${HOME}/.local}"
manifest="${prefix}/share/shuffle-keyboard/installed-files.txt"

[[ -f "${manifest}" ]] || {
    echo "No record of an install at ${manifest}; nothing was removed." >&2
    echo "A copy installed before install-keyboard.sh kept that record is" >&2
    echo "listed by running install-keyboard.sh once more." >&2
    exit 1
}

chosen="$(kreadconfig6 --file kwinrc --group Wayland --key InputMethod 2>/dev/null || true)"
if [[ "${chosen}" == *org.shuffle.Keyboard* && -z "${SHUFFLE_KEYBOARD_UNINSTALL_ANYWAY:-}" ]]; then
    cat >&2 <<STOP
The desktop is still set to start the Shuffle Keyboard (${chosen}).
Choose another, or None, in System Settings > Keyboard > Virtual Keyboard
first, so the next sign-in does not come up with no keys. Nothing was removed.
STOP
    exit 1
fi

removed=0
while IFS= read -r file; do
    case "${file}" in "" | /* | *..*) continue ;; esac
    [[ -e "${prefix}/${file}" || -L "${prefix}/${file}" ]] || continue
    rm -f -- "${prefix}/${file}"
    removed=$((removed + 1))
    dir="$(dirname -- "${prefix}/${file}")"
    while [[ "${dir}" != "${prefix}" ]] && rmdir -- "${dir}" 2> /dev/null; do
        dir="$(dirname -- "${dir}")"
    done
done < "${manifest}"
rm -f -- "${manifest}"
dir="$(dirname -- "${manifest}")"
while [[ "${dir}" != "${prefix}" ]] && rmdir -- "${dir}" 2> /dev/null; do
    dir="$(dirname -- "${dir}")"
done

kbuildsycoca6 > /dev/null 2>&1 || true

echo "Removed ${removed} file(s) from ${prefix}."
if [[ -e /usr/local/bin/shuffle-keyboard ]]; then
    echo "The sign-in screen's copy under /usr/local is still there; Shuffle's"
    echo "uninstall-signin-keyboard.sh removes it."
fi
echo "The Keyboard running now keeps running until you sign out."
