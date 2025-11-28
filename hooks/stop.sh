#!/bin/bash
# NONSTOP v2.1 - Stop Hook
# Fires after every Claude response - auto-updates state and progress

CACHE_DIR="${NONSTOP_CACHE_DIR:-$HOME/.claude/nonstop-cache}"
STATE_FILE="$CACHE_DIR/execution-state.json"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LIB_DIR="${NONSTOP_LIB_DIR:-$PROJECT_ROOT/.claude/lib}"

# Only run if nonstop session is active
if [ ! -f "$STATE_FILE" ]; then
    exit 0
fi

EXEC_STATUS=$(jq -r '.execution.status // "none"' "$STATE_FILE" 2>/dev/null)
if [ "$EXEC_STATUS" != "in_progress" ]; then
    exit 0
fi

# Update timestamp
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
TMP_FILE=$(mktemp)
jq --arg ts "$TIMESTAMP" '.updated_at = $ts' "$STATE_FILE" > "$TMP_FILE" 2>/dev/null && mv "$TMP_FILE" "$STATE_FILE"

# Show compact progress (to stderr so it doesn't interfere)
if [ -x "$LIB_DIR/progress-dashboard.sh" ]; then
    echo "" >&2
    bash "$LIB_DIR/progress-dashboard.sh" compact >&2 2>/dev/null || true
fi
