#!/bin/bash
# NONSTOP v2.1 - State Manager
# Utilities for managing execution state

set -euo pipefail

CACHE_DIR="${NONSTOP_CACHE_DIR:-$HOME/.claude/nonstop-cache}"
STATE_FILE="$CACHE_DIR/execution-state.json"
BACKUP_DIR="$CACHE_DIR/backups"
AGENT_RESULTS_DIR="$CACHE_DIR/agent-results"

# Ensure directories exist
init_cache() {
    mkdir -p "$CACHE_DIR" "$BACKUP_DIR" "$AGENT_RESULTS_DIR"
}

# Initialize new state from template
init_state() {
    local task_description="$1"
    local template_path="${2:-./templates/execution-state-template.json}"

    init_cache

    local session_id=$(uuidgen 2>/dev/null || date +%s)
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    if [ -f "$template_path" ]; then
        jq --arg sid "$session_id" \
           --arg ts "$timestamp" \
           --arg task "$task_description" \
           '.session_id = $sid | .created_at = $ts | .updated_at = $ts | .task.original_request = $task' \
           "$template_path" > "$STATE_FILE"
    else
        cat > "$STATE_FILE" << EOF
{
  "version": "2.0",
  "session_id": "$session_id",
  "created_at": "$timestamp",
  "updated_at": "$timestamp",
  "task": { "original_request": "$task_description" },
  "preparation": { "status": "pending" },
  "plan": { "status": "pending", "stories": [] },
  "execution": { "status": "pending" },
  "verification": { "status": "pending" }
}
EOF
    fi

    echo "$STATE_FILE"
}

# Read current state
get_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "{}"
    fi
}

# Update state field using jq
update_state() {
    local jq_filter="$1"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    if [ -f "$STATE_FILE" ]; then
        local tmp_file=$(mktemp)
        jq --arg ts "$timestamp" "$jq_filter | .updated_at = \$ts" "$STATE_FILE" > "$tmp_file"
        mv "$tmp_file" "$STATE_FILE"
    fi
}

# Update story status
update_story() {
    local story_id="$1"
    local status="$2"

    update_state "(.plan.stories[] | select(.id == \"$story_id\")).status = \"$status\""
}

# Add new story to plan
add_story() {
    local story_json="$1"

    # Validate JSON
    if ! echo "$story_json" | jq . >/dev/null 2>&1; then
        echo "ERROR: Invalid story JSON" >&2
        return 1
    fi

    update_state ".plan.stories += [$story_json]"
}

# Add story from parameters (convenience function)
add_story_simple() {
    local id="$1"
    local title="$2"
    local points="${3:-3}"
    local deps="${4:-[]}"

    local story_json=$(jq -n \
        --arg id "$id" \
        --arg title "$title" \
        --argjson points "$points" \
        --argjson deps "$deps" \
        '{
            id: $id,
            title: $title,
            points: $points,
            dependencies: $deps,
            status: "pending",
            tasks: [],
            acceptance_criteria: []
        }')

    add_story "$story_json"
}

# Clear all stories (for re-planning)
clear_stories() {
    update_state ".plan.stories = []"
}

# Save preparation data (detected types, skills, MCPs)
save_preparation() {
    local detected_types="$1"
    local recommended_skills="$2"
    local detected_mcps="${3:-}"

    # Convert space-separated to JSON arrays
    local types_json=$(echo "$detected_types" | xargs | tr ' ' '\n' | jq -R . | jq -s .)
    local skills_json=$(echo "$recommended_skills" | xargs | tr ' ' '\n' | jq -R . | jq -s .)
    local mcps_json=$(echo "$detected_mcps" | xargs | tr ' ' '\n' | jq -R . | jq -s .)

    update_state "
        .preparation.status = \"completed\" |
        .preparation.detected_types = $types_json |
        .preparation.recommended_skills = $skills_json |
        .preparation.detected_mcps = $mcps_json
    "
}

# Add invoked skill to state
add_invoked_skill() {
    local skill_name="$1"
    update_state ".preparation.invoked_skills += [\"$skill_name\"] | .preparation.invoked_skills |= unique"
}

# Get preparation summary
get_preparation() {
    if [ -f "$STATE_FILE" ]; then
        jq -r '
            "Detected Types: \(.preparation.detected_types // [] | join(", "))",
            "Recommended Skills: \(.preparation.recommended_skills // [] | join(", "))",
            "Detected MCPs: \(.preparation.detected_mcps // [] | join(", "))",
            "Invoked Skills: \(.preparation.invoked_skills // [] | join(", "))"
        ' "$STATE_FILE" 2>/dev/null
    fi
}

# Update task status
update_task() {
    local task_id="$1"
    local status="$2"

    # task_id format: S1.T1
    local story_id=$(echo "$task_id" | cut -d. -f1)

    update_state "(.plan.stories[] | select(.id == \"$story_id\")).tasks[] | select(.id == \"$task_id\").status = \"$status\""
}

