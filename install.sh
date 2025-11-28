#!/bin/bash
set -e

# NONSTOP v2.1 INSTALLER
# Installs the NONSTOP orchestrator for Claude Code

PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-.claude}"

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    NONSTOP v2.1 INSTALLER                        ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║  Progress Dashboard | Checkpoints | Quality Gates | Metrics      ║"
echo "║  Agent Pooling | Domain Skills | ULTRATHINK | Parallel Agents   ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "Source: $PLUGIN_DIR"
echo ""

# Parse arguments
INSTALL_SKILLS=true
INSTALL_HOOKS=true
INSTALL_COMMANDS=true
INSTALL_LIB=true
INSTALL_DOMAIN_SKILLS=true
PROJECT_DIR="."

while [[ $# -gt 0 ]]; do
  case $1 in
    --no-skills)
      INSTALL_SKILLS=false
      shift
      ;;
    --no-hooks)
      INSTALL_HOOKS=false
      shift
      ;;
    --no-commands)
      INSTALL_COMMANDS=false
      shift
      ;;
    --no-lib)
      INSTALL_LIB=false
      shift
      ;;
    --no-domain-skills)
      INSTALL_DOMAIN_SKILLS=false
      shift
      ;;
    --project-dir)
      PROJECT_DIR="$2"
      shift 2
      ;;
    --help)
      echo "Usage: install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --no-skills          Don't install orchestrator skill"
      echo "  --no-hooks           Don't install hooks"
      echo "  --no-commands        Don't install commands"
      echo "  --no-lib             Don't install lib utilities"
      echo "  --no-domain-skills   Don't install domain expert skills"
      echo "  --project-dir        Target project directory (default: current)"
      echo ""
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

cd "$PROJECT_DIR"
PROJECT_ROOT="$(pwd)"
CLAUDE_DIR="$PROJECT_ROOT/$CLAUDE_DIR"

echo "Installing to: $PROJECT_ROOT"
echo ""

# Create directory structure (all inside .claude/)
mkdir -p "$CLAUDE_DIR/skills/nonstop-orchestrator"
mkdir -p "$CLAUDE_DIR/skills/domains"
mkdir -p "$CLAUDE_DIR/hooks"
mkdir -p "$CLAUDE_DIR/commands"
mkdir -p "$CLAUDE_DIR/lib"
mkdir -p "$CLAUDE_DIR/templates"
mkdir -p "$CLAUDE_DIR/config"

# Create cache directories
CACHE_DIR="$HOME/.claude/nonstop-cache"
mkdir -p "$CACHE_DIR/backups"
mkdir -p "$CACHE_DIR/agent-results"
mkdir -p "$CACHE_DIR/checkpoints"
echo "Cache directory: $CACHE_DIR"

# Install skills
if [ "$INSTALL_SKILLS" = true ]; then
  echo ""
  echo "Installing core skills..."
  cp "$PLUGIN_DIR/skills/nonstop-orchestrator/SKILL.md" "$CLAUDE_DIR/skills/nonstop-orchestrator/"
  echo "  [x] nonstop-orchestrator (main orchestrator)"
fi

# Install domain skills
if [ "$INSTALL_DOMAIN_SKILLS" = true ]; then
  echo ""
  echo "Installing domain expert skills..."
  if [ -d "$PLUGIN_DIR/skills/domains" ]; then
    cp -r "$PLUGIN_DIR/skills/domains/"*.md "$CLAUDE_DIR/skills/domains/" 2>/dev/null || true
    for skill in "$CLAUDE_DIR/skills/domains/"*.md; do
      [ -f "$skill" ] && echo "  [x] $(basename "$skill" .md)"
    done
  fi
fi

# Install hooks
if [ "$INSTALL_HOOKS" = true ]; then
  echo ""
  echo "Installing hooks..."
  cp "$PLUGIN_DIR/hooks/session-start.sh" "$CLAUDE_DIR/hooks/"
  cp "$PLUGIN_DIR/hooks/pre-compact.sh" "$CLAUDE_DIR/hooks/"
  cp "$PLUGIN_DIR/hooks/stop.sh" "$CLAUDE_DIR/hooks/"
  cp "$PLUGIN_DIR/hooks/subagent-stop.sh" "$CLAUDE_DIR/hooks/"
  chmod +x "$CLAUDE_DIR/hooks/"*.sh
  echo "  [x] session-start.sh (recovery detection)"
  echo "  [x] pre-compact.sh (state backup)"
  echo "  [x] stop.sh (auto-progress after each response)"
  echo "  [x] subagent-stop.sh (checkpoint on agent complete)"
fi

