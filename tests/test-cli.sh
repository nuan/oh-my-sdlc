#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

mkdir -p "$TMPDIR_TEST/.gemini"
cat > "$TMPDIR_TEST/.gemini/settings.json" <<'JSON'
{
  "ui": {
    "theme": "GitHub"
  },
  "mcpServers": {
    "existing": {
      "command": "existing-mcp",
      "args": ["--flag"]
    }
  }
}
JSON

SDLC_SKIP_ANTIGRAVITY_PLUGIN_INSTALL=1 node "$ROOT/bin/sdlc.js" install all --project "$TMPDIR_TEST" >/tmp/oh-my-sdlc-cli-test.out

test -f "$TMPDIR_TEST/AGENTS.md"
test -f "$TMPDIR_TEST/CLAUDE.md"
test -f "$TMPDIR_TEST/GEMINI.md"
test -d "$TMPDIR_TEST/scripts"
test -d "$TMPDIR_TEST/mcp"
test -d "$TMPDIR_TEST/skills"
test -f "$TMPDIR_TEST/.claude/mcp.json"
test -f "$TMPDIR_TEST/.gemini/settings.json"
test -f "$TMPDIR_TEST/.gemini/extensions/oh-my-sdlc/gemini-extension.json"
test -f "$TMPDIR_TEST/plugins/antigravity-cli/plugin.json"
test -f "$TMPDIR_TEST/plugins/antigravity-cli/mcp_config.json"
test -f "$TMPDIR_TEST/.codex/config.toml"

CLAUDE_COMMAND="$(jq -r '.mcpServers.sdlc.command' "$TMPDIR_TEST/.claude/mcp.json")"
GEMINI_COMMAND="$(jq -r '.mcpServers.sdlc.command' "$TMPDIR_TEST/.gemini/settings.json")"
ANTIGRAVITY_COMMAND="$(jq -r '.mcpServers.sdlc.command' "$TMPDIR_TEST/plugins/antigravity-cli/mcp_config.json")"
ANTIGRAVITY_CONFIG="$(jq -r '.mcpServers.sdlc.args[1]' "$TMPDIR_TEST/plugins/antigravity-cli/mcp_config.json")"
ANTIGRAVITY_CWD="$(jq -r '.mcpServers.sdlc.cwd' "$TMPDIR_TEST/plugins/antigravity-cli/mcp_config.json")"
EXISTING_GEMINI_COMMAND="$(jq -r '.mcpServers.existing.command' "$TMPDIR_TEST/.gemini/settings.json")"
GEMINI_THEME="$(jq -r '.ui.theme' "$TMPDIR_TEST/.gemini/settings.json")"

test "$CLAUDE_COMMAND" = "sdlc-mcp"
test "$GEMINI_COMMAND" = "sdlc-mcp"
test "$ANTIGRAVITY_COMMAND" = "sdlc-mcp"
test "$ANTIGRAVITY_CONFIG" = "$TMPDIR_TEST/.sdlc/config.json"
test "$ANTIGRAVITY_CWD" = "$TMPDIR_TEST"
test "$EXISTING_GEMINI_COMMAND" = "existing-mcp"
test "$GEMINI_THEME" = "GitHub"
grep -q '\[mcp_servers.sdlc\]' "$TMPDIR_TEST/.codex/config.toml"

echo "CLI install test passed"
