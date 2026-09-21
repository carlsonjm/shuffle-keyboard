#!/usr/bin/env bash
# One command that builds this fork, runs its tests, and checks the two things
# its commit hook and its licence care about. Run it before treating a source,
# test or documentation change as complete.
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/shuffle-keyboard-verify.XXXXXX")"
trap 'rm -rf -- "${build_dir}"' EXIT

# The commit hook refuses unformatted C++, and a refusal at commit time is a
# refusal after the work is done. Fail here instead, where it is one command to
# fix with `git clang-format`.
mapfile -t sources < <(git -C "${project_root}" ls-files 'src/*.cpp' 'src/*.h' 'autotests/*.cpp')
clang-format --dry-run --Werror "${sources[@]/#/${project_root}/}"
echo "Shuffle Keyboard formatting matches .clang-format."

# Every file this fork adds carries an SPDX header, because the licence travels
# with what ships and a file without one cannot say what it is.
missing=()
while IFS= read -r file; do
    grep -qF "SPDX-License-Identifier" "${project_root}/${file}" || missing+=("${file}")
done < <(git -C "${project_root}" ls-files 'src/*.cpp' 'src/*.h' 'src/qml/*.qml' 'autotests/*.cpp')
if ((${#missing[@]})); then
    printf 'Missing SPDX-License-Identifier: %s\n' "${missing[@]}" >&2
    exit 1
fi
echo "Shuffle Keyboard licence headers are present."

cmake -S "${project_root}" -B "${build_dir}" -G Ninja \
    -DBUILD_TESTING=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo >/dev/null
cmake --build "${build_dir}" >/dev/null
ctest --test-dir "${build_dir}" --output-on-failure

echo "Shuffle Keyboard verification passed. Physical acceptance is separate:"
echo "docs/PHYSICAL_ACCEPTANCE.md, on a touch device, by hand."
