#!/bin/bash
# NONSTOP v2.0 - Progress Dashboard
# Real-time ASCII visualization of execution progress

set -euo pipefail

CACHE_DIR="${NONSTOP_CACHE_DIR:-$HOME/.claude/nonstop-cache}"
STATE_FILE="$CACHE_DIR/execution-state.json"

# Colors (if terminal supports)
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    GREEN='' YELLOW='' RED='' BLUE='' CYAN='' BOLD='' NC=''
fi

# ════════════════════════════════════════════════════════════════════
# PROGRESS BAR GENERATOR
# ════════════════════════════════════════════════════════════════════

render_progress_bar() {
    local width="${1:-30}"
    local percentage="${2:-0}"

    # Clamp percentage
    (( percentage < 0 )) && percentage=0
    (( percentage > 100 )) && percentage=100

    local filled=$(( width * percentage / 100 ))
    local empty=$(( width - filled ))

    local bar="["
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    bar+="] ${percentage}%"

    echo "$bar"
}

# ════════════════════════════════════════════════════════════════════
# STORY STATUS TABLE
# ════════════════════════════════════════════════════════════════════

render_story_table() {
    if [ ! -f "$STATE_FILE" ]; then
        echo "No state file found"
        return 1
    fi

    local stories_json=$(jq -r '.plan.stories // []' "$STATE_FILE" 2>/dev/null)
    local story_count=$(echo "$stories_json" | jq 'length')

    if [ "$story_count" = "0" ] || [ -z "$story_count" ]; then
        echo "No stories in plan"
        return 0
    fi

    # Header
    echo "┌────────┬────────────────────────────────┬────────────┐"
    echo "│ Story  │ Title                          │ Status     │"
    echo "├────────┼────────────────────────────────┼────────────┤"

    # Stories
    echo "$stories_json" | jq -r '.[] | "\(.id)|\(.title // "Untitled")|\(.status // "pending")"' | while IFS='|' read -r id title status; do
        # Truncate title to 30 chars
        title="${title:0:30}"

        # Status icon
        case "$status" in
            completed) status_str="${GREEN}✓ complete${NC}" ;;
            in_progress) status_str="${YELLOW}⟳ running${NC}" ;;
            failed) status_str="${RED}✗ failed${NC}" ;;
            blocked) status_str="${RED}⊘ blocked${NC}" ;;
            *) status_str="○ pending" ;;
        esac

        printf "│ %-6s │ %-30s │ %-10s │\n" "$id" "$title" "$status_str"
    done

    echo "└────────┴────────────────────────────────┴────────────┘"
}

# ════════════════════════════════════════════════════════════════════
# CURRENT TASK INDICATOR
# ════════════════════════════════════════════════════════════════════

render_current_task() {
    if [ ! -f "$STATE_FILE" ]; then
        echo "▶ No active task"
        return 0
    fi

    local current_story=$(jq -r '.execution.current_story_id // "none"' "$STATE_FILE" 2>/dev/null)
    local current_task=$(jq -r '.execution.current_task_id // "none"' "$STATE_FILE" 2>/dev/null)
    local current_subtask=$(jq -r '.execution.current_subtask_id // "none"' "$STATE_FILE" 2>/dev/null)

    if [ "$current_story" = "none" ] || [ "$current_story" = "null" ]; then
        echo "▶ No task in progress"
        return 0
    fi

    # Get story title
    local story_title=$(jq -r ".plan.stories[] | select(.id == \"$current_story\") | .title // \"Unknown\"" "$STATE_FILE" 2>/dev/null)

    echo -e "${CYAN}▶ Currently:${NC} ${BOLD}$current_story${NC}"
    echo "  Story: $story_title"
    [ "$current_task" != "none" ] && [ "$current_task" != "null" ] && echo "  Task: $current_task"
    [ "$current_subtask" != "none" ] && [ "$current_subtask" != "null" ] && echo "  Subtask: $current_subtask"
}

# ════════════════════════════════════════════════════════════════════
# ETA CALCULATOR
# ════════════════════════════════════════════════════════════════════

