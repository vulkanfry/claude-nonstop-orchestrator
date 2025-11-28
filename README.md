# NONSTOP v2.1 - Claude Code Plugin

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║   I AM NONSTOP.                                                  ║
║                                                                  ║
║   I DO NOT STOP until the task is COMPLETE.                      ║
║   I DO NOT care about tokens or time.                            ║
║   I PLAN with ULTRATHINK before I execute.                       ║
║   I USE PARALLEL AGENTS for maximum efficiency.                  ║
║   I VERIFY until PERFECT.                                        ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Full Vibe Coded](https://img.shields.io/badge/Full%20Vibe-Coded%20%F0%9F%A4%99-blueviolet)](https://github.com/anthropics/claude-code)

**Unstoppable task execution with deep planning, parallel agents, and perfectionist verification.**

## What's New in v2.1

| Feature | Description |
|---------|-------------|
| **Progress Dashboard** | Real-time ASCII visualization of execution progress |
| **Checkpoint System** | Save/restore state snapshots for safe experimentation |
| **Quality Gates** | Configurable checks between execution phases |
| **Agent Pooling** | Track, cache, and optimize parallel agent usage |
| **Metrics & Analytics** | Timing, file changes, success rates, detailed reports |
| **Domain Skills Library** | 18 expert skills for TypeScript, React, Python, Rust, GraphQL, Security, etc. |
| **ULTRATHINK Planning** | 15+ sequential thinking iterations before any code |
| **Parallel Execution** | Multiple agents work on independent stories simultaneously |
| **Enhanced Recovery** | Full state recovery after context compaction |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  /nonstop "implement feature X"                                 │
└───────────────────────────┬─────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 0: PREPARATION                                           │
│  • Analyze task domain                                          │
│  • Detect project type → Recommend domain skills                │
│  • Run pre_execute quality gates                                │
│  • Create initial checkpoint                                    │
└───────────────────────────┬─────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 1: ULTRATHINK PLANNING                                   │
│  • Deep analysis (15+ thinking iterations)                      │
│  • Decompose: Task → Stories → Tasks → Subtasks                 │
│  • Identify parallelizable work                                 │
│  • Start metrics collection                                     │
└───────────────────────────┬─────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 2: PARALLEL EXECUTION                                    │
│  • Launch agents for independent Stories                        │
│  • Track agents in pool, cache results                          │
│  • Create checkpoints after each story                          │
│  • Run post_execute quality gates                               │
│  • Display progress dashboard                                   │
└───────────────────────────┬─────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 3: VERIFICATION LOOP                                     │
│  • Run pre_complete quality gates                               │
│  • Tests, lint, typecheck, code review                          │
│  • Fix all issues, loop until perfect                           │
│  • Generate metrics report                                      │
└─────────────────────────────────────────────────────────────────┘
```

## Installation

### Quick Install

```bash
cd /path/to/your/project
/path/to/nonstop-claude-plugin/install.sh
```

### What Gets Installed

```
your-project/
├── .claude/
│   ├── settings.json                    # Hooks configuration
│   ├── skills/
│   │   ├── nonstop-orchestrator/        # Main orchestrator
│   │   │   └── SKILL.md
│   │   └── domains/                     # Domain expert skills
│   │       ├── typescript-expert.md
│   │       ├── react-expert.md
│   │       ├── react-native-expert.md
│   │       ├── python-expert.md
│   │       ├── rust-expert.md
│   │       ├── api-backend-expert.md
│   │       ├── devops-expert.md
│   │       ├── ui-ux-expert.md
│   │       ├── mcp-builder-expert.md
│   │       ├── system-architect-expert.md
│   │       └── testing-expert.md
│   ├── hooks/
│   │   ├── session-start.sh             # Recovery detection
│   │   └── pre-compact.sh               # State backup
│   └── commands/
│       └── nonstop.md                   # /nonstop command
├── lib/
│   ├── state-manager.sh                 # State persistence
│   ├── mcp-scanner.sh                   # MCP discovery
│   ├── progress-dashboard.sh            # ASCII visualization
│   ├── checkpoint-manager.sh            # State snapshots
│   ├── quality-gate.sh                  # Quality checks
│   ├── agent-pool.sh                    # Agent management
│   ├── metrics-collector.sh             # Analytics
│   └── skill-selector.sh                # Domain detection
├── templates/
│   ├── execution-state-template.json
│   ├── story-template.json
│   └── skill-template.md
├── config/
│   └── default.json
└── .nonstop.json                        # Project config
```

## Usage

### Start NONSTOP Mode

```
/nonstop implement user authentication with OAuth
```

Or invoke directly:
```
Use skill: "nonstop-orchestrator"
```

## New Features

### Progress Dashboard

Real-time ASCII visualization:

```bash
lib/progress-dashboard.sh dashboard
```

Output:
```
╔══════════════════════════════════════════════════════════════════╗
║                    NONSTOP PROGRESS DASHBOARD                    ║
║  Task: Implement OAuth authentication                            ║
╚══════════════════════════════════════════════════════════════════╝

Stories: 5/7 completed | 2 running | 0 failed
[████████████████████░░░░░░░░░░░░░░░░░░░░] 71%
ETA: 12m 34s

┌────────┬────────────────────────────────┬────────────┐
│ Story  │ Title                          │ Status     │
├────────┼────────────────────────────────┼────────────┤
│ S1     │ Setup OAuth providers          │ ✓ complete │
│ S2     │ Create auth endpoints          │ ✓ complete │
│ S3     │ Implement token refresh        │ ⟳ running  │
└────────┴────────────────────────────────┴────────────┘
```

### Checkpoint System

Save and restore state snapshots:

```bash
lib/checkpoint-manager.sh create before-refactor
lib/checkpoint-manager.sh list
lib/checkpoint-manager.sh restore before-refactor
```

### Quality Gates

Configurable checks between phases:

```bash
lib/quality-gate.sh run-phase pre_complete
lib/quality-gate.sh check tests_pass
```

Built-in gates: `files_exist`, `tests_pass`, `lint_clean`, `no_type_errors`, `build_success`, `no_secrets`, `custom_script`

### Metrics & Analytics

```bash
lib/metrics-collector.sh start planning
lib/metrics-collector.sh end planning
lib/metrics-collector.sh report
```

### Domain Skills Library

18 expert skills organized by category:

**Languages & Frameworks:**
| Skill | Focus |
|-------|-------|
| `typescript-expert` | Type safety, generics, strict mode |
| `react-expert` | Hooks, performance, component patterns |
| `react-native-expert` | Mobile development, native modules |
| `python-expert` | Type hints, async, clean architecture |
| `rust-expert` | Ownership, lifetimes, memory safety |

**Backend & APIs:**
| Skill | Focus |
|-------|-------|
| `api-backend-expert` | REST/GraphQL, authentication, security |
| `graphql-expert` | Schema design, DataLoader, performance |
| `database-expert` | PostgreSQL, MongoDB, Redis, optimization |
| `messaging-expert` | Kafka, RabbitMQ, event-driven architecture |

**Infrastructure & Quality:**
| Skill | Focus |
|-------|-------|
| `devops-expert` | Docker, Kubernetes, CI/CD pipelines |
| `security-expert` | OWASP, authentication, encryption |
| `testing-expert` | TDD, unit/integration/E2E testing |
| `performance-expert` | Profiling, caching, optimization |

**Design & Architecture:**
| Skill | Focus |
|-------|-------|
| `system-architect-expert` | Distributed systems, scalability |
| `ui-ux-expert` | Accessibility, design systems |
| `web-design-expert` | Responsive design, typography, CSS |
| `mobile-design-expert` | Touch targets, gestures, mobile UX |

**Tools & Protocols:**
| Skill | Focus |
|-------|-------|
| `mcp-builder-expert` | Model Context Protocol servers |

```bash
lib/skill-selector.sh detect      # Detect project type
lib/skill-selector.sh recommend   # Get skill recommendations
lib/skill-selector.sh list        # List all available skills
lib/skill-selector.sh info <name> # Show skill details
```

## Configuration

### .nonstop.json

```json
{
  "version": "2.1.0",
  "quality_gates": {
    "enabled": true,
    "gates": {
      "pre_execute": { "checks": ["files_exist"] },
      "pre_complete": { "checks": ["no_type_errors", "tests_pass"] }
    }
  },
  "checkpoints": { "auto_checkpoint": true },
  "metrics": { "enabled": true, "generate_report": true },
  "domain_skills": { "enabled": true, "auto_detect": true }
}
```

## Recovery

When context compacts:
1. `pre-compact.sh` creates backup
2. On resume, `session-start.sh` detects active state
3. Just re-invoke: `skill: "nonstop-orchestrator"`
4. Skill auto-resumes from last checkpoint

## Inspired By

- [awesome-claude-skills](https://github.com/ComposioHQ/awesome-claude-skills)
- [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code)
- [awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)
- [LangGPT](https://github.com/langgptai/LangGPT)

## Principles

```
I DO NOT STOP until the task is COMPLETE.
I DO NOT care about tokens or time.
I PLAN with ULTRATHINK.
I EXECUTE with PARALLEL AGENTS.
I VERIFY until PERFECT.
```

## License

MIT

---

**PERFECTION IS THE ONLY ACCEPTABLE OUTCOME.**
