#!/usr/bin/env bash
set -euo pipefail

REPO="${MARCHJSON_REPO:-MarchTechnology/MarchJson}"
REF="${MARCHJSON_REF:-main}"
INSTALL_DIR="${MARCHJSON_INSTALL_DIR:-$HOME/.local/share/marchjson}"
BASHRC="${MARCHJSON_BASHRC:-$HOME/.bashrc}"
MARCH_ENV_PATH="${MARCH_ENV_PATH:-$HOME/.local/bin/march-env}"

API_BASE="https://api.github.com/repos/${REPO}"
BEGIN_MARKER="# >>> MarchJson >>>"
END_MARKER="# <<< MarchJson <<<"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/marchjson-install.XXXXXX")"
TMP_META="$TMP_ROOT/meta.json"
TMP_RUNTIME="$TMP_ROOT/bash/marchjson.sh"
TMP_VERSION="$TMP_ROOT/VERSION"
TMP_BASHRC_CONTENT="$TMP_ROOT/bashrc.content"
TMP_BASHRC_DEST="$TMP_ROOT/bashrc.dest"

LEGACY_CHECKOUT_BACKUP=''
LEGACY_MIGRATED=0

cleanup() {
  rm -rf "$TMP_ROOT"
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

rollback_legacy_checkout() {
  if [[ "$LEGACY_MIGRATED" == '1' ]] && [[ -n "$LEGACY_CHECKOUT_BACKUP" ]]; then
    rm -rf -- "$INSTALL_DIR"

    if [[ -d "$LEGACY_CHECKOUT_BACKUP" ]]; then
      mv -- "$LEGACY_CHECKOUT_BACKUP" "$INSTALL_DIR"
      printf 'Rollback: restored legacy Git checkout to %s\n' "$INSTALL_DIR" >&2
    fi
  fi
}

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  rollback_legacy_checkout
  exit 1
}

is_marchjson_checkout() {
  local origin=''

  command -v git >/dev/null 2>&1 || return 1

  origin="$(git -C "$INSTALL_DIR" remote get-url origin 2>/dev/null || true)"

  case "$origin" in
    https://github.com/MarchTechnology/MarchJson|    https://github.com/MarchTechnology/MarchJson.git|    git@github.com:MarchTechnology/MarchJson.git|    ssh://git@github.com/MarchTechnology/MarchJson.git)
      return 0
      ;;
  esac

  return 1
}

migrate_legacy_checkout() {
  [[ -d "$INSTALL_DIR/.git" ]] || return 0

  if ! is_marchjson_checkout; then
    fail "MARCHJSON_INSTALL_DIR is a Git checkout that is not recognized as MarchTechnology/MarchJson: $INSTALL_DIR"
  fi

  LEGACY_CHECKOUT_BACKUP="$INSTALL_DIR.git-backup-$(date +%Y%m%d-%H%M%S)"

  if [[ -e "$LEGACY_CHECKOUT_BACKUP" ]]; then
    LEGACY_CHECKOUT_BACKUP="$LEGACY_CHECKOUT_BACKUP.$"
  fi

  mv -- "$INSTALL_DIR" "$LEGACY_CHECKOUT_BACKUP"
  LEGACY_MIGRATED=1

  printf 'Legacy Git checkout detected.\n'
  printf 'Preserved checkout: %s\n' "$LEGACY_CHECKOUT_BACKUP"
}

fingerprint_file() {
  local path="$1"

  if [[ ! -e "$path" ]]; then
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

download_to() {
  local url="$1"
  local dest="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url"
  else
    fail 'curl or wget is required to download MarchJson.'
  fi
}

if ((BASH_VERSINFO[0] < 4)); then
  fail 'MarchJson requires Bash 4 or newer.'
fi

if ! command -v jq >/dev/null 2>&1; then
  fail 'jq is required but was not found in PATH. Install jq first, then rerun the installer.'
fi

mkdir -p "$(dirname "$TMP_RUNTIME")"

if [[ "$REF" =~ ^[0-9a-fA-F]{40}$ ]]; then
  RESOLVED_SHA="${REF,,}"
else
  COMMIT_API_URL="$API_BASE/commits/$REF"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL \
      -H 'Accept: application/vnd.github+json' \
      -H 'User-Agent: marchjson-installer' \
      "$COMMIT_API_URL" \
      -o "$TMP_META"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$TMP_META" \
      --header='Accept: application/vnd.github+json' \
      --header='User-Agent: marchjson-installer' \
      "$COMMIT_API_URL"
  else
    fail 'curl or wget is required to download MarchJson.'
  fi

  RESOLVED_SHA="$(
    jq -er '
      .sha
      | select(type == "string")
      | ascii_downcase
      | select(test("^[0-9a-f]{40}$"))
    ' "$TMP_META"
  )" || fail 'unable to resolve requested ref to a commit SHA.'
fi

RAW_BASE="https://raw.githubusercontent.com/${REPO}/${RESOLVED_SHA}"

printf 'Installing MarchJson from %s@%s\n' "$REPO" "$REF"
printf 'Resolved commit: %s\n' "$RESOLVED_SHA"

download_to "$RAW_BASE/bash/marchjson.sh" "$TMP_RUNTIME"
download_to "$RAW_BASE/VERSION" "$TMP_VERSION"

[[ -s "$TMP_RUNTIME" ]] ||
  fail 'downloaded MarchJson Bash runtime is empty.'

[[ -s "$TMP_VERSION" ]] ||
  fail 'downloaded VERSION file is empty.'

