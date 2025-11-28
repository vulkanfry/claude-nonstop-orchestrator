#!/bin/bash
# NONSTOP v2.0 - Quality Gate System
# Configurable quality checks between execution phases

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONFIG_FILE="$PROJECT_ROOT/.nonstop.json"
CACHE_DIR="${NONSTOP_CACHE_DIR:-$HOME/.claude/nonstop-cache}"
STATE_FILE="$CACHE_DIR/execution-state.json"
GATE_RESULTS_FILE="$CACHE_DIR/gate-results.json"

# Initialize gate results
[ -f "$GATE_RESULTS_FILE" ] || echo '{"gates":{}}' > "$GATE_RESULTS_FILE"

# ════════════════════════════════════════════════════════════════════
# BUILT-IN GATE CHECKS
# ════════════════════════════════════════════════════════════════════

check_files_exist() {
    local files="${1:-}"
    local missing=()

    if [ -z "$files" ]; then
        # Default: check common required files
        files="package.json"
    fi

    for file in $files; do
        if [ ! -f "$PROJECT_ROOT/$file" ]; then
            missing+=("$file")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "FAIL: Missing files: ${missing[*]}"
        return 1
    fi

    echo "PASS: All required files exist"
    return 0
}

check_tests_pass() {
    local cmd="${1:-npm run test}"

    echo "Running: $cmd"
    if eval "cd '$PROJECT_ROOT' && $cmd" > /dev/null 2>&1; then
        echo "PASS: Tests passed"
        return 0
    else
        echo "FAIL: Tests failed"
        return 1
    fi
}

check_lint_clean() {
    local cmd="${1:-npm run lint}"

    echo "Running: $cmd"
    if eval "cd '$PROJECT_ROOT' && $cmd" > /dev/null 2>&1; then
        echo "PASS: Lint clean"
        return 0
    else
        echo "FAIL: Lint errors found"
        return 1
    fi
}

check_no_type_errors() {
    local cmd="${1:-npm run typecheck}"

    # Check if TypeScript exists
    if [ ! -f "$PROJECT_ROOT/tsconfig.json" ]; then
        echo "SKIP: No TypeScript config found"
        return 0
    fi

    echo "Running: $cmd"
    if eval "cd '$PROJECT_ROOT' && $cmd" > /dev/null 2>&1; then
        echo "PASS: No type errors"
        return 0
    else
        echo "FAIL: Type errors found"
        return 1
    fi
}

check_build_success() {
    local cmd="${1:-npm run build}"

    echo "Running: $cmd"
    if eval "cd '$PROJECT_ROOT' && $cmd" > /dev/null 2>&1; then
        echo "PASS: Build successful"
        return 0
    else
        echo "FAIL: Build failed"
        return 1
    fi
}

check_no_secrets() {
    local patterns="API_KEY|SECRET|PASSWORD|PRIVATE_KEY|ACCESS_TOKEN"

    # Search for hardcoded secrets (excluding .env files and node_modules)
    local found=$(grep -rE "$patterns" "$PROJECT_ROOT" \
        --include="*.ts" --include="*.js" --include="*.tsx" --include="*.jsx" \
        --exclude-dir=node_modules --exclude-dir=.git \
        2>/dev/null | grep -v "process.env" | head -5 || true)

    if [ -n "$found" ]; then
        echo "FAIL: Potential hardcoded secrets found"
        echo "$found"
        return 1
    fi

    echo "PASS: No hardcoded secrets detected"
    return 0
}

check_custom_script() {
    local script="$1"

    if [ ! -f "$script" ]; then
        echo "FAIL: Script not found: $script"
        return 1
    fi

    echo "Running custom script: $script"
    if bash "$script"; then
        echo "PASS: Custom script passed"
        return 0
    else
        echo "FAIL: Custom script failed"
        return 1
    fi
}

# ════════════════════════════════════════════════════════════════════
# GATE CHECK EXECUTOR
# ════════════════════════════════════════════════════════════════════

run_gate_check() {
    local check_type="$1"
    local args="${2:-}"
    local result=""
    local status=0

    case "$check_type" in
        files_exist)
            result=$(check_files_exist "$args") || status=1
            ;;
        tests_pass)
            result=$(check_tests_pass "$args") || status=1
            ;;
        lint_clean)
            result=$(check_lint_clean "$args") || status=1
            ;;
        no_type_errors)
            result=$(check_no_type_errors "$args") || status=1
            ;;
        build_success)
            result=$(check_build_success "$args") || status=1
            ;;
        no_secrets)
            result=$(check_no_secrets) || status=1
            ;;
        custom_script)
            result=$(check_custom_script "$args") || status=1
            ;;
        *)
            result="UNKNOWN: Check type not recognized: $check_type"
            status=1
            ;;
    esac

    # Record result
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local tmp_file=$(mktemp)
    jq --arg check "$check_type" \
       --arg status "$([ $status -eq 0 ] && echo 'pass' || echo 'fail')" \
       --arg result "$result" \
       --arg ts "$timestamp" \
       '.gates[$check] = {status: $status, result: $result, checked_at: $ts}' \
       "$GATE_RESULTS_FILE" > "$tmp_file"
    mv "$tmp_file" "$GATE_RESULTS_FILE"

    echo "$result"
    return $status
}

# ════════════════════════════════════════════════════════════════════
# PHASE GATE RUNNER
# ════════════════════════════════════════════════════════════════════

