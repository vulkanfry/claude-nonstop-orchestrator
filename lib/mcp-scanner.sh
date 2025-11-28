#!/bin/bash
# NONSTOP v2.0 - MCP Scanner
# Scans installed MCPs and analyzes their capabilities

set -euo pipefail

# Configuration
HOME_DIR="${HOME:-/Users/$(whoami)}"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# MCP settings locations
SETTINGS_LOCATIONS=(
    "$HOME_DIR/.config/claude/settings.json"
    "$HOME_DIR/Library/Application Support/Claude/settings.json"
    "$HOME_DIR/.claude/settings.json"
    "$PROJECT_ROOT/.mcp.json"
    "$PROJECT_ROOT/.claude/mcp.json"
)

# Detect project type and return keywords
detect_project_keywords() {
    local keywords=""

    # Check package.json
    if [ -f "$PROJECT_ROOT/package.json" ]; then
        keywords="$keywords nodejs javascript"

        # Framework detection
        grep -q '"typescript"' "$PROJECT_ROOT/package.json" 2>/dev/null && keywords="$keywords typescript"
        grep -q '"react"' "$PROJECT_ROOT/package.json" 2>/dev/null && keywords="$keywords react frontend"
        grep -q '"react-native"' "$PROJECT_ROOT/package.json" 2>/dev/null && keywords="$keywords react-native mobile"
        grep -q '"next"' "$PROJECT_ROOT/package.json" 2>/dev/null && keywords="$keywords nextjs fullstack"
        grep -q '"vue"' "$PROJECT_ROOT/package.json" 2>/dev/null && keywords="$keywords vue frontend"
        grep -q '"express"' "$PROJECT_ROOT/package.json" 2>/dev/null && keywords="$keywords express api backend"
        grep -q '"fastify"' "$PROJECT_ROOT/package.json" 2>/dev/null && keywords="$keywords fastify api backend"
        grep -q '"prisma"' "$PROJECT_ROOT/package.json" 2>/dev/null && keywords="$keywords prisma database"
        grep -q '"mongoose"' "$PROJECT_ROOT/package.json" 2>/dev/null && keywords="$keywords mongodb database"
        grep -q '"@supabase"' "$PROJECT_ROOT/package.json" 2>/dev/null && keywords="$keywords supabase"
    fi

    # Other project types
    [ -f "$PROJECT_ROOT/Cargo.toml" ] && keywords="$keywords rust"
    [ -f "$PROJECT_ROOT/go.mod" ] && keywords="$keywords go golang"
    [ -f "$PROJECT_ROOT/pyproject.toml" ] || [ -f "$PROJECT_ROOT/requirements.txt" ] && keywords="$keywords python"
    [ -f "$PROJECT_ROOT/pubspec.yaml" ] && keywords="$keywords flutter dart mobile"
    [ -f "$PROJECT_ROOT/docker-compose.yml" ] && keywords="$keywords docker devops"
    [ -d "$PROJECT_ROOT/.github" ] && keywords="$keywords github ci"

    echo "$keywords" | xargs
}

# Scan installed MCPs
scan_installed_mcps() {
    local found_mcps=""

    for location in "${SETTINGS_LOCATIONS[@]}"; do
        if [ -f "$location" ]; then
            # Try to extract MCP servers using jq
            if command -v jq &>/dev/null; then
                local mcps=$(jq -r '.mcpServers // {} | keys[]' "$location" 2>/dev/null || echo "")
                if [ -n "$mcps" ]; then
                    found_mcps="$found_mcps $mcps"
                fi
            else
                # Fallback: grep-based extraction
                local mcps=$(grep -oE '"[a-zA-Z0-9_-]+"\s*:\s*\{[^}]*"command"' "$location" 2>/dev/null | grep -oE '^"[^"]+' | tr -d '"' || echo "")
                if [ -n "$mcps" ]; then
                    found_mcps="$found_mcps $mcps"
                fi
            fi
        fi
    done

    echo "$found_mcps" | xargs | tr ' ' '\n' | sort -u
}

# Get MCP tools (if available)
get_mcp_tools() {
    local mcp_name="$1"
    # This would require actually querying the MCP, which isn't possible from bash
    # Return placeholder for now
    echo "tools-not-queryable-from-bash"
}

# Output as JSON
output_json() {
    local keywords=$(detect_project_keywords)
    local mcps=$(scan_installed_mcps)

    local mcps_json="["
    local first=true
    for mcp in $mcps; do
        [ "$first" = true ] && first=false || mcps_json="$mcps_json,"
        mcps_json="$mcps_json\"$mcp\""
    done
    mcps_json="$mcps_json]"

    local keywords_json="["
    first=true
    for kw in $keywords; do
        [ "$first" = true ] && first=false || keywords_json="$keywords_json,"
        keywords_json="$keywords_json\"$kw\""
    done
    keywords_json="$keywords_json]"

    cat << EOF
{
  "project_root": "$PROJECT_ROOT",
  "project_keywords": $keywords_json,
  "installed_mcps": $mcps_json,
  "scan_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

# Output human-readable
output_text() {
    echo "=== MCP Scanner ==="
    echo ""
    echo "Project: $PROJECT_ROOT"
    echo ""

    local keywords=$(detect_project_keywords)
    echo "Detected Keywords: ${keywords:-none}"
    echo ""

    local mcps=$(scan_installed_mcps)
    if [ -n "$mcps" ]; then
        echo "Installed MCPs:"
        for mcp in $mcps; do
            echo "  - $mcp"
        done
    else
        echo "Installed MCPs: none detected"
    fi
    echo ""
    echo "=== End Scan ==="
}

# MCP relevance suggestions based on keywords
suggest_mcps() {
    local keywords="$1"
    local suggestions=""

    echo "$keywords" | grep -q "database\|prisma\|mongodb" && suggestions="$suggestions database-mcp"
    echo "$keywords" | grep -q "frontend\|react\|vue" && suggestions="$suggestions puppeteer"
    echo "$keywords" | grep -q "api\|backend" && suggestions="$suggestions postman-mcp"
    echo "$keywords" | grep -q "github\|ci" && suggestions="$suggestions github-mcp"
    echo "$keywords" | grep -q "docker\|devops" && suggestions="$suggestions docker-mcp"

    echo "$suggestions" | xargs
}

# Command dispatcher
case "${1:-text}" in
    json) output_json ;;
    text) output_text ;;
    keywords) detect_project_keywords ;;
    mcps) scan_installed_mcps ;;
    suggest) suggest_mcps "$(detect_project_keywords)" ;;
    *)
        echo "MCP Scanner v2.0"
        echo ""
        echo "Usage: mcp-scanner.sh [command]"
        echo ""
        echo "Commands:"
        echo "  json      Output as JSON"
        echo "  text      Output human-readable (default)"
        echo "  keywords  Show detected project keywords"
        echo "  mcps      List installed MCPs"
        echo "  suggest   Suggest MCPs based on project"
        ;;
esac