# Install commands
if [ "$INSTALL_COMMANDS" = true ]; then
  echo ""
  echo "Installing commands..."
  cp "$PLUGIN_DIR/commands/nonstop.md" "$CLAUDE_DIR/commands/"
  echo "  [x] /nonstop (main entry point)"
fi

# Install lib utilities
if [ "$INSTALL_LIB" = true ]; then
  echo ""
  echo "Installing utilities..."

  # Core utilities
  cp "$PLUGIN_DIR/lib/state-manager.sh" "$CLAUDE_DIR/lib/"
  cp "$PLUGIN_DIR/lib/mcp-scanner.sh" "$CLAUDE_DIR/lib/"
  echo "  [x] .claude/lib/state-manager.sh (state persistence)"
  echo "  [x] .claude/lib/mcp-scanner.sh (MCP discovery)"

  # New v2.1 utilities
  [ -f "$PLUGIN_DIR/lib/progress-dashboard.sh" ] && cp "$PLUGIN_DIR/lib/progress-dashboard.sh" "$CLAUDE_DIR/lib/" && echo "  [x] .claude/lib/progress-dashboard.sh (ASCII visualization)"
  [ -f "$PLUGIN_DIR/lib/checkpoint-manager.sh" ] && cp "$PLUGIN_DIR/lib/checkpoint-manager.sh" "$CLAUDE_DIR/lib/" && echo "  [x] .claude/lib/checkpoint-manager.sh (state snapshots)"
  [ -f "$PLUGIN_DIR/lib/quality-gate.sh" ] && cp "$PLUGIN_DIR/lib/quality-gate.sh" "$CLAUDE_DIR/lib/" && echo "  [x] .claude/lib/quality-gate.sh (quality checks)"
  [ -f "$PLUGIN_DIR/lib/agent-pool.sh" ] && cp "$PLUGIN_DIR/lib/agent-pool.sh" "$CLAUDE_DIR/lib/" && echo "  [x] .claude/lib/agent-pool.sh (agent management)"
  [ -f "$PLUGIN_DIR/lib/metrics-collector.sh" ] && cp "$PLUGIN_DIR/lib/metrics-collector.sh" "$CLAUDE_DIR/lib/" && echo "  [x] .claude/lib/metrics-collector.sh (analytics)"
  [ -f "$PLUGIN_DIR/lib/skill-selector.sh" ] && cp "$PLUGIN_DIR/lib/skill-selector.sh" "$CLAUDE_DIR/lib/" && echo "  [x] .claude/lib/skill-selector.sh (domain detection)"

  chmod +x "$CLAUDE_DIR/lib/"*.sh

  echo ""
  echo "Installing templates..."
  cp "$PLUGIN_DIR/templates/execution-state-template.json" "$CLAUDE_DIR/templates/"
  cp "$PLUGIN_DIR/templates/story-template.json" "$CLAUDE_DIR/templates/"
  cp "$PLUGIN_DIR/templates/skill-template.md" "$CLAUDE_DIR/templates/"
  echo "  [x] .claude/templates/execution-state-template.json"
  echo "  [x] .claude/templates/story-template.json"
  echo "  [x] .claude/templates/skill-template.md"

  echo ""
  echo "Installing config..."
  [ -f "$PLUGIN_DIR/config/default.json" ] && cp "$PLUGIN_DIR/config/default.json" "$CLAUDE_DIR/config/"
  [ -f "$PLUGIN_DIR/config/schema.json" ] && cp "$PLUGIN_DIR/config/schema.json" "$CLAUDE_DIR/config/"
  echo "  [x] .claude/config/default.json"
fi

# Create or update settings.json
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

if [ ! -f "$SETTINGS_FILE" ]; then
  echo ""
  echo "Creating settings.json..."
  cat > "$SETTINGS_FILE" << 'EOF'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "allow": ["Skill", "Task", "WebSearch", "mcp__sequential-thinking__sequentialthinking"]
  },
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": ".claude/hooks/session-start.sh" }]
      }
    ],
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": ".claude/hooks/pre-compact.sh" }]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": ".claude/hooks/stop.sh" }]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": ".claude/hooks/subagent-stop.sh" }]
      }
    ]
  }
}
EOF
  echo "  [x] settings.json created"
else
  echo ""
  echo "WARNING: settings.json already exists!"
  echo "Please add these hooks manually:"
  echo ""
  cat << 'EOF'
  "hooks": {
    "SessionStart": [{ "matcher": "", "hooks": [{ "type": "command", "command": ".claude/hooks/session-start.sh" }] }],
    "PreCompact": [{ "matcher": "", "hooks": [{ "type": "command", "command": ".claude/hooks/pre-compact.sh" }] }],
    "Stop": [{ "matcher": "", "hooks": [{ "type": "command", "command": ".claude/hooks/stop.sh" }] }],
    "SubagentStop": [{ "matcher": "", "hooks": [{ "type": "command", "command": ".claude/hooks/subagent-stop.sh" }] }]
  }
