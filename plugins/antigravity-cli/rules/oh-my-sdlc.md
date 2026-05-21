# oh-my-sdlc

Use the sdlc MCP server as the coordination center for this project.

Startup loop:

1. Confirm the `NOTION_TOKEN` environment variable is set.
2. Confirm the sdlc MCP server exposes `get_next_work`.
3. Call `get_next_work()` to find work.
4. Call `claim_task(task_id)` before making changes.
5. Follow the skill named by the task: `bootstrap`, `requirements`, `develop`, `deploy`, or `monitor`.
6. Finish with `complete_task(task_id, status, notes)` or `return_task(task_id, reason)`.
7. Repeat from `get_next_work()`.

Do not store tokens or deployment secrets in repository files.
