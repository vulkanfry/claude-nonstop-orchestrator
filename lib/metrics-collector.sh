#!/bin/bash
# NONSTOP v2.0 - Metrics Collector
# Track execution metrics and generate reports

set -euo pipefail

CACHE_DIR="${NONSTOP_CACHE_DIR:-$HOME/.claude/nonstop-cache}"
STATE_FILE="$CACHE_DIR/execution-state.json"
METRICS_FILE="$CACHE_DIR/metrics.json"
HISTORY_FILE="$CACHE_DIR/metrics-history.json"

# Initialize files
[ -f "$METRICS_FILE" ] || echo '{"timings":{},"file_changes":{"created":[],"modified":[],"deleted":[]},"events":[],"counters":{}}' > "$METRICS_FILE"
[ -f "$HISTORY_FILE" ] || echo '{"sessions":[]}' > "$HISTORY_FILE"

# ════════════════════════════════════════════════════════════════════
# TIMING METRICS
# ════════════════════════════════════════════════════════════════════

start_timer() {
    local event_name="$1"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local epoch=$(date +%s)

    local tmp_file=$(mktemp)
    jq --arg name "$event_name" \
       --arg ts "$timestamp" \
       --argjson epoch "$epoch" \
       '.timings[$name] = {start: $ts, start_epoch: $epoch, end: null, duration: null}' \
       "$METRICS_FILE" > "$tmp_file"
    mv "$tmp_file" "$METRICS_FILE"

    echo "Timer started: $event_name"
}

end_timer() {
    local event_name="$1"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local epoch=$(date +%s)

    # Get start epoch
    local start_epoch=$(jq -r ".timings[\"$event_name\"].start_epoch // 0" "$METRICS_FILE" 2>/dev/null)
    local duration=$((epoch - start_epoch))

    local tmp_file=$(mktemp)
    jq --arg name "$event_name" \
       --arg ts "$timestamp" \
       --argjson duration "$duration" \
       '.timings[$name].end = $ts | .timings[$name].duration = $duration' \
       "$METRICS_FILE" > "$tmp_file"
    mv "$tmp_file" "$METRICS_FILE"

    echo "Timer ended: $event_name (${duration}s)"
}

get_duration() {
    local event_name="$1"
    jq -r ".timings[\"$event_name\"].duration // \"not recorded\"" "$METRICS_FILE" 2>/dev/null
}

# ════════════════════════════════════════════════════════════════════
# FILE CHANGE METRICS
# ════════════════════════════════════════════════════════════════════

record_file_change() {
    local action="$1"  # created, modified, deleted
    local file_path="$2"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    local tmp_file=$(mktemp)
    case "$action" in
        created|modified|deleted)
            jq --arg action "$action" \
               --arg file "$file_path" \
               --arg ts "$timestamp" \
               '.file_changes[$action] += [{path: $file, at: $ts}] | .file_changes[$action] |= unique_by(.path)' \
               "$METRICS_FILE" > "$tmp_file"
            mv "$tmp_file" "$METRICS_FILE"
            echo "Recorded: $action $file_path"
            ;;
        *)
            echo "Unknown action: $action (use: created, modified, deleted)"
            return 1
            ;;
    esac
}

# ════════════════════════════════════════════════════════════════════
# EVENT TRACKING
# ════════════════════════════════════════════════════════════════════

record_event() {
    local event_type="$1"  # story_complete, task_complete, verification, gate_check
    local status="$2"       # success, failure, skipped
    local details="${3:-}"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    local tmp_file=$(mktemp)
    jq --arg type "$event_type" \
       --arg status "$status" \
       --arg details "$details" \
       --arg ts "$timestamp" \
       '.events += [{type: $type, status: $status, details: $details, at: $ts}]' \
       "$METRICS_FILE" > "$tmp_file"
    mv "$tmp_file" "$METRICS_FILE"

    # Update counters
    tmp_file=$(mktemp)
    jq --arg key "${event_type}_${status}" \
       '.counters[$key] = ((.counters[$key] // 0) + 1)' \
       "$METRICS_FILE" > "$tmp_file"
    mv "$tmp_file" "$METRICS_FILE"

    echo "Event: $event_type ($status)"
}

# ════════════════════════════════════════════════════════════════════
# SESSION METRICS
# ════════════════════════════════════════════════════════════════════

