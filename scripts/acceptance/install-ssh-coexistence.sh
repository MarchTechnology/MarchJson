#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
mkdir -p "$HOME/.local/bin"

printf '#!/usr/bin/env bash\nprintf "march-env sentinel\\n"\n' > "$HOME/.local/bin/march-env"
chmod +x "$HOME/.local/bin/march-env"

cat > "$HOME/.bashrc" <<'EOF'
# existing user configuration
export MARCH_ENV_SENTINEL=preserve-me
EOF

before="$(sha256sum "$HOME/.local/bin/march-env" | awk '{print $1}')"

MARCHJSON_BASHRC="$HOME/.bashrc" \
MARCH_ENV_PATH="$HOME/.local/bin/march-env" \
bash "$ROOT/scripts/install-ssh.sh" >/dev/null

after="$(sha256sum "$HOME/.local/bin/march-env" | awk '{print $1}')"
[ "$before" = "$after" ] || { echo "march-env fingerprint changed" >&2; exit 1; }

grep -Fxq "export MARCH_ENV_SENTINEL=preserve-me" "$HOME/.bashrc"
[ "$(grep -Fxc "# >>> MarchJson >>>" "$HOME/.bashrc")" -eq 1 ]
[ "$(grep -Fxc "# <<< MarchJson <<<" "$HOME/.bashrc")" -eq 1 ]
bash -n "$HOME/.bashrc"

# Re-run to prove idempotence and coexistence.
MARCHJSON_BASHRC="$HOME/.bashrc" \
MARCH_ENV_PATH="$HOME/.local/bin/march-env" \
bash "$ROOT/scripts/install-ssh.sh" >/dev/null

after_second="$(sha256sum "$HOME/.local/bin/march-env" | awk '{print $1}')"
[ "$before" = "$after_second" ] || { echo "march-env changed after second install" >&2; exit 1; }
[ "$(grep -Fxc "# >>> MarchJson >>>" "$HOME/.bashrc")" -eq 1 ]
[ "$(grep -Fxc "# <<< MarchJson <<<" "$HOME/.bashrc")" -eq 1 ]

# shellcheck disable=SC1090
source "$HOME/.bashrc"
type marchjson >/dev/null 2>&1
[ "$MARCH_ENV_SENTINEL" = "preserve-me" ]

echo "INSTALL_SSH_COEXISTENCE=PASS"
