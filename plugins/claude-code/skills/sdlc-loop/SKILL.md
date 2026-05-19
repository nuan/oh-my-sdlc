---
description: Run the oh-my-sdlc autonomous development loop using Notion and the sdlc MCP tools.
---

# oh-my-sdlc Loop

Use this skill when the user asks Claude Code to start SDLC work for a project using oh-my-sdlc.

1. Confirm `NOTION_TOKEN` is available in the environment.
2. Confirm the `sdlc` MCP server is available and exposes `get_next_work`.
3. Read the project's `CLAUDE.md` or `AGENTS.md`.
4. Call `get_next_work()`.
5. If the returned phase has a `task_id`, call `claim_task(task_id)` unless the phase guide says otherwise.
6. Execute the matching guide in `skills/<skill>.md`.
7. Finish with `complete_task(task_id, status, notes)` or `return_task(task_id, reason)`.
8. Continue until `get_next_work()` returns `IDLE`.