show_session_metrics() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "                   SESSION METRICS"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Timings
    echo "TIMINGS"
    echo "───────────────────────────────────────────────────────────────"
    jq -r '.timings | to_entries[] | "  \(.key): \(.value.duration // "running")s"' "$METRICS_FILE" 2>/dev/null || echo "  No timings recorded"
    echo ""

    # File changes
    echo "FILE CHANGES"
    echo "───────────────────────────────────────────────────────────────"
    local created=$(jq '.file_changes.created | length' "$METRICS_FILE" 2>/dev/null || echo "0")
    local modified=$(jq '.file_changes.modified | length' "$METRICS_FILE" 2>/dev/null || echo "0")
    local deleted=$(jq '.file_changes.deleted | length' "$METRICS_FILE" 2>/dev/null || echo "0")
    echo "  Created: $created | Modified: $modified | Deleted: $deleted"
    echo ""

    # Events
    echo "EVENTS"
    echo "───────────────────────────────────────────────────────────────"
    jq -r '.counters | to_entries[] | "  \(.key): \(.value)"' "$METRICS_FILE" 2>/dev/null || echo "  No events recorded"
    echo ""

    echo "═══════════════════════════════════════════════════════════════"
}

# ════════════════════════════════════════════════════════════════════
# SUMMARY REPORT
# ════════════════════════════════════════════════════════════════════

generate_report() {
    local session_id=$(jq -r '.session_id // "unknown"' "$STATE_FILE" 2>/dev/null)
    local task=$(jq -r '.task.original_request // "unknown"' "$STATE_FILE" 2>/dev/null | head -c 60)

    # Calculate total duration
    local session_start=$(jq -r '.timings.session.start_epoch // 0' "$METRICS_FILE" 2>/dev/null)
    local now=$(date +%s)
    local session_end=$(jq -r '.timings.session.end_epoch // empty' "$METRICS_FILE" 2>/dev/null)
    [ -z "$session_end" ] && session_end=$now
    local total_duration=$((session_end - session_start))

    # Format duration
    local hours=$((total_duration / 3600))
    local minutes=$(((total_duration % 3600) / 60))
    local seconds=$((total_duration % 60))
    local duration_str=""
    [ $hours -gt 0 ] && duration_str="${hours}h "
    [ $minutes -gt 0 ] && duration_str="${duration_str}${minutes}m "
    duration_str="${duration_str}${seconds}s"

    # Story stats
    local total_stories=$(jq '.plan.stories | length' "$STATE_FILE" 2>/dev/null || echo "0")
    local completed_stories=$(jq '[.plan.stories[] | select(.status == "completed")] | length' "$STATE_FILE" 2>/dev/null || echo "0")
    local failed_stories=$(jq '[.plan.stories[] | select(.status == "failed")] | length' "$STATE_FILE" 2>/dev/null || echo "0")
    local success_rate=0
    [ "$total_stories" -gt 0 ] && success_rate=$((completed_stories * 100 / total_stories))

    # File stats
    local files_created=$(jq '.file_changes.created | length' "$METRICS_FILE" 2>/dev/null || echo "0")
    local files_modified=$(jq '.file_changes.modified | length' "$METRICS_FILE" 2>/dev/null || echo "0")
    local files_deleted=$(jq '.file_changes.deleted | length' "$METRICS_FILE" 2>/dev/null || echo "0")

    # Gate stats
    local gates_passed=$(jq '.counters.gate_check_success // 0' "$METRICS_FILE" 2>/dev/null)
    local gates_failed=$(jq '.counters.gate_check_failure // 0' "$METRICS_FILE" 2>/dev/null)

    # Verification loops
    local verify_loops=$(jq '.counters.verification_success // 0' "$METRICS_FILE" 2>/dev/null)

    # Phase timings
    local planning_time=$(jq -r '.timings.planning.duration // 0' "$METRICS_FILE" 2>/dev/null)
    local execution_time=$(jq -r '.timings.execution.duration // 0' "$METRICS_FILE" 2>/dev/null)
    local verification_time=$(jq -r '.timings.verification.duration // 0' "$METRICS_FILE" 2>/dev/null)

    # Generate report
    cat << EOF

══════════════════════════════════════════════════════════════════
                    NONSTOP SESSION REPORT
══════════════════════════════════════════════════════════════════

Session: $session_id
Task: ${task}...
Duration: $duration_str

STORIES
───────────────────────────────────────────────────────────────────
Total: $total_stories | Completed: $completed_stories | Failed: $failed_stories
Success Rate: ${success_rate}%

TIMING BREAKDOWN
───────────────────────────────────────────────────────────────────
Planning:     ${planning_time}s
Execution:    ${execution_time}s
Verification: ${verification_time}s

FILES
───────────────────────────────────────────────────────────────────
Created: $files_created | Modified: $files_modified | Deleted: $files_deleted

QUALITY
───────────────────────────────────────────────────────────────────
Gate Checks: $gates_passed passed, $gates_failed failed
Verification Loops: $verify_loops

══════════════════════════════════════════════════════════════════

EOF

    # List files
    echo "FILES CREATED:"
    jq -r '.file_changes.created[].path' "$METRICS_FILE" 2>/dev/null | head -20 | sed 's/^/  /'
    echo ""
    echo "FILES MODIFIED:"
    jq -r '.file_changes.modified[].path' "$METRICS_FILE" 2>/dev/null | head -20 | sed 's/^/  /'
    echo ""
}