# Update subtask status
update_subtask() {
    local subtask_id="$1"
    local status="$2"

    # subtask_id format: S1.T1.1
    local story_id=$(echo "$subtask_id" | cut -d. -f1)
    local task_id=$(echo "$subtask_id" | cut -d. -f1-2)

    update_state "
        (.plan.stories[] | select(.id == \"$story_id\"))
        .tasks[] | select(.id == \"$task_id\")
        .subtasks[] | select(.id == \"$subtask_id\")
        .status = \"$status\"
    "
}

# Set current execution point
set_current() {
    local story_id="${1:-null}"
    local task_id="${2:-null}"
    local subtask_id="${3:-null}"

    update_state "
        .execution.current_story_id = $([ "$story_id" = "null" ] && echo null || echo \"$story_id\") |
        .execution.current_task_id = $([ "$task_id" = "null" ] && echo null || echo \"$task_id\") |
        .execution.current_subtask_id = $([ "$subtask_id" = "null" ] && echo null || echo \"$subtask_id\")
    "
}

# Add file to modified list
add_modified_file() {
    local file_path="$1"

    update_state ".execution.files_modified += [\"$file_path\"] | .execution.files_modified |= unique"
}

# Record error
add_error() {
    local error_msg="$1"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    update_state ".execution.errors_encountered += [{\"time\": \"$timestamp\", \"error\": \"$error_msg\"}]"
}

# Create backup
backup_state() {
    if [ -f "$STATE_FILE" ]; then
        local backup_name="state-$(date +%Y%m%d-%H%M%S).json"
        cp "$STATE_FILE" "$BACKUP_DIR/$backup_name"
        echo "$BACKUP_DIR/$backup_name"
    fi
}

# Save agent result
save_agent_result() {
    local story_id="$1"
    local result="$2"

    echo "$result" > "$AGENT_RESULTS_DIR/${story_id}-result.json"
}

# Get progress summary
get_progress() {
    if [ -f "$STATE_FILE" ]; then
        jq -r '
            def count_by_status(status): [.plan.stories[].tasks[].subtasks[] | select(.status == status)] | length;

            "Stories: \(.plan.stories | length)",
            "Completed: \([.plan.stories[] | select(.status == "completed")] | length)",
            "In Progress: \([.plan.stories[] | select(.status == "in_progress")] | length)",
            "Current: \(.execution.current_story_id // "none") / \(.execution.current_task_id // "none")"
        ' "$STATE_FILE" 2>/dev/null || echo "No state file"
    fi
}

# Check if nonstop is active
is_active() {
    if [ -f "$STATE_FILE" ]; then
        local status=$(jq -r '.execution.status' "$STATE_FILE" 2>/dev/null)
        [ "$status" = "in_progress" ] && echo "true" || echo "false"
    else
        echo "false"
    fi
}

# Get recovery info for compact
get_recovery_info() {
    if [ -f "$STATE_FILE" ]; then
        jq '{
            active: (.execution.status == "in_progress"),
            current_story: .execution.current_story_id,
            current_task: .execution.current_task_id,
            task_description: .task.original_request,
            progress: {
                total_stories: (.plan.stories | length),
                completed: ([.plan.stories[] | select(.status == "completed")] | length)
            }
        }' "$STATE_FILE"
    fi
}

# Command dispatcher
case "${1:-help}" in
    init) init_state "${2:-}" "${3:-}" ;;
    get) get_state ;;
    update) update_state "$2" ;;
    story) update_story "$2" "$3" ;;
    add-story) add_story "$2" ;;
    add-story-simple) add_story_simple "$2" "$3" "${4:-3}" "${5:-[]}" ;;
    clear-stories) clear_stories ;;
    save-preparation) save_preparation "$2" "$3" "${4:-}" ;;
    add-skill) add_invoked_skill "$2" ;;
    get-preparation) get_preparation ;;
    task) update_task "$2" "$3" ;;
    subtask) update_subtask "$2" "$3" ;;
    current) set_current "${2:-}" "${3:-}" "${4:-}" ;;
    file) add_modified_file "$2" ;;
    error) add_error "$2" ;;
    backup) backup_state ;;
    agent-result) save_agent_result "$2" "$3" ;;
    progress) get_progress ;;
    active) is_active ;;
    recovery) get_recovery_info ;;
    help|*)
        echo "NONSTOP State Manager v2.0"
        echo ""
        echo "Usage: state-manager.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  init <task>          Initialize new state"
        echo "  get                  Get current state JSON"
        echo "  update <jq-filter>   Update state with jq filter"
        echo "  story <id> <status>  Update story status"
        echo "  add-story <json>     Add story from JSON"
        echo "  add-story-simple <id> <title> [points] [deps]  Add story"
        echo "  clear-stories        Clear all stories"
        echo "  save-preparation <types> <skills> [mcps]  Save prep data"
        echo "  add-skill <name>     Record invoked skill"
        echo "  get-preparation      Show preparation summary"
        echo "  task <id> <status>   Update task status"
        echo "  subtask <id> <status> Update subtask status"
        echo "  current <s> <t> <st> Set current execution point"
        echo "  file <path>          Add file to modified list"
        echo "  error <msg>          Record an error"
        echo "  backup               Create state backup"
        echo "  progress             Show progress summary"
        echo "  active               Check if nonstop active"
        echo "  recovery             Get recovery info"
        ;;
esac
