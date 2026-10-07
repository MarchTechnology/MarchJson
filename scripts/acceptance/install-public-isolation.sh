#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

command -v jq >/dev/null 2>&1 || {
  echo "INSTALL_PUBLIC_ISOLATION=FAIL jq missing" >&2
  exit 1
}

export HOME="$TMP/home"
mkdir -p "$HOME/.local/bin"

printf '#!/usr/bin/env bash\nprintf "march-env sentinel\\n"\n' > "$HOME/.local/bin/march-env"
chmod 700 "$HOME/.local/bin/march-env"

cat > "$HOME/.bashrc" <<'EOF'
# existing user configuration
export MARCH_ENV_SENTINEL=preserve-me
EOF

fingerprint() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1 ":" $2}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1 ":" $2}'
  else
    cksum "$1" | awk '{print $1 ":" $2}'
  fi
}

before="$(fingerprint "$HOME/.local/bin/march-env")"
before_mode="$(stat -c '%a' "$HOME/.local/bin/march-env" 2>/dev/null || stat -f '%Lp' "$HOME/.local/bin/march-env")"

if [[ -n "${MARCHJSON_ACCEPTANCE_REF:-}" ]]; then
  ref="$MARCHJSON_ACCEPTANCE_REF"
elif command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse HEAD >/dev/null 2>&1; then
  ref="$(git -C "$ROOT" rev-parse HEAD)"
else
  ref="main"
fi

run_install() {
  MARCHJSON_REF="$ref" \
  MARCHJSON_INSTALL_DIR="$HOME/.local/share/marchjson" \
  MARCHJSON_BASHRC="$HOME/.bashrc" \
  MARCH_ENV_PATH="$HOME/.local/bin/march-env" \
  bash "$ROOT/install.sh" >/dev/null
}

run_install

after="$(fingerprint "$HOME/.local/bin/march-env")"
after_mode="$(stat -c '%a' "$HOME/.local/bin/march-env" 2>/dev/null || stat -f '%Lp' "$HOME/.local/bin/march-env")"

[[ "$before" == "$after" ]] || {
  echo "INSTALL_PUBLIC_ISOLATION=FAIL march-env content changed" >&2
  exit 1
}

[[ "$before_mode" == "$after_mode" ]] || {
  echo "INSTALL_PUBLIC_ISOLATION=FAIL march-env mode changed" >&2
  exit 1
}

grep -Fxq "export MARCH_ENV_SENTINEL=preserve-me" "$HOME/.bashrc"
[[ "$(grep -Fxc "# >>> MarchJson >>>" "$HOME/.bashrc")" -eq 1 ]]
[[ "$(grep -Fxc "# <<< MarchJson <<<" "$HOME/.bashrc")" -eq 1 ]]
bash -n "$HOME/.bashrc"

run_install

after_second="$(fingerprint "$HOME/.local/bin/march-env")"
after_second_mode="$(stat -c '%a' "$HOME/.local/bin/march-env" 2>/dev/null || stat -f '%Lp' "$HOME/.local/bin/march-env")"

[[ "$before" == "$after_second" ]] || {
  echo "INSTALL_PUBLIC_ISOLATION=FAIL march-env changed after reinstall" >&2
  exit 1
}

[[ "$before_mode" == "$after_second_mode" ]] || {
  echo "INSTALL_PUBLIC_ISOLATION=FAIL march-env mode changed after reinstall" >&2
  exit 1
}

[[ "$(grep -Fxc "# >>> MarchJson >>>" "$HOME/.bashrc")" -eq 1 ]]
[[ "$(grep -Fxc "# <<< MarchJson <<<" "$HOME/.bashrc")" -eq 1 ]]

# shellcheck disable=SC1090
source "$HOME/.bashrc"

type marchjson >/dev/null 2>&1
[[ "$MARCH_ENV_SENTINEL" == "preserve-me" ]]
[[ "$(marchjson --version)" =~ ^marchjson[[:space:]][0-9]+\.[0-9]+\.[0-9]+ ]]

echo "INSTALL_PUBLIC_ISOLATION=PASS"
