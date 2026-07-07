#!/usr/bin/env bash
# load-env.sh — Source .env into the current shell session (bash/zsh/WSL).
# Usage:  source scripts/load-env.sh
#         source scripts/load-env.sh .env.staging

set -euo pipefail

ENV_FILE="${1:-.env}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_PATH="$SCRIPT_DIR/../$ENV_FILE"

if [[ ! -f "$ENV_PATH" ]]; then
    echo "ERROR: $ENV_PATH not found." >&2
    echo "Copy .env.example to .env and fill in your credentials." >&2
    return 1 2>/dev/null || exit 1
fi

loaded=0
while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip blank lines and comments
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*) ]]; then
        name="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        # Strip surrounding quotes
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        export "$name=$value"
        (( loaded++ )) || true
    fi
done < "$ENV_PATH"

echo "Loaded $loaded variable(s) from $ENV_FILE into this session."

# Warn if credentials are still example placeholders
if [[ "${AWS_ACCESS_KEY_ID:-}" == *EXAMPLE* ]]; then
    echo "WARNING: AWS_ACCESS_KEY_ID still contains 'EXAMPLE' — did you forget to edit .env?" >&2
fi