# ════════════════════════════════════════════════════════════════════
# HISTORY
# ════════════════════════════════════════════════════════════════════

save_to_history() {
    local session_id=$(jq -r '.session_id // "unknown"' "$STATE_FILE" 2>/dev/null)
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Get current metrics
    local metrics=$(cat "$METRICS_FILE")

    local tmp_file=$(mktemp)
    jq --arg id "$session_id" \
       --arg ts "$timestamp" \
       --argjson metrics "$metrics" \
       '.sessions += [{session_id: $id, saved_at: $ts, metrics: $metrics}]' \
       "$HISTORY_FILE" > "$tmp_file"
    mv "$tmp_file" "$HISTORY_FILE"

    echo "Session saved to history: $session_id"
}

show_history() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "                   METRICS HISTORY"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    jq -r '.sessions | sort_by(.saved_at) | reverse | .[:10][] |
        "[\(.session_id)]\n  Saved: \(.saved_at)\n  Files: \(.metrics.file_changes.created | length) created, \(.metrics.file_changes.modified | length) modified\n"' \
        "$HISTORY_FILE" 2>/dev/null || echo "No history"

    echo "═══════════════════════════════════════════════════════════════"
}

# ════════════════════════════════════════════════════════════════════
# RESET
# ════════════════════════════════════════════════════════════════════

reset_metrics() {
    echo '{"timings":{},"file_changes":{"created":[],"modified":[],"deleted":[]},"events":[],"counters":{}}' > "$METRICS_FILE"
    echo "Metrics reset"
}

# ════════════════════════════════════════════════════════════════════
# COMMAND DISPATCHER
# ════════════════════════════════════════════════════════════════════

case "${1:-help}" in
    start)
        if [ -z "${2:-}" ]; then
            echo "Usage: metrics-collector.sh start <event_name>"
            exit 1
        fi
        start_timer "$2"
        ;;
    end)
        if [ -z "${2:-}" ]; then
            echo "Usage: metrics-collector.sh end <event_name>"
            exit 1
        fi
        end_timer "$2"
        ;;
    duration)
        if [ -z "${2:-}" ]; then
            echo "Usage: metrics-collector.sh duration <event_name>"
            exit 1
        fi
        get_duration "$2"
        ;;
    file-change)
        if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
            echo "Usage: metrics-collector.sh file-change <created|modified|deleted> <path>"
            exit 1
        fi
        record_file_change "$2" "$3"
        ;;
    record)
        if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
            echo "Usage: metrics-collector.sh record <event_type> <status> [details]"
            exit 1
        fi
        record_event "$2" "$3" "${4:-}"
        ;;
    session)
        show_session_metrics
        ;;
    report)
        generate_report
        ;;
    save)
        save_to_history
        ;;
    history)
        show_history
        ;;
    reset)
        reset_metrics
        ;;
    help|*)
        echo "NONSTOP Metrics Collector v2.0"
        echo ""
        echo "Usage: metrics-collector.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  start <event>              Start timer for event"
        echo "  end <event>                End timer for event"
        echo "  duration <event>           Get event duration"
        echo "  file-change <action> <path>  Record file change"
        echo "  record <type> <status>     Record event"
        echo "  session                    Show current session metrics"
        echo "  report                     Generate full report"
        echo "  save                       Save session to history"
        echo "  history                    Show metrics history"
        echo "  reset                      Clear current metrics"
        echo "  help                       This help message"
        echo ""
        echo "Event Types: story_complete, task_complete, verification, gate_check"
        echo "Status: success, failure, skipped"
        echo "File Actions: created, modified, deleted"
        echo ""
        echo "Examples:"
        echo "  metrics-collector.sh start planning"
        echo "  metrics-collector.sh end planning"
        echo "  metrics-collector.sh file-change created src/new-file.ts"
        echo "  metrics-collector.sh record story_complete success S1"
        ;;
esac
