#!/bin/bash
# NONSTOP v2.0 - Agent Pool Manager
# Track agents, cache results, optimize batching

set -euo pipefail

CACHE_DIR="${NONSTOP_CACHE_DIR:-$HOME/.claude/nonstop-cache}"
STATE_FILE="$CACHE_DIR/execution-state.json"
AGENT_DIR="$CACHE_DIR/agent-results"
POOL_FILE="$CACHE_DIR/agent-pool.json"

# Initialize directories and files
mkdir -p "$AGENT_DIR"
[ -f "$POOL_FILE" ] || echo '{"agents":[],"stats":{"total":0,"successful":0,"failed":0}}' > "$POOL_FILE"

# ════════════════════════════════════════════════════════════════════
# AGENT REGISTRY
# ════════════════════════════════════════════════════════════════════

register_agent() {
    local agent_id="$1"
    local story_id="$2"
    local agent_type="${3:-general-purpose}"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    local tmp_file=$(mktemp)
    jq --arg id "$agent_id" \
       --arg story "$story_id" \
       --arg type "$agent_type" \
       --arg ts "$timestamp" \
       '.agents += [{
           id: $id,
           story_id: $story,
           type: $type,
           status: "running",
           started_at: $ts,
           completed_at: null,
           result: null
       }] |
       .stats.total += 1' \
       "$POOL_FILE" > "$tmp_file"
    mv "$tmp_file" "$POOL_FILE"

    echo "Agent registered: $agent_id (Story: $story_id)"
}

# ════════════════════════════════════════════════════════════════════
# AGENT STATUS
# ════════════════════════════════════════════════════════════════════

get_agent_status() {
    local agent_id="$1"

    jq -r ".agents[] | select(.id == \"$agent_id\") | \"Status: \(.status)\nStory: \(.story_id)\nStarted: \(.started_at)\nCompleted: \(.completed_at // \"running\")\"" "$POOL_FILE" 2>/dev/null || echo "Agent not found"
}

list_agents() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "                      AGENT POOL"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    local running=$(jq '[.agents[] | select(.status == "running")] | length' "$POOL_FILE" 2>/dev/null || echo "0")
    local completed=$(jq '[.agents[] | select(.status == "completed")] | length' "$POOL_FILE" 2>/dev/null || echo "0")
    local failed=$(jq '[.agents[] | select(.status == "failed")] | length' "$POOL_FILE" 2>/dev/null || echo "0")

    echo "Summary: $running running | $completed completed | $failed failed"
    echo ""
    echo "┌────────────────┬──────────┬────────────┬─────────────────────┐"
    echo "│ Agent ID       │ Story    │ Status     │ Duration            │"
    echo "├────────────────┼──────────┼────────────┼─────────────────────┤"

    jq -r '.agents[] | "\(.id)|\(.story_id)|\(.status)|\(.started_at)|\(.completed_at // "running")"' "$POOL_FILE" 2>/dev/null | while IFS='|' read -r id story status started completed; do
        # Calculate duration if completed
        local duration="running..."
        if [ "$completed" != "running" ] && [ "$completed" != "null" ]; then
            local start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$started" "+%s" 2>/dev/null || echo "0")
            local end_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$completed" "+%s" 2>/dev/null || echo "0")
            local diff=$((end_epoch - start_epoch))
            duration="${diff}s"
        fi

        # Status icon
        case "$status" in
            completed) status_icon="✓ done" ;;
            running) status_icon="⟳ run" ;;
            failed) status_icon="✗ fail" ;;
            *) status_icon="? $status" ;;
        esac

        printf "│ %-14s │ %-8s │ %-10s │ %-19s │\n" "${id:0:14}" "$story" "$status_icon" "$duration"
    done

    echo "└────────────────┴──────────┴────────────┴─────────────────────┘"
    echo ""
}

# ════════════════════════════════════════════════════════════════════
# RESULT CACHING
# ════════════════════════════════════════════════════════════════════

cache_result() {
    local agent_id="$1"
    local result="$2"
    local status="${3:-completed}"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Save result to file
    echo "$result" > "$AGENT_DIR/${agent_id}.json"

    # Update pool
    local tmp_file=$(mktemp)
    jq --arg id "$agent_id" \
       --arg status "$status" \
       --arg ts "$timestamp" \
       '(.agents[] | select(.id == $id)) |= . + {
           status: $status,
           completed_at: $ts,
           result_file: ($id + ".json")
       } |
       if $status == "completed" then .stats.successful += 1
       elif $status == "failed" then .stats.failed += 1
       else . end' \
       "$POOL_FILE" > "$tmp_file"
    mv "$tmp_file" "$POOL_FILE"

    echo "Result cached for agent: $agent_id"
}

get_result() {
    local agent_id="$1"
    local result_file="$AGENT_DIR/${agent_id}.json"

    if [ -f "$result_file" ]; then
        cat "$result_file"
    else
        echo "No cached result for agent: $agent_id"
        return 1
    fi
}

# ════════════════════════════════════════════════════════════════════
# AGENT HISTORY
# ════════════════════════════════════════════════════════════════════

show_history() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "                     AGENT HISTORY"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    jq -r '.agents | sort_by(.started_at) | reverse | .[:10][] |
        "[\(.status | ascii_upcase)] \(.id)\n  Story: \(.story_id) | Type: \(.type)\n  Started: \(.started_at)\n  Completed: \(.completed_at // "running")\n"' \
        "$POOL_FILE" 2>/dev/null || echo "No history"

    echo "═══════════════════════════════════════════════════════════════"
}

# ════════════════════════════════════════════════════════════════════
# BATCHING OPTIMIZATION
# ════════════════════════════════════════════════════════════════════

