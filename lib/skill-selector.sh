#!/bin/bash
# NONSTOP v2.1 - Skill Selector
# Auto-detect project type and recommend domain skills

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$PLUGIN_DIR/skills/domains"

# ════════════════════════════════════════════════════════════════════
# PROJECT TYPE DETECTION
# ════════════════════════════════════════════════════════════════════

detect_project_type() {
    local types=""

    # TypeScript
    if [ -f "$PROJECT_ROOT/tsconfig.json" ]; then
        types="$types typescript"
    fi

    # JavaScript/Node
    if [ -f "$PROJECT_ROOT/package.json" ]; then
        types="$types javascript nodejs"

        # React
        if grep -q '"react"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
            types="$types react frontend"
        fi

        # React Native
        if grep -q '"react-native"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
            types="$types react-native mobile"
        fi

        # Next.js
        if grep -q '"next"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
            types="$types nextjs fullstack"
        fi

        # Vue
        if grep -q '"vue"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
            types="$types vue frontend"
        fi

        # Express/Backend
        if grep -q '"express"\|"fastify"\|"koa"\|"hapi"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
            types="$types backend api"
        fi

        # NestJS
        if grep -q '"@nestjs"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
            types="$types nestjs backend api"
        fi
    fi

    # Python
    if [ -f "$PROJECT_ROOT/pyproject.toml" ] || [ -f "$PROJECT_ROOT/requirements.txt" ] || [ -f "$PROJECT_ROOT/setup.py" ]; then
        types="$types python"

        # Django
        if grep -q "django" "$PROJECT_ROOT/requirements.txt" 2>/dev/null || \
           grep -q "django" "$PROJECT_ROOT/pyproject.toml" 2>/dev/null; then
            types="$types django backend"
        fi

        # FastAPI
        if grep -q "fastapi" "$PROJECT_ROOT/requirements.txt" 2>/dev/null || \
           grep -q "fastapi" "$PROJECT_ROOT/pyproject.toml" 2>/dev/null; then
            types="$types fastapi backend api"
        fi

        # Flask
        if grep -q "flask" "$PROJECT_ROOT/requirements.txt" 2>/dev/null; then
            types="$types flask backend"
        fi
    fi

    # Rust
    if [ -f "$PROJECT_ROOT/Cargo.toml" ]; then
        types="$types rust"
    fi

    # Go
    if [ -f "$PROJECT_ROOT/go.mod" ]; then
        types="$types go golang"
    fi

    # DevOps
    if [ -f "$PROJECT_ROOT/Dockerfile" ] || [ -f "$PROJECT_ROOT/docker-compose.yml" ]; then
        types="$types docker devops"
    fi

    if [ -d "$PROJECT_ROOT/.github/workflows" ]; then
        types="$types github-actions ci devops"
    fi

    if [ -f "$PROJECT_ROOT/terraform.tf" ] || [ -d "$PROJECT_ROOT/terraform" ]; then
        types="$types terraform infrastructure devops"
    fi

    if [ -f "$PROJECT_ROOT/k8s" ] || [ -f "$PROJECT_ROOT/kubernetes" ]; then
        types="$types kubernetes devops"
    fi

    # GraphQL
    if grep -rq "graphql\|apollo\|@Query\|@Mutation" "$PROJECT_ROOT/package.json" "$PROJECT_ROOT/src" 2>/dev/null; then
        types="$types graphql"
    fi

    # Database
    if grep -q '"prisma"\|"typeorm"\|"sequelize"\|"mongoose"\|"pg"\|"mysql"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
        types="$types database"
    fi
    if [ -f "$PROJECT_ROOT/prisma/schema.prisma" ]; then
        types="$types database"
    fi
    if grep -q "sqlalchemy\|psycopg\|pymongo\|redis" "$PROJECT_ROOT/requirements.txt" 2>/dev/null; then
        types="$types database"
    fi

    # Messaging/Queues
    if grep -q '"kafkajs"\|"amqplib"\|"bull"\|"ioredis"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
        types="$types messaging"
    fi
    if grep -q "kafka\|pika\|celery\|redis" "$PROJECT_ROOT/requirements.txt" 2>/dev/null; then
        types="$types messaging"
    fi

    # Testing frameworks
    if grep -q '"jest"\|"vitest"\|"mocha"\|"playwright"\|"cypress"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
        types="$types testing"
    fi
    if grep -q "pytest\|unittest" "$PROJECT_ROOT/requirements.txt" 2>/dev/null; then
        types="$types testing"
    fi

    # Mobile (additional patterns)
    if [ -d "$PROJECT_ROOT/ios" ] || [ -d "$PROJECT_ROOT/android" ]; then
        types="$types mobile"
    fi
    if [ -f "$PROJECT_ROOT/app.json" ] && grep -q "expo" "$PROJECT_ROOT/package.json" 2>/dev/null; then
        types="$types mobile react-native"
    fi

    # Web design indicators
    if grep -q '"tailwindcss"\|"styled-components"\|"emotion"\|"sass"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
        types="$types web-design frontend"
    fi
    if [ -d "$PROJECT_ROOT/styles" ] || [ -d "$PROJECT_ROOT/css" ]; then
        types="$types web-design"
    fi

    # Output unique types
    echo "$types" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs
}

# ════════════════════════════════════════════════════════════════════
# SKILL RECOMMENDATION
# ════════════════════════════════════════════════════════════════════

