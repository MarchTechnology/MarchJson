#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SOURCE_FILE="$REPO_ROOT/bash/marchjson.sh"
BASHRC="${MARCHJSON_BASHRC:-$HOME/.bashrc}"
MARCH_ENV_PATH="${MARCH_ENV_PATH:-$HOME/.local/bin/march-env}"

BEGIN_MARKER="# >>> MarchJson >>>"
END_MARKER="# <<< MarchJson <<<"

fail() {
    printf 'MarchJson install error: %s\n' "$*" >&2
    exit 1
}

fingerprint_file() {
    local path="$1"

    if [ ! -e "$path" ]; then
        printf 'ABSENT'
        return 0
    fi

    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$path" | awk '{print $1}'
        return 0
    fi

    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$path" | awk '{print $1}'
        return 0
    fi

    cksum "$path" | awk '{print $1 ":" $2}'
}

[ -f "$SOURCE_FILE" ] || fail "Missing Bash runtime: $SOURCE_FILE"

mkdir -p "$(dirname "$BASHRC")"
touch "$BASHRC"

march_env_before="$(fingerprint_file "$MARCH_ENV_PATH")"

backup="$BASHRC.marchjson-backup-$(date +%Y%m%d-%H%M%S)"
cp -p "$BASHRC" "$backup"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
    $0 == begin { skip = 1; next }
    $0 == end   { skip = 0; next }
    !skip       { print }
' "$BASHRC" > "$tmp"

source_expr="$(printf '%q' "$SOURCE_FILE")"

printf '\n%s\nsource %s\n%s\n' \
    "$BEGIN_MARKER" \
    "$source_expr" \
    "$END_MARKER" \
    >> "$tmp"

bash -n "$tmp" || fail "Generated .bashrc is invalid; original file was not changed."

cat "$tmp" > "$BASHRC"

march_env_after="$(fingerprint_file "$MARCH_ENV_PATH")"

if [ "$march_env_before" != "$march_env_after" ]; then
    cp -p "$backup" "$BASHRC"
    fail "march-env changed during installation. .bashrc was restored. MarchJson never intentionally writes to $MARCH_ENV_PATH."
fi

printf 'MarchJson SSH setup complete.\n'
printf '  Runtime:   %s\n' "$SOURCE_FILE"
printf '  Bash rc:   %s\n' "$BASHRC"
printf '  Backup:    %s\n' "$backup"

if [ "$march_env_before" = "ABSENT" ]; then
    printf '  march-env: not present before install; no march-env path was created or modified.\n'
else
    printf '  march-env: preserved unchanged at %s\n' "$MARCH_ENV_PATH"
fi

printf '\nNo file under ~/.local/bin is installed, replaced, or removed by this installer.\n'
printf 'Run: source %q\n' "$BASHRC"
