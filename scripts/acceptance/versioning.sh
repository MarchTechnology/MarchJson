#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
VERSION_FILE="$ROOT/VERSION"

fail() {
    printf 'VERSIONING_ACCEPTANCE=FAIL %s\n' "$*" >&2
    exit 1
}

[ -f "$VERSION_FILE" ] || fail "VERSION file missing"

version="$(tr -d '[:space:]' < "$VERSION_FILE")"

printf '%s\n' "$version" |
    grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$' ||
    fail "VERSION is not valid SemVer: $version"

grep -Fq 'MARCHJSON_VERSION_FILE="$MARCHJSON_ROOT/VERSION"' "$ROOT/bash/marchjson.sh" ||
    fail "Bash runtime does not use VERSION"

grep -Fq "MarchJsonVersionFile = Join-Path" "$ROOT/powershell/MarchJson.ps1" ||
    fail "PowerShell runtime does not use VERSION"

grep -Fq 'CHANGELOG.md' "$ROOT/README.md" ||
    fail "README does not document CHANGELOG"

# shellcheck disable=SC1090
source "$ROOT/bash/marchjson.sh"

actual="$(marchjson version)"
expected="marchjson $version"

[ "$actual" = "$expected" ] ||
    fail "Bash version output mismatch: expected '$expected', got '$actual'"

actual_short="$(marchjson -v)"
[ "$actual_short" = "$expected" ] ||
    fail "Bash -v output mismatch: expected '$expected', got '$actual_short'"

printf 'VERSIONING_ACCEPTANCE=PASS VERSION=%s\n' "$version"