estimate_eta() {
    if [ ! -f "$STATE_FILE" ]; then
        echo "Unknown"
        return 0
    fi

    local total=$(jq -r '.plan.stories | length' "$STATE_FILE" 2>/dev/null || echo "0")
    local completed=$(jq -r '[.plan.stories[] | select(.status == "completed")] | length' "$STATE_FILE" 2>/dev/null || echo "0")
    local start_time=$(jq -r '.metrics.session_start // .created_at // empty' "$STATE_FILE" 2>/dev/null)

    if [ -z "$start_time" ] || [ "$total" = "0" ] || [ "$completed" = "0" ]; then
        echo "Calculating..."
        return 0
    fi

    # Calculate elapsed time
    local start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$start_time" "+%s" 2>/dev/null || date -d "$start_time" "+%s" 2>/dev/null || echo "0")
    local now_epoch=$(date "+%s")
    local elapsed=$((now_epoch - start_epoch))

    if [ "$elapsed" -le 0 ] || [ "$completed" -eq 0 ]; then
        echo "Calculating..."
        return 0
    fi

    # Estimate remaining
    local remaining=$((total - completed))
    local avg_per_story=$((elapsed / completed))
    local eta_seconds=$((avg_per_story * remaining))

    # Format ETA
    if [ "$eta_seconds" -lt 60 ]; then
        echo "${eta_seconds}s"
    elif [ "$eta_seconds" -lt 3600 ]; then
        echo "$((eta_seconds / 60))m $((eta_seconds % 60))s"
    else
        echo "$((eta_seconds / 3600))h $((eta_seconds % 3600 / 60))m"
    fi
}

# ════════════════════════════════════════════════════════════════════
# PROGRESS SUMMARY
# ════════════════════════════════════════════════════════════════════

render_progress_summary() {
    if [ ! -f "$STATE_FILE" ]; then
        echo "No state file"
        return 1
    fi

    local total=$(jq -r '.plan.stories | length' "$STATE_FILE" 2>/dev/null || echo "0")
    local completed=$(jq -r '[.plan.stories[] | select(.status == "completed")] | length' "$STATE_FILE" 2>/dev/null || echo "0")
    local in_progress=$(jq -r '[.plan.stories[] | select(.status == "in_progress")] | length' "$STATE_FILE" 2>/dev/null || echo "0")
    local failed=$(jq -r '[.plan.stories[] | select(.status == "failed")] | length' "$STATE_FILE" 2>/dev/null || echo "0")

    local percentage=0
    [ "$total" -gt 0 ] && percentage=$((completed * 100 / total))

    echo "Stories: $completed/$total completed | $in_progress running | $failed failed"
    render_progress_bar 40 "$percentage"
    echo "ETA: $(estimate_eta)"
}

# ════════════════════════════════════════════════════════════════════
# FULL DASHBOARD
# ════════════════════════════════════════════════════════════════════

render_dashboard() {
    local task_name=$(jq -r '.task.original_request // "Unknown task"' "$STATE_FILE" 2>/dev/null | head -c 60)
    local phase=$(jq -r '.execution.status // "pending"' "$STATE_FILE" 2>/dev/null)

    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    NONSTOP PROGRESS DASHBOARD                    ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    printf "║  Task: %-57s ║\n" "${task_name:0:57}"
    printf "║  Phase: %-56s ║\n" "$phase"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""

    render_progress_summary
    echo ""

    render_story_table
    echo ""

    render_current_task
    echo ""
}

# ════════════════════════════════════════════════════════════════════
# COMPACT DASHBOARD (for inline display)
# ════════════════════════════════════════════════════════════════════

render_compact() {
    if [ ! -f "$STATE_FILE" ]; then
        echo "[NONSTOP] No active session"
        return 0
    fi

    local total=$(jq -r '.plan.stories | length' "$STATE_FILE" 2>/dev/null || echo "0")
    local completed=$(jq -r '[.plan.stories[] | select(.status == "completed")] | length' "$STATE_FILE" 2>/dev/null || echo "0")
    local current=$(jq -r '.execution.current_story_id // "none"' "$STATE_FILE" 2>/dev/null)

    local percentage=0
    [ "$total" -gt 0 ] && percentage=$((completed * 100 / total))

    echo "[NONSTOP] $(render_progress_bar 20 $percentage) | Current: $current | ETA: $(estimate_eta)"
}

# ════════════════════════════════════════════════════════════════════
# COMMAND DISPATCHER
# ════════════════════════════════════════════════════════════════════

case "${1:-dashboard}" in
    bar)
        render_progress_bar "${2:-30}" "${3:-0}"
        ;;
    table)
        render_story_table
        ;;
    current)
        render_current_task
        ;;
    eta)
        estimate_eta
        ;;
    summary)
        render_progress_summary
        ;;
    dashboard|render)
        render_dashboard
        ;;
    compact)
        render_compact
        ;;
    help|*)
        echo "NONSTOP Progress Dashboard v2.0"
        echo ""
        echo "Usage: progress-dashboard.sh [command]"
        echo ""
        echo "Commands:"
        echo "  dashboard    Full dashboard (default)"
        echo "  compact      Single-line progress"
        echo "  bar W P      Progress bar (width, percentage)"
        echo "  table        Story status table"
        echo "  current      Current task indicator"
        echo "  eta          Estimated time remaining"
        echo "  summary      Progress summary"
        echo "  help         This help message"
        echo ""
        echo "Integration:"
        echo "  Add to SKILL.md responses:"
        echo "  \$(bash lib/progress-dashboard.sh compact)"
        ;;
esac
