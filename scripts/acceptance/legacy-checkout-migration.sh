#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

command -v git >/dev/null 2>&1 || {
  echo "LEGACY_CHECKOUT_MIGRATION=SKIP git missing"
  exit 0
}

command -v jq >/dev/null 2>&1 || {
  echo "LEGACY_CHECKOUT_MIGRATION=FAIL jq missing" >&2
  exit 1
}

export HOME="$TMP/home"
INSTALL_DIR="$HOME/.local/share/marchjson"
mkdir -p "$INSTALL_DIR"

git -C "$INSTALL_DIR" init -q
git -C "$INSTALL_DIR" remote add origin https://github.com/MarchTechnology/MarchJson.git
printf 'legacy sentinel\n' > "$INSTALL_DIR/legacy-sentinel.txt"

mkdir -p "$HOME/.local/bin"
printf '#!/usr/bin/env bash\nprintf "march-env sentinel\\n"\n' > "$HOME/.local/bin/march-env"
chmod 700 "$HOME/.local/bin/march-env"

cat > "$HOME/.bashrc" <<'EOF'
# pre-existing config
export LEGACY_SENTINEL=preserve-me
EOF

if [[ -n "${MARCHJSON_ACCEPTANCE_REF:-}" ]]; then
  ref="$MARCHJSON_ACCEPTANCE_REF"
elif git -C "$ROOT" rev-parse HEAD >/dev/null 2>&1; then
  ref="$(git -C "$ROOT" rev-parse HEAD)"
else
  ref="main"
fi

output="$(
  MARCHJSON_REF="$ref"   MARCHJSON_INSTALL_DIR="$INSTALL_DIR"   MARCHJSON_BASHRC="$HOME/.bashrc"   MARCH_ENV_PATH="$HOME/.local/bin/march-env"   bash "$ROOT/install.sh"
)"

printf '%s\n' "$output" | grep -Fq 'Legacy Git checkout detected.'
backup="$(printf '%s\n' "$output" | sed -n 's/^Preserved checkout: //p' | tail -1)"

[[ -n "$backup" ]]
[[ -d "$backup/.git" ]]
[[ -f "$backup/legacy-sentinel.txt" ]]
grep -Fxq 'legacy sentinel' "$backup/legacy-sentinel.txt"

[[ ! -d "$INSTALL_DIR/.git" ]]
[[ -f "$INSTALL_DIR/bash/marchjson.sh" ]]
[[ -f "$INSTALL_DIR/VERSION" ]]
[[ -f "$INSTALL_DIR/REVISION" ]]

grep -Fxq 'export LEGACY_SENTINEL=preserve-me' "$HOME/.bashrc"
[[ "$(grep -Fxc '# >>> MarchJson >>>' "$HOME/.bashrc")" -eq 1 ]]
[[ "$(grep -Fxc '# <<< MarchJson <<<' "$HOME/.bashrc")" -eq 1 ]]

# shellcheck disable=SC1090
source "$HOME/.bashrc"
type marchjson >/dev/null 2>&1

echo "LEGACY_CHECKOUT_MIGRATION=PASS"
