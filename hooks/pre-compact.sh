#!/bin/bash
# NONSTOP v2.1 - Pre-Compact Hook
# Simplified: State is already maintained by skill, just backup

CACHE_DIR="${NONSTOP_CACHE_DIR:-$HOME/.claude/nonstop-cache}"
STATE_FILE="$CACHE_DIR/execution-state.json"
BACKUP_DIR="$CACHE_DIR/backups"

mkdir -p "$BACKUP_DIR"

echo "=== NONSTOP v2.1 Pre-Compact ===" >&2

if [ -f "$STATE_FILE" ]; then
    # Create timestamped backup
    BACKUP_NAME="state-$(date +%Y%m%d-%H%M%S).json"
    cp "$STATE_FILE" "$BACKUP_DIR/$BACKUP_NAME"
    echo "State backed up: $BACKUP_NAME" >&2

    # Update recovery info in state
    if command -v jq &>/dev/null; then
        COMPACT_COUNT=$(jq -r '.recovery.compact_count // 0' "$STATE_FILE" 2>/dev/null || echo "0")
        NEW_COUNT=$((COMPACT_COUNT + 1))
        TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

        jq --arg ts "$TIMESTAMP" --argjson cnt "$NEW_COUNT" \
           '.recovery.compact_count = $cnt | .recovery.last_compact_time = $ts | .updated_at = $ts' \
           "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null && mv "$STATE_FILE.tmp" "$STATE_FILE"

        echo "Compact count: $NEW_COUNT" >&2
    fi

    # Keep only last 10 backups
    ls -t "$BACKUP_DIR"/state-*.json 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
else
    echo "No state file to backup" >&2
fi

echo "=== Pre-Compact Complete ===" >&2
