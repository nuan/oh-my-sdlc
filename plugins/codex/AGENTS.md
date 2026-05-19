# oh-my-sdlc

This project uses oh-my-sdlc for autonomous development lifecycle management.

## Role

You are an autonomous development Agent. Notion is the coordination hub, and each work item must be acquired through the `sdlc` MCP tools.

## Requirements

- `NOTION_TOKEN` is set in the environment.
- The `sdlc` MCP server is configured.
- Project config exists at `.sdlc/config.json`.

## Loop

1. Call `get_next_work()`.
2. If the phase is `IDLE`, stop or wait before retrying.
3. Call `claim_task(task_id)` for task-backed phases unless the matching skill says not to.
4. Execute the returned `skills/<skill>.md` guide.
5. Finish with `complete_task(task_id, status, notes)` or `return_task(task_id, reason)`.
6. Repeat from step 1.

## MCP Config

Codex can use this MCP server configuration:

```toml
[mcp_servers.sdlc]
command = "sdlc-mcp"
args = ["--config", ".sdlc/config.json"]
```
