# MarchJson 0.1.0
# JSON-aware selective wrappers for Bash/SSH.
# Source this file from ~/.bashrc.

MARCHJSON_VERSION="0.1.0"

if [ -z "${MARCHJSON_NPM_WHITELIST:-}" ]; then
    MARCHJSON_NPM_WHITELIST="$HOME/.config/march/json-npm-whitelist.txt"
fi

__marchjson_ensure_whitelist() {
    mkdir -p "$(dirname "$MARCHJSON_NPM_WHITELIST")"
    touch "$MARCHJSON_NPM_WHITELIST"
}

__marchjson_has_jq() {
    command -v jq >/dev/null 2>&1
}

__marchjson_is_json() {
    local input="$1"

    [ -n "$input" ] || return 1
    __marchjson_has_jq || return 1

    printf '%s' "$input" | command jq -e . >/dev/null 2>&1
}

__marchjson_format_json() {
    local input="$1"

    if __marchjson_has_jq; then
        printf '%s\n' "$input" | command jq -C .
        return
    fi

    printf '%s\n' "$input"
}

__marchjson_exec() {
    local merge_stderr=0
    local output
    local exit_code
    local line

    if [ "${1:-}" = "--merge-stderr" ]; then
        merge_stderr=1
        shift
    fi

    if [ "$merge_stderr" -eq 1 ]; then
        output="$("$@" 2>&1)"
    else
        output="$("$@")"
    fi

    exit_code=$?

    if [ -z "$output" ]; then
        return "$exit_code"
    fi

    if __marchjson_is_json "$output"; then
        __marchjson_format_json "$output"
        return "$exit_code"
    fi

    while IFS= read -r line || [ -n "$line" ]; do
        if __marchjson_is_json "$line"; then
            __marchjson_format_json "$line"
        else
            printf '%s\n' "$line"
        fi
    done <<< "$output"

    return "$exit_code"
}

__marchjson_list() {
    [ -f "$MARCHJSON_NPM_WHITELIST" ] || return 0

    command grep -vE '^[[:space:]]*(#|$)' "$MARCHJSON_NPM_WHITELIST" |
        command sort -u
}

__marchjson_npm_enabled() {
    local script_name="$1"

    __marchjson_list | command grep -Fxq -- "$script_name"
}

curl() {
    local arg
    local file_mode=0

    for arg in "$@"; do
        case "$arg" in
            -o|-O|-T|--output|--output=*|--remote-name|--upload-file|--upload-file=*)
                file_mode=1
                break
                ;;
        esac
    done

    if [ "$file_mode" -eq 1 ]; then
        command curl "$@"
        return
    fi

    __marchjson_exec command curl "$@"
}

node() {
    case "${1:-}" in
        -e|--eval)
            __marchjson_exec --merge-stderr command node "$@"
            ;;
        *)
            command node "$@"
            ;;
    esac
}

npm() {
    if [ "${1:-}" = "run" ] &&
       [ -n "${2:-}" ] &&
       __marchjson_npm_enabled "$2"; then
        __marchjson_exec --merge-stderr command npm "$@"
        return $?
    fi

    command npm "$@"
}

marchjson() {
    local subcommand="${1:-help}"
    local value="${2:-}"

    __marchjson_help() {
        cat <<EOF
marchjson $MARCHJSON_VERSION - JSON-aware wrapper manager

Usage:
  marchjson -h
  marchjson h | help | ?
  marchjson s | status
  marchjson l | list
  marchjson a | add <npm-script>
  marchjson r | remove <npm-script>
  marchjson e | edit
  marchjson rl | reload
  marchjson v | version

Wrappers:
  curl       JSON-aware
  npm        JSON-aware for whitelisted npm scripts
  node -e    JSON-aware

Bypass:
  command curl ...
  command npm ...
  command node ...

Whitelist:
  $MARCHJSON_NPM_WHITELIST
EOF
    }

    case "$subcommand" in
        -h|h|help|\?)
            __marchjson_help
            ;;

        v|version)
            echo "marchjson $MARCHJSON_VERSION"
            ;;

        s|status)
            echo "MarchJson:"
            echo "  Version: $MARCHJSON_VERSION"
            echo
            echo "Whitelist file:"
            echo "  $MARCHJSON_NPM_WHITELIST"
            echo
            echo "Wrappers:"

            if declare -F curl >/dev/null 2>&1; then
                echo "  curl   Function"
            else
                echo "  curl   Native"
            fi

            if declare -F npm >/dev/null 2>&1; then
                echo "  npm    Function"
            else
                echo "  npm    Native"
            fi

            if declare -F node >/dev/null 2>&1; then
                echo "  node   Function"
            else
                echo "  node   Native"
            fi

            echo
            echo "Native executables:"
            printf '  %-8s %s\n' "curl" "$(type -P curl 2>/dev/null || echo 'NOT FOUND')"
            printf '  %-8s %s\n' "npm" "$(type -P npm 2>/dev/null || echo 'NOT FOUND')"
            printf '  %-8s %s\n' "node" "$(type -P node 2>/dev/null || echo 'NOT FOUND')"
            printf '  %-8s %s\n' "jq" "$(type -P jq 2>/dev/null || echo 'NOT FOUND')"

            if __marchjson_has_jq; then
                printf '  %-8s %s\n' "jq ver." "$(command jq --version 2>/dev/null)"
            fi

            echo
            echo "Whitelist:"
            if [ -n "$(__marchjson_list)" ]; then
                __marchjson_list | sed 's/^/  /'
            else
                echo "  (empty)"
            fi
            ;;

        l|list)
            __marchjson_list
            ;;

        a|add)
            if [ -z "$value" ]; then
                echo "Usage: marchjson add <npm-script>" >&2
                echo "Short form: marchjson a <npm-script>" >&2
                return 1
            fi

            __marchjson_ensure_whitelist

            if __marchjson_npm_enabled "$value"; then
                echo "Already whitelisted: $value"
                return 0
            fi

            printf '%s\n' "$value" >> "$MARCHJSON_NPM_WHITELIST"
            echo "Added JSON-aware npm script: $value"
            ;;

        r|remove)
            if [ -z "$value" ]; then
                echo "Usage: marchjson remove <npm-script>" >&2
                echo "Short form: marchjson r <npm-script>" >&2
                return 1
            fi

            __marchjson_ensure_whitelist

            if ! __marchjson_npm_enabled "$value"; then
                echo "Not whitelisted: $value"
                return 0
            fi

            local temp_file
            temp_file="$(mktemp)"

            command awk -v target="$value" '$0 != target' "$MARCHJSON_NPM_WHITELIST" > "$temp_file"
            cat "$temp_file" > "$MARCHJSON_NPM_WHITELIST"
            rm -f "$temp_file"

            echo "Removed JSON-aware npm script: $value"
            ;;

        e|edit)
            __marchjson_ensure_whitelist

            if [ -n "${EDITOR:-}" ]; then
                "$EDITOR" "$MARCHJSON_NPM_WHITELIST"
            elif command -v nano >/dev/null 2>&1; then
                nano "$MARCHJSON_NPM_WHITELIST"
            elif command -v vi >/dev/null 2>&1; then
                vi "$MARCHJSON_NPM_WHITELIST"
            else
                echo "No editor found. Set EDITOR or edit the whitelist manually." >&2
                return 1
            fi
            ;;

        rl|reload)
            echo "Whitelist is read dynamically; no reload is required."
            ;;

        *)
            echo "Unknown command: $subcommand" >&2
            echo "Run: marchjson -h"
            return 1
            ;;
    esac
}