EOF
fi

# Create config file
CONFIG_FILE="$PROJECT_ROOT/.nonstop.json"
if [ ! -f "$CONFIG_FILE" ]; then
  echo ""
  echo "Creating .nonstop.json..."
  cat > "$CONFIG_FILE" << 'EOF'
{
  "$schema": "./.claude/config/schema.json",
  "version": "2.1.0",
  "name": "nonstop",

  "project": {
    "root": "${PROJECT_ROOT}",
    "source_dirs": ["src", "app", "lib"],
    "file_extensions": [".ts", ".tsx", ".js", ".jsx", ".py", ".rs"]
  },

  "ultrathink": {
    "min_iterations": 15,
    "explore_codebase": true,
    "parallel_exploration": true
  },

  "parallel_execution": {
    "enabled": true,
    "max_agents": 5,
    "story_parallelization": true
  },

  "verification": {
    "tests": { "enabled": true, "command": "npm run test" },
    "lint": { "enabled": true, "command": "npm run lint" },
    "typecheck": { "enabled": true, "command": "npm run typecheck" },
    "build": { "enabled": true, "command": "npm run build" },
    "code_review": { "enabled": true }
  },

  "quality_gates": {
    "enabled": true,
    "fail_fast": true,
    "gates": {
      "pre_execute": { "enabled": true, "checks": ["files_exist"] },
      "post_execute": { "enabled": true, "checks": ["lint_clean"] },
      "pre_complete": { "enabled": true, "checks": ["no_type_errors", "tests_pass"] }
    }
  },

  "checkpoints": {
    "auto_checkpoint": true,
    "checkpoint_on_story_complete": true,
    "max_checkpoints": 20
  },

  "metrics": {
    "enabled": true,
    "track_timing": true,
    "track_file_changes": true,
    "generate_report": true
  },

  "domain_skills": {
    "enabled": true,
    "auto_detect": true
  },

  "progress_dashboard": {
    "enabled": true,
    "show_in_response": true
  }
}
EOF
  echo "  [x] .nonstop.json created"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    INSTALLATION COMPLETE                         ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "Installed Components:"
[ "$INSTALL_SKILLS" = true ] && echo "  [x] Core: nonstop-orchestrator"
[ "$INSTALL_DOMAIN_SKILLS" = true ] && echo "  [x] Domain Skills: 18 experts (typescript, react, python, rust, graphql, security, etc.)"
[ "$INSTALL_HOOKS" = true ] && echo "  [x] Hooks: session-start, pre-compact, stop, subagent-stop"
[ "$INSTALL_COMMANDS" = true ] && echo "  [x] Commands: /nonstop"
[ "$INSTALL_LIB" = true ] && echo "  [x] Utilities: state-manager, mcp-scanner, progress-dashboard,"
[ "$INSTALL_LIB" = true ] && echo "                 checkpoint-manager, quality-gate, agent-pool,"
[ "$INSTALL_LIB" = true ] && echo "                 metrics-collector, skill-selector"
echo ""
echo "NEW in v2.1:"
echo "  - Progress Dashboard: ASCII visualization of progress"
echo "  - Checkpoint System: Save/restore execution state"
echo "  - Quality Gates: Configurable checks between phases"
echo "  - Agent Pooling: Track and optimize agent usage"
echo "  - Metrics & Analytics: Timing, file changes, reports"
echo "  - Domain Skills Library: 18 expert skills organized by category"
echo "    Languages: TypeScript, React, React Native, Python, Rust"
echo "    Backend: API, GraphQL, Database, Messaging"
echo "    Infrastructure: DevOps, Security, Testing, Performance"
echo "    Design: System Architect, UI/UX, Web Design, Mobile Design"
echo ""
echo "Usage:"
echo "  1. Start Claude Code in your project"
echo "  2. Type: /nonstop <your task description>"
echo ""
echo "Utilities (all in .claude/lib/):"
echo "  .claude/lib/progress-dashboard.sh dashboard  - Show progress"
echo "  .claude/lib/checkpoint-manager.sh create     - Create checkpoint"
echo "  .claude/lib/quality-gate.sh run-phase        - Run quality gates"
echo "  .claude/lib/metrics-collector.sh report      - Generate report"
echo "  .claude/lib/skill-selector.sh recommend      - Recommend skills"
echo ""
echo "State saved to: $CACHE_DIR/"
echo ""
echo "PERFECTION IS THE ONLY ACCEPTABLE OUTCOME."
echo ""
