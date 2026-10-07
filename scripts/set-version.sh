#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
VERSION_FILE="$ROOT/VERSION"
VERSION="${1:-}"

usage() {
    cat <<'EOF'
Usage:
  bash scripts/set-version.sh <semver>

Examples:
  bash scripts/set-version.sh 0.2.1
  bash scripts/set-version.sh 0.3.0
  bash scripts/set-version.sh 1.0.0
EOF
}

if [ -z "$VERSION" ] || [ "$VERSION" = "-h" ] || [ "$VERSION" = "--help" ]; then
    usage
    [ -n "$VERSION" ] || exit 1
    exit 0
fi

printf '%s\n' "$VERSION" |
    grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$' || {
        printf 'Invalid SemVer: %s\n' "$VERSION" >&2
        exit 1
    }

printf '%s\n' "$VERSION" > "$VERSION_FILE"
printf 'MarchJson version set to %s\n' "$VERSION"
printf 'Next: update CHANGELOG.md, run scripts/acceptance/versioning.sh, then commit/tag the release.\n'
