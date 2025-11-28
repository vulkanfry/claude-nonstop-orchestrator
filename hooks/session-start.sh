#!/bin/bash
# NONSTOP v2.1 - Session Start Hook
# Simplified: State is managed by skill, hook just detects and prompts

HOOK_INPUT=$(cat 2>/dev/null || echo '{}')
SOURCE=$(echo "$HOOK_INPUT" | jq -r '.source // "startup"' 2>/dev/null || echo "startup")

CACHE_DIR="${NONSTOP_CACHE_DIR:-$HOME/.claude/nonstop-cache}"
STATE_FILE="$CACHE_DIR/execution-state.json"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LIB_DIR="${NONSTOP_LIB_DIR:-$PROJECT_ROOT/.claude/lib}"

echo "=== NONSTOP v2.1 ==="
echo "Trigger: $SOURCE"
echo "Project: $PROJECT_ROOT"
echo ""

# ============================================================
# CHECK FOR ACTIVE NONSTOP SESSION
# ============================================================

if [ -f "$STATE_FILE" ]; then
    # Check if state is recent (within 4 hours)
    if [ "$(find "$STATE_FILE" -mmin -240 2>/dev/null)" ]; then
        EXEC_STATUS=$(jq -r '.execution.status // "none"' "$STATE_FILE" 2>/dev/null || echo "none")

        if [ "$EXEC_STATUS" = "in_progress" ]; then
            echo "============================================================"
            echo "       NONSTOP SESSION ACTIVE - AUTOMATIC RECOVERY          "
            echo "============================================================"
            echo ""

            # Extract recovery info
            TASK=$(jq -r '.task.original_request // "unknown"' "$STATE_FILE" 2>/dev/null | head -c 100)

            # Derive current phase from individual statuses
            PREP_STATUS=$(jq -r '.preparation.status // "pending"' "$STATE_FILE" 2>/dev/null)
            PLAN_STATUS_RAW=$(jq -r '.plan.status // "pending"' "$STATE_FILE" 2>/dev/null)
            EXEC_STATUS_RAW=$(jq -r '.execution.status // "pending"' "$STATE_FILE" 2>/dev/null)
            VERIF_STATUS=$(jq -r '.verification.status // "pending"' "$STATE_FILE" 2>/dev/null)

            # Determine current phase
            if [ "$VERIF_STATUS" = "in_progress" ]; then
                CURRENT_PHASE="verification"
            elif [ "$EXEC_STATUS_RAW" = "in_progress" ]; then
                CURRENT_PHASE="execution"
            elif [ "$PLAN_STATUS_RAW" = "in_progress" ]; then
                CURRENT_PHASE="planning"
            elif [ "$PREP_STATUS" = "in_progress" ]; then
                CURRENT_PHASE="preparation"
            elif [ "$PLAN_STATUS_RAW" = "pending" ] && [ "$PREP_STATUS" = "completed" ]; then
                CURRENT_PHASE="planning"
            elif [ "$EXEC_STATUS_RAW" = "pending" ] && [ "$PLAN_STATUS_RAW" = "completed" ]; then
                CURRENT_PHASE="execution"
            elif [ "$VERIF_STATUS" = "pending" ] && [ "$EXEC_STATUS_RAW" = "completed" ]; then
                CURRENT_PHASE="verification"
            else
                CURRENT_PHASE="unknown"
            fi
            CURRENT_STORY=$(jq -r '.execution.current_story_id // "none"' "$STATE_FILE" 2>/dev/null)
            CURRENT_TASK=$(jq -r '.execution.current_task_id // "none"' "$STATE_FILE" 2>/dev/null)
            TOTAL_STORIES=$(jq -r '.plan.stories | length' "$STATE_FILE" 2>/dev/null || echo "0")
            COMPLETED=$(jq -r '[.plan.stories[] | select(.status == "completed")] | length' "$STATE_FILE" 2>/dev/null || echo "0")
            PLAN_STATUS=$(jq -r '.plan.status // "unknown"' "$STATE_FILE" 2>/dev/null)

            echo "Task: $TASK"
            echo ""
            echo "╔════════════════════════════════════════════════════════════╗"
            echo "║  CURRENT PHASE: $CURRENT_PHASE"
            echo "╚════════════════════════════════════════════════════════════╝"
            echo ""
            echo "Plan Status: $PLAN_STATUS_RAW"
            echo "Progress: $COMPLETED / $TOTAL_STORIES stories"
            [ "$CURRENT_STORY" != "none" ] && echo "Current: Story $CURRENT_STORY, Task $CURRENT_TASK"
            echo ""

            if [ "$SOURCE" = "compact" ] || [ "$SOURCE" = "resume" ]; then
                echo "!!! CONTEXT WAS COMPACTED !!!"
                echo ""
                echo "YOU MUST CONTINUE FROM PHASE: $CURRENT_PHASE"
                echo ""
                case "$CURRENT_PHASE" in
                    "planning"|"phase_1")
                        echo ">>> DO NOT START IMPLEMENTATION <<<"
                        echo ">>> CONTINUE PLANNING - CREATE/REFINE STORIES <<<"
                        ;;
                    "execution"|"phase_2")
                        echo ">>> CONTINUE EXECUTION FROM STORY $CURRENT_STORY <<<"
                        ;;
                    "verification"|"phase_3")
                        echo ">>> CONTINUE VERIFICATION <<<"
                        ;;
                esac
                echo ""
            fi

            echo "IMMEDIATE ACTION:"
            echo '  Use Skill: skill: "nonstop-orchestrator"'
            echo ""
            echo "The skill will:"
            echo "  1. Read state from: $STATE_FILE"
            echo "  2. RESUME phase: $CURRENT_PHASE"
            echo "  3. Continue until completion"
            echo ""
            echo "!!! DO NOT SKIP PHASES. DO NOT ASK QUESTIONS. INVOKE SKILL NOW !!!"
            echo ""
            echo "============================================================"

        elif [ "$EXEC_STATUS" = "completed" ]; then
            echo "Previous NONSTOP session completed successfully."
            echo "Use /nonstop to start a new task."

        else
            echo "Previous session found (status: $EXEC_STATUS)"
            echo "Use /nonstop to start fresh or resume."
        fi
    else
        echo "State file expired. Use /nonstop to start fresh."
    fi
else
    echo "No active session."
    echo ""
    echo "Use /nonstop to start NONSTOP mode."
fi

echo ""
echo "=== Ready ==="