run_phase_gates() {
    local phase="$1"
    local fail_fast="${2:-true}"
    local passed=0
    local failed=0
    local skipped=0

    echo "═══════════════════════════════════════════════════════════════"
    echo "  QUALITY GATE: $phase"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Read gate config
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "No config file found, using defaults"
        # Default gates
        case "$phase" in
            pre_execute)
                checks="files_exist"
                ;;
            post_execute)
                checks="lint_clean"
                ;;
            pre_complete)
                checks="no_type_errors"
                ;;
            *)
                checks=""
                ;;
        esac
    else
        # Read from config
        local enabled=$(jq -r ".quality_gates.gates.${phase}.enabled // true" "$CONFIG_FILE" 2>/dev/null)
        if [ "$enabled" = "false" ]; then
            echo "Gate disabled for phase: $phase"
            return 0
        fi

        checks=$(jq -r ".quality_gates.gates.${phase}.checks // [] | .[]" "$CONFIG_FILE" 2>/dev/null || echo "")
    fi

    if [ -z "$checks" ]; then
        echo "No checks configured for phase: $phase"
        return 0
    fi

    # Run each check
    for check in $checks; do
        echo "┌─ Check: $check"

        if run_gate_check "$check"; then
            passed=$((passed + 1))
            echo "└─ ✓ PASSED"
        else
            failed=$((failed + 1))
            echo "└─ ✗ FAILED"

            if [ "$fail_fast" = "true" ]; then
                echo ""
                echo "GATE FAILED (fail_fast=true)"
                return 1
            fi
        fi
        echo ""
    done

    # Summary
    echo "───────────────────────────────────────────────────────────────"
    echo "  Results: $passed passed, $failed failed, $skipped skipped"

    if [ "$failed" -gt 0 ]; then
        echo "  Status: FAILED"
        echo "═══════════════════════════════════════════════════════════════"
        return 1
    else
        echo "  Status: PASSED"
        echo "═══════════════════════════════════════════════════════════════"
        return 0
    fi
}

# ════════════════════════════════════════════════════════════════════
# GATE STATUS
# ════════════════════════════════════════════════════════════════════

show_gate_status() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "                    GATE STATUS"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    if [ ! -f "$GATE_RESULTS_FILE" ]; then
        echo "No gate checks recorded yet"
        return 0
    fi

    jq -r '.gates | to_entries[] | "[\(.value.status | ascii_upcase)] \(.key)\n    Last check: \(.value.checked_at)\n    Result: \(.value.result)\n"' "$GATE_RESULTS_FILE" 2>/dev/null || echo "No results"

    echo "═══════════════════════════════════════════════════════════════"
}

# ════════════════════════════════════════════════════════════════════
# LIST AVAILABLE GATES
# ════════════════════════════════════════════════════════════════════

list_gates() {
    echo "Available Gate Checks:"
    echo ""
    echo "  files_exist      - Check required files exist"
    echo "  tests_pass       - Run test suite"
    echo "  lint_clean       - Run linter"
    echo "  no_type_errors   - Run TypeScript check"
    echo "  build_success    - Run build"
    echo "  no_secrets       - Scan for hardcoded secrets"
    echo "  custom_script    - Run custom script"
    echo ""
    echo "Configured Phases (from .nonstop.json):"

    if [ -f "$CONFIG_FILE" ]; then
        jq -r '.quality_gates.gates | keys[]' "$CONFIG_FILE" 2>/dev/null | while read phase; do
            local checks=$(jq -r ".quality_gates.gates.${phase}.checks | join(\", \")" "$CONFIG_FILE" 2>/dev/null)
            echo "  $phase: $checks"
        done
    else
        echo "  (no config file)"
    fi
}

# ════════════════════════════════════════════════════════════════════
# COMMAND DISPATCHER
# ════════════════════════════════════════════════════════════════════

case "${1:-help}" in
    check)
        if [ -z "${2:-}" ]; then
            echo "Usage: quality-gate.sh check <check_type> [args]"
            exit 1
        fi
        run_gate_check "$2" "${3:-}"
        ;;
    run-phase|phase)
        if [ -z "${2:-}" ]; then
            echo "Usage: quality-gate.sh run-phase <phase_name>"
            echo "Phases: pre_execute, post_execute, pre_complete"
            exit 1
        fi
        run_phase_gates "$2" "${3:-true}"
        ;;
    status)
        show_gate_status
        ;;
    list)
        list_gates
        ;;
    reset)
        echo '{"gates":{}}' > "$GATE_RESULTS_FILE"
        echo "Gate results reset"
        ;;
    help|*)
        echo "NONSTOP Quality Gate System v2.0"
        echo ""
        echo "Usage: quality-gate.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  check <type> [args]   Run single gate check"
        echo "  run-phase <phase>     Run all gates for phase"
        echo "  status                Show gate check history"
        echo "  list                  List available gates"
        echo "  reset                 Clear gate results"
        echo "  help                  This help message"
        echo ""
        echo "Check Types:"
        echo "  files_exist, tests_pass, lint_clean,"
        echo "  no_type_errors, build_success, no_secrets,"
        echo "  custom_script"
        echo ""
        echo "Phases:"
        echo "  pre_execute, post_execute, pre_complete"
        echo ""
        echo "Examples:"
        echo "  quality-gate.sh check lint_clean"
        echo "  quality-gate.sh run-phase pre_complete"
        ;;
esac
