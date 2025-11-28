#!/bin/bash
# NONSTOP v2.0 - Checkpoint Manager
# Save and restore execution state snapshots

set -euo pipefail

CACHE_DIR="${NONSTOP_CACHE_DIR:-$HOME/.claude/nonstop-cache}"
STATE_FILE="$CACHE_DIR/execution-state.json"
CHECKPOINT_DIR="$CACHE_DIR/checkpoints"

# Ensure directories exist
mkdir -p "$CHECKPOINT_DIR"

# ════════════════════════════════════════════════════════════════════
# CREATE CHECKPOINT
# ════════════════════════════════════════════════════════════════════

create_checkpoint() {
    local name="${1:-auto}"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local checkpoint_id="${timestamp}-${name}"
    local checkpoint_file="$CHECKPOINT_DIR/${checkpoint_id}.json"

    if [ ! -f "$STATE_FILE" ]; then
        echo "ERROR: No state file to checkpoint"
        return 1
    fi

    # Copy current state
    cp "$STATE_FILE" "$checkpoint_file"

    # Add checkpoint metadata to the copy
    local tmp_file=$(mktemp)
    jq --arg id "$checkpoint_id" \
       --arg name "$name" \
       --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       '. + {checkpoint_meta: {id: $id, name: $name, created_at: $ts}}' \
       "$checkpoint_file" > "$tmp_file"
    mv "$tmp_file" "$checkpoint_file"

    # Update state with checkpoint reference
    tmp_file=$(mktemp)
    jq --arg id "$checkpoint_id" \
       --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       '.checkpoints.last_checkpoint = $id |
        .checkpoints.checkpoint_list += [{id: $id, created_at: $ts}]' \
       "$STATE_FILE" > "$tmp_file" 2>/dev/null && mv "$tmp_file" "$STATE_FILE" || rm -f "$tmp_file"

    echo "Checkpoint created: $checkpoint_id"
    echo "File: $checkpoint_file"
}

# ════════════════════════════════════════════════════════════════════
# LIST CHECKPOINTS
# ════════════════════════════════════════════════════════════════════