bash -n "$TMP_RUNTIME" ||
  fail 'downloaded MarchJson Bash runtime failed syntax validation.'

VERSION="$(tr -d '[:space:]' < "$TMP_VERSION")"

if [[ ! "$VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]; then
  fail "downloaded VERSION is not valid SemVer: $VERSION"
fi

DOWNLOADED_VERSION="$(
  HOME="$HOME" \
  MARCHJSON_NPM_WHITELIST="$TMP_ROOT/npm-whitelist.txt" \
  bash -c 'source "$1"; marchjson --version' _ "$TMP_RUNTIME"
)"

[[ "$DOWNLOADED_VERSION" == "marchjson $VERSION" ]] ||
  fail 'downloaded runtime version does not match VERSION.'

march_env_before="$(fingerprint_file "$MARCH_ENV_PATH")"

migrate_legacy_checkout

mkdir -p "$INSTALL_DIR/bash"

RUNTIME_DEST="$INSTALL_DIR/bash/marchjson.sh"
VERSION_DEST="$INSTALL_DIR/VERSION"
REVISION_DEST="$INSTALL_DIR/REVISION"

runtime_tmp="$RUNTIME_DEST.tmp.$$"
version_tmp="$VERSION_DEST.tmp.$$"
revision_tmp="$REVISION_DEST.tmp.$$"

rm -f "$runtime_tmp" "$version_tmp" "$revision_tmp"

if command -v install >/dev/null 2>&1; then
  install -m 700 "$TMP_RUNTIME" "$runtime_tmp"
  install -m 600 "$TMP_VERSION" "$version_tmp"
else
  cp "$TMP_RUNTIME" "$runtime_tmp"
  cp "$TMP_VERSION" "$version_tmp"
  chmod 700 "$runtime_tmp"
  chmod 600 "$version_tmp"
fi

printf '%s\n' "$RESOLVED_SHA" > "$revision_tmp"
chmod 600 "$revision_tmp"

mv -f "$runtime_tmp" "$RUNTIME_DEST"
mv -f "$version_tmp" "$VERSION_DEST"
mv -f "$revision_tmp" "$REVISION_DEST"

mkdir -p "$(dirname "$BASHRC")"
touch "$BASHRC"

begin_count="$(grep -Fxc "$BEGIN_MARKER" "$BASHRC" 2>/dev/null || true)"
end_count="$(grep -Fxc "$END_MARKER" "$BASHRC" 2>/dev/null || true)"

if [[ "$begin_count" != "$end_count" ]] || ((begin_count > 1)); then
  fail 'existing MarchJson marker block in .bashrc is malformed or duplicated; refusing to edit it.'
fi

BASHRC_BACKUP="$BASHRC.marchjson-backup-$(date +%Y%m%d-%H%M%S)"
cp -p "$BASHRC" "$BASHRC_BACKUP"

awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
  $0 == begin { skip = 1; next }
  $0 == end   { skip = 0; next }
  !skip       { print }
' "$BASHRC" > "$TMP_BASHRC_CONTENT"

source_expr="$(printf '%q' "$RUNTIME_DEST")"

printf '\n%s\nsource %s\n%s\n' \
  "$BEGIN_MARKER" \
  "$source_expr" \
  "$END_MARKER" \
  >> "$TMP_BASHRC_CONTENT"

bash -n "$TMP_BASHRC_CONTENT" ||
  fail 'generated .bashrc failed Bash syntax validation; original .bashrc was not changed.'

cp -p "$BASHRC" "$TMP_BASHRC_DEST"
cat "$TMP_BASHRC_CONTENT" > "$TMP_BASHRC_DEST"
mv -f "$TMP_BASHRC_DEST" "$BASHRC"

INSTALLED_VERSION="$(
  HOME="$HOME" \
  MARCHJSON_NPM_WHITELIST="$TMP_ROOT/installed-whitelist.txt" \
  bash -c 'source "$1"; marchjson --version' _ "$RUNTIME_DEST"
)"

[[ "$INSTALLED_VERSION" == "$DOWNLOADED_VERSION" ]] || {
  cp -p "$BASHRC_BACKUP" "$BASHRC"
  fail 'installed MarchJson version does not match downloaded runtime; .bashrc was restored.'
}

march_env_after="$(fingerprint_file "$MARCH_ENV_PATH")"

if [[ "$march_env_before" != "$march_env_after" ]]; then
  cp -p "$BASHRC_BACKUP" "$BASHRC"
  fail "march-env changed during installation. .bashrc was restored. MarchJson does not write to $MARCH_ENV_PATH."
fi

printf 'Installed runtime: %s\n' "$RUNTIME_DEST"
printf 'Version: %s\n' "$INSTALLED_VERSION"
printf 'Revision: %s\n' "$RESOLVED_SHA"
printf 'Bash integration: %s\n' "$BASHRC"
printf 'Backup: %s\n' "$BASHRC_BACKUP"

if [[ "$march_env_before" == 'ABSENT' ]]; then
  printf 'march-env: not present before install; no march-env file was created or modified.\n'
else
  printf 'march-env: preserved unchanged at %s\n' "$MARCH_ENV_PATH"
fi

if [[ "$LEGACY_MIGRATED" == '1' ]]; then
  printf 'Legacy checkout backup: %s\n' "$LEGACY_CHECKOUT_BACKUP"
  LEGACY_MIGRATED=0
fi

printf 'Validation: PASS\n'
printf '\nRun:\n'
printf '  source %q\n' "$BASHRC"
printf '  marchjson --version\n'
printf '  marchjson status\n'
