#!/bin/bash
# NONSTOP v2.1 - SubagentStop Hook
# Fires when a subagent completes - caches results and updates progress

HOOK_INPUT=$(cat 2>/dev/null || echo '{}')
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

# Extract agent info from hook input
AGENT_ID=$(echo "$HOOK_INPUT" | jq -r '.agent_id // "unknown"' 2>/dev/null)

echo "=== NONSTOP SubagentStop ===" >&2
echo "Agent completed: $AGENT_ID" >&2

# Update progress dashboard
if [ -x "$LIB_DIR/progress-dashboard.sh" ]; then
    bash "$LIB_DIR/progress-dashboard.sh" compact >&2 2>/dev/null || true
fi

# Create auto-checkpoint after agent completion
if [ -x "$LIB_DIR/checkpoint-manager.sh" ]; then
    bash "$LIB_DIR/checkpoint-manager.sh" create "auto-agent-$AGENT_ID" >&2 2>/dev/null || true
fi

echo "=== SubagentStop Complete ===" >&2