list_checkpoints() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "                      CHECKPOINTS"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    local count=0
    for checkpoint in "$CHECKPOINT_DIR"/*.json; do
        [ -f "$checkpoint" ] || continue
        count=$((count + 1))

        local filename=$(basename "$checkpoint" .json)
        local created=$(jq -r '.checkpoint_meta.created_at // .created_at // "unknown"' "$checkpoint" 2>/dev/null)
        local task=$(jq -r '.task.original_request // "unknown"' "$checkpoint" 2>/dev/null | head -c 50)
        local stories_done=$(jq -r '[.plan.stories[] | select(.status == "completed")] | length' "$checkpoint" 2>/dev/null || echo "?")
        local stories_total=$(jq -r '.plan.stories | length' "$checkpoint" 2>/dev/null || echo "?")

        echo "[$count] $filename"
        echo "    Created: $created"
        echo "    Task: ${task}..."
        echo "    Progress: $stories_done/$stories_total stories"
        echo ""
    done

    if [ "$count" -eq 0 ]; then
        echo "No checkpoints found."
        echo ""
        echo "Create one with: checkpoint-manager.sh create [name]"
    fi

    echo "═══════════════════════════════════════════════════════════════"
}

# ════════════════════════════════════════════════════════════════════
# RESTORE CHECKPOINT
# ════════════════════════════════════════════════════════════════════

restore_checkpoint() {
    local identifier="$1"
    local checkpoint_file=""

    # Find checkpoint by name or partial match
    for f in "$CHECKPOINT_DIR"/*.json; do
        [ -f "$f" ] || continue
        if [[ "$(basename "$f")" == *"$identifier"* ]]; then
            checkpoint_file="$f"
            break
        fi
    done

    if [ -z "$checkpoint_file" ] || [ ! -f "$checkpoint_file" ]; then
        echo "ERROR: Checkpoint not found: $identifier"
        echo "Use 'list' to see available checkpoints"
        return 1
    fi

    # Backup current state before restore
    if [ -f "$STATE_FILE" ]; then
        local backup_name="pre-restore-$(date +%Y%m%d-%H%M%S)"
        cp "$STATE_FILE" "$CHECKPOINT_DIR/${backup_name}.json"
        echo "Current state backed up as: $backup_name"
    fi

    # Restore checkpoint
    cp "$checkpoint_file" "$STATE_FILE"

    # Remove checkpoint metadata from restored state
    local tmp_file=$(mktemp)
    jq 'del(.checkpoint_meta)' "$STATE_FILE" > "$tmp_file"
    mv "$tmp_file" "$STATE_FILE"

    # Update timestamp
    tmp_file=$(mktemp)
    jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.updated_at = $ts' "$STATE_FILE" > "$tmp_file"
    mv "$tmp_file" "$STATE_FILE"

    echo "Restored checkpoint: $(basename "$checkpoint_file" .json)"
}

# ════════════════════════════════════════════════════════════════════
# DELETE CHECKPOINT
# ════════════════════════════════════════════════════════════════════

delete_checkpoint() {
    local identifier="$1"
    local checkpoint_file=""

    for f in "$CHECKPOINT_DIR"/*.json; do
        [ -f "$f" ] || continue
        if [[ "$(basename "$f")" == *"$identifier"* ]]; then
            checkpoint_file="$f"
            break
        fi
    done

    if [ -z "$checkpoint_file" ] || [ ! -f "$checkpoint_file" ]; then
        echo "ERROR: Checkpoint not found: $identifier"
        return 1
    fi

    rm "$checkpoint_file"
    echo "Deleted: $(basename "$checkpoint_file" .json)"
}

# ════════════════════════════════════════════════════════════════════
# CLEANUP OLD CHECKPOINTS
# ════════════════════════════════════════════════════════════════════

cleanup_checkpoints() {
    local keep_count="${1:-10}"

    local files=($(ls -t "$CHECKPOINT_DIR"/*.json 2>/dev/null || true))
    local total=${#files[@]}

    if [ "$total" -le "$keep_count" ]; then
        echo "Only $total checkpoints exist, keeping all (limit: $keep_count)"
        return 0
    fi

    local to_delete=$((total - keep_count))
    local deleted=0

    # Delete oldest files (at end of sorted list)
    for ((i=keep_count; i<total; i++)); do
        rm "${files[$i]}"
        deleted=$((deleted + 1))
    done

    echo "Cleaned up $deleted old checkpoints, kept $keep_count"
}

# ════════════════════════════════════════════════════════════════════
# GET LATEST CHECKPOINT
# ════════════════════════════════════════════════════════════════════

get_latest() {
    local latest=$(ls -t "$CHECKPOINT_DIR"/*.json 2>/dev/null | head -1)

    if [ -z "$latest" ]; then
        echo "No checkpoints"
        return 1
    fi

    echo "$(basename "$latest" .json)"
}

# ════════════════════════════════════════════════════════════════════
# DIFF CHECKPOINT
# ════════════════════════════════════════════════════════════════════

diff_checkpoint() {
    local identifier="$1"
    local checkpoint_file=""

    for f in "$CHECKPOINT_DIR"/*.json; do
        [ -f "$f" ] || continue
        if [[ "$(basename "$f")" == *"$identifier"* ]]; then
            checkpoint_file="$f"
            break
        fi
    done

    if [ -z "$checkpoint_file" ] || [ ! -f "$checkpoint_file" ]; then
        echo "ERROR: Checkpoint not found"
        return 1
    fi

    if [ ! -f "$STATE_FILE" ]; then
        echo "ERROR: No current state"
        return 1
    fi

    echo "Comparing: $(basename "$checkpoint_file" .json) vs current"
    echo ""

    # Compare story statuses
    echo "Story Status Changes:"
    local checkpoint_stories=$(jq -r '.plan.stories[] | "\(.id): \(.status)"' "$checkpoint_file" 2>/dev/null | sort)
    local current_stories=$(jq -r '.plan.stories[] | "\(.id): \(.status)"' "$STATE_FILE" 2>/dev/null | sort)

    diff <(echo "$checkpoint_stories") <(echo "$current_stories") || true
}

# ════════════════════════════════════════════════════════════════════
# COMMAND DISPATCHER
# ════════════════════════════════════════════════════════════════════

case "${1:-help}" in
    create)
        create_checkpoint "${2:-auto}"
        ;;
    list|ls)
        list_checkpoints
        ;;
    restore)
        if [ -z "${2:-}" ]; then
            echo "Usage: checkpoint-manager.sh restore <name|id>"
            exit 1
        fi
        restore_checkpoint "$2"
        ;;
    delete|rm)
        if [ -z "${2:-}" ]; then
            echo "Usage: checkpoint-manager.sh delete <name|id>"
            exit 1
        fi
        delete_checkpoint "$2"
        ;;
    cleanup)
        cleanup_checkpoints "${2:-10}"
        ;;
    latest)
        get_latest
        ;;
    diff)
        if [ -z "${2:-}" ]; then
            echo "Usage: checkpoint-manager.sh diff <name|id>"
            exit 1
        fi
        diff_checkpoint "$2"
        ;;
    help|*)
        echo "NONSTOP Checkpoint Manager v2.0"
        echo ""
        echo "Usage: checkpoint-manager.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  create [name]     Create checkpoint (default name: auto)"
        echo "  list              List all checkpoints"
        echo "  restore <id>      Restore state from checkpoint"
        echo "  delete <id>       Delete checkpoint"
        echo "  cleanup [N]       Keep only last N checkpoints (default: 10)"
        echo "  latest            Show latest checkpoint name"
        echo "  diff <id>         Compare checkpoint to current state"
        echo "  help              This help message"
        echo ""
        echo "Examples:"
        echo "  checkpoint-manager.sh create before-refactor"
        echo "  checkpoint-manager.sh restore before-refactor"
        echo "  checkpoint-manager.sh cleanup 5"
        ;;
esac