suggest_batch() {
    local stories_json="$1"

    echo "Analyzing stories for optimal batching..."
    echo ""

    # Parse stories and group by dependencies
    local no_deps=$(echo "$stories_json" | jq -r '.[] | select(.dependencies == null or .dependencies == [] or .dependencies == "none") | .id' 2>/dev/null)
    local with_deps=$(echo "$stories_json" | jq -r '.[] | select(.dependencies != null and .dependencies != [] and .dependencies != "none") | .id' 2>/dev/null)

    echo "Batch 1 (parallel - no dependencies):"
    for id in $no_deps; do
        echo "  - $id"
    done

    echo ""
    echo "Batch 2+ (sequential - has dependencies):"
    for id in $with_deps; do
        local deps=$(echo "$stories_json" | jq -r ".[] | select(.id == \"$id\") | .dependencies | if type == \"array\" then join(\", \") else . end" 2>/dev/null)
        echo "  - $id (depends on: $deps)"
    done
}

# ════════════════════════════════════════════════════════════════════
# POOL STATISTICS
# ════════════════════════════════════════════════════════════════════

show_stats() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "                    POOL STATISTICS"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    local total=$(jq '.stats.total' "$POOL_FILE" 2>/dev/null || echo "0")
    local successful=$(jq '.stats.successful' "$POOL_FILE" 2>/dev/null || echo "0")
    local failed=$(jq '.stats.failed' "$POOL_FILE" 2>/dev/null || echo "0")

    echo "Total Agents Launched: $total"
    echo "Successful: $successful"
    echo "Failed: $failed"

    if [ "$total" -gt 0 ]; then
        local rate=$((successful * 100 / total))
        echo "Success Rate: ${rate}%"
    fi

    # Average duration
    local durations=$(jq -r '.agents[] | select(.completed_at != null) |
        ((.completed_at | fromdateiso8601) - (.started_at | fromdateiso8601))' "$POOL_FILE" 2>/dev/null || echo "")

    if [ -n "$durations" ]; then
        local sum=0
        local count=0
        for d in $durations; do
            sum=$((sum + d))
            count=$((count + 1))
        done
        if [ "$count" -gt 0 ]; then
            local avg=$((sum / count))
            echo "Average Duration: ${avg}s"
        fi
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
}

# ════════════════════════════════════════════════════════════════════
# CLEANUP
# ════════════════════════════════════════════════════════════════════

cleanup_pool() {
    local keep="${1:-10}"

    # Keep only last N agents in pool
    local tmp_file=$(mktemp)
    jq --argjson keep "$keep" '.agents = (.agents | sort_by(.started_at) | reverse | .[:$keep])' "$POOL_FILE" > "$tmp_file"
    mv "$tmp_file" "$POOL_FILE"

    # Clean old result files
    local current_agents=$(jq -r '.agents[].id' "$POOL_FILE" 2>/dev/null)
    for file in "$AGENT_DIR"/*.json; do
        [ -f "$file" ] || continue
        local agent_id=$(basename "$file" .json)
        if ! echo "$current_agents" | grep -q "^${agent_id}$"; then
            rm "$file"
        fi
    done

    echo "Pool cleaned, kept last $keep agents"
}

# ════════════════════════════════════════════════════════════════════
# RESET
# ════════════════════════════════════════════════════════════════════

reset_pool() {
    echo '{"agents":[],"stats":{"total":0,"successful":0,"failed":0}}' > "$POOL_FILE"
    rm -f "$AGENT_DIR"/*.json 2>/dev/null || true
    echo "Agent pool reset"
}

# ════════════════════════════════════════════════════════════════════
# COMMAND DISPATCHER
# ════════════════════════════════════════════════════════════════════

case "${1:-help}" in
    register)
        if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
            echo "Usage: agent-pool.sh register <agent_id> <story_id> [type]"
            exit 1
        fi
        register_agent "$2" "$3" "${4:-general-purpose}"
        ;;
    status)
        if [ -z "${2:-}" ]; then
            echo "Usage: agent-pool.sh status <agent_id>"
            exit 1
        fi
        get_agent_status "$2"
        ;;
    list|ls)
        list_agents
        ;;
    cache-result)
        if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
            echo "Usage: agent-pool.sh cache-result <agent_id> <result_json> [status]"
            exit 1
        fi
        cache_result "$2" "$3" "${4:-completed}"
        ;;
    get-result)
        if [ -z "${2:-}" ]; then
            echo "Usage: agent-pool.sh get-result <agent_id>"
            exit 1
        fi
        get_result "$2"
        ;;
    history)
        show_history
        ;;
    suggest-batch)
        if [ -z "${2:-}" ]; then
            echo "Usage: agent-pool.sh suggest-batch '<stories_json>'"
            exit 1
        fi
        suggest_batch "$2"
        ;;
    stats)
        show_stats
        ;;
    cleanup)
        cleanup_pool "${2:-10}"
        ;;
    reset)
        reset_pool
        ;;
    help|*)
        echo "NONSTOP Agent Pool Manager v2.0"
        echo ""
        echo "Usage: agent-pool.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  register <id> <story> [type]   Register new agent"
        echo "  status <id>                    Get agent status"
        echo "  list                           List all agents"
        echo "  cache-result <id> <json>       Cache agent result"
        echo "  get-result <id>                Get cached result"
        echo "  history                        Show agent history"
        echo "  suggest-batch <json>           Suggest optimal batching"
        echo "  stats                          Show pool statistics"
        echo "  cleanup [N]                    Keep last N agents"
        echo "  reset                          Clear entire pool"
        echo "  help                           This help message"
        echo ""
        echo "Examples:"
        echo "  agent-pool.sh register agent-001 S1 general-purpose"
        echo "  agent-pool.sh cache-result agent-001 '{\"status\":\"completed\"}'"
        ;;
esac