recommend_skills() {
    local project_types=$(detect_project_type)
    local recommended=""

    # Map project types to skills
    for type in $project_types; do
        case "$type" in
            typescript)
                recommended="$recommended typescript-expert"
                ;;
            react)
                recommended="$recommended react-expert"
                ;;
            react-native|mobile)
                recommended="$recommended react-native-expert mobile-design-expert"
                ;;
            frontend|web-design)
                recommended="$recommended web-design-expert ui-ux-expert"
                ;;
            python|django|fastapi|flask)
                recommended="$recommended python-expert"
                ;;
            rust)
                recommended="$recommended rust-expert"
                ;;
            backend|api|nestjs)
                recommended="$recommended api-backend-expert"
                ;;
            devops|docker|kubernetes|terraform|ci)
                recommended="$recommended devops-expert"
                ;;
            graphql)
                recommended="$recommended graphql-expert"
                ;;
            database)
                recommended="$recommended database-expert"
                ;;
            messaging)
                recommended="$recommended messaging-expert"
                ;;
            testing)
                recommended="$recommended testing-expert"
                ;;
        esac
    done

    # Always recommend system-architect for large projects
    local file_count=$(find "$PROJECT_ROOT" -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" 2>/dev/null | wc -l)
    if [ "$file_count" -gt 50 ]; then
        recommended="$recommended system-architect-expert"
    fi

    # Always recommend security for backend projects
    if echo "$project_types" | grep -qE "backend|api|django|fastapi"; then
        recommended="$recommended security-expert"
    fi

    # Output unique recommendations
    echo "$recommended" | tr ' ' '\n' | sort -u | grep -v '^$' | tr '\n' ' ' | xargs
}

# ════════════════════════════════════════════════════════════════════
# SKILL LISTING
# ════════════════════════════════════════════════════════════════════

list_skills() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "                   AVAILABLE DOMAIN SKILLS"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    if [ ! -d "$SKILLS_DIR" ]; then
        echo "Skills directory not found: $SKILLS_DIR"
        echo "Run install.sh to set up domain skills."
        return 1
    fi

    for skill_file in "$SKILLS_DIR"/*.md; do
        [ -f "$skill_file" ] || continue

        local name=$(basename "$skill_file" .md)
        local description=$(grep -m1 "^description:" "$skill_file" 2>/dev/null | sed 's/^description: //' | head -c 60)

        printf "  %-25s %s...\n" "$name" "$description"
    done

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
}

# ════════════════════════════════════════════════════════════════════
# SKILL INFO
# ════════════════════════════════════════════════════════════════════

show_skill_info() {
    local skill_name="$1"
    local skill_file="$SKILLS_DIR/${skill_name}.md"

    if [ ! -f "$skill_file" ]; then
        echo "Skill not found: $skill_name"
        echo "Use 'list' to see available skills"
        return 1
    fi

    echo "═══════════════════════════════════════════════════════════════"
    echo "  SKILL: $skill_name"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Extract frontmatter
    local in_frontmatter=false
    while IFS= read -r line; do
        if [ "$line" = "---" ]; then
            if [ "$in_frontmatter" = false ]; then
                in_frontmatter=true
                continue
            else
                break
            fi
        fi
        if [ "$in_frontmatter" = true ]; then
            echo "  $line"
        fi
    done < "$skill_file"

    echo ""

    # Extract first section (Core Principles usually)
    sed -n '/^## CORE PRINCIPLES/,/^## /p' "$skill_file" | head -20

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Full skill: $skill_file"
    echo "═══════════════════════════════════════════════════════════════"
}

# ════════════════════════════════════════════════════════════════════
# FULL DETECTION OUTPUT
# ════════════════════════════════════════════════════════════════════

full_detect() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "                   PROJECT ANALYSIS"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Project: $PROJECT_ROOT"
    echo ""

    local types=$(detect_project_type)
    echo "Detected Types: ${types:-none}"
    echo ""

    local skills=$(recommend_skills)
    echo "Recommended Skills:"
    if [ -n "$skills" ]; then
        for skill in $skills; do
            local skill_file="$SKILLS_DIR/${skill}.md"
            local exists="✓"
            [ ! -f "$skill_file" ] && exists="✗ (not installed)"
            echo "  - $skill $exists"
        done
    else
        echo "  No specific recommendations"
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
}

# ════════════════════════════════════════════════════════════════════
# COMMAND DISPATCHER
# ════════════════════════════════════════════════════════════════════

case "${1:-help}" in
    detect)
        detect_project_type
        ;;
    recommend)
        recommend_skills
        ;;
    list|ls)
        list_skills
        ;;
    info)
        if [ -z "${2:-}" ]; then
            echo "Usage: skill-selector.sh info <skill_name>"
            exit 1
        fi
        show_skill_info "$2"
        ;;
    full)
        full_detect
        ;;
    help|*)
        echo "NONSTOP Skill Selector v2.1"
        echo ""
        echo "Usage: skill-selector.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  detect       Detect project type"
        echo "  recommend    Recommend skills for project"
        echo "  list         List available domain skills"
        echo "  info <name>  Show skill details"
        echo "  full         Full project analysis"
        echo "  help         This help message"
        echo ""
        echo "Examples:"
        echo "  skill-selector.sh detect"
        echo "  skill-selector.sh recommend"
        echo "  skill-selector.sh info typescript-expert"
        ;;
esac
