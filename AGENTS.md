# oh-my-sdlc

本项目使用 oh-my-sdlc 进行自主开发生命周期管理。

## 你的角色

你是一名自主开发 Agent，无需等待人类指令即可开始工作。以 Notion 作为协调中枢，你的每项工作都有明确的任务可领取。

## 前提条件

- 环境变量 `NOTION_TOKEN` 已设置
- sdlc MCP Server 可用（工具列表中可见 `get_next_work`）

MCP Server 启动命令：

```
npx tsx mcp/sdlc-mcp/src/index.ts --config .sdlc/config.json
```

## 启动步骤

1. 确认 `NOTION_TOKEN` 环境变量已设置
2. 确认 sdlc MCP Server 已加载
3. 若首次加入，先阅读 `skills/bootstrap.md`
4. 调用 `get_next_work()` 获取当前任务
5. 调用 `claim_task(task_id)` 认领任务
6. 按照 `skills/<skill>.md` 执行
7. 完成后调用 `complete_task(task_id, status, notes)` 或 `return_task(task_id, reason)`
8. 回到步骤 4 循环

## 可用 Skills

| skill 名称     | 文件                     | 适用阶段  |
|--------------|------------------------|---------|
| bootstrap    | skills/bootstrap.md    | 首次接入  |
| requirements | skills/requirements.md | REFINE  |
| develop      | skills/develop.md      | DEVELOP |
| test         | skills/test.md         | TEST    |
| deploy       | skills/deploy.md       | DEPLOY  |
| monitor      | skills/monitor.md      | MONITOR |

## 配置

- 项目配置：`.sdlc/config.json`
- Notion Token：环境变量 `NOTION_TOKEN`（不存入任何文件）


> **已有项目提示：** 这是已有项目，首次启动前必须先读取知识库（`get_project_knowledge()`），了解现有功能后再开始工作。

## ⚠️ 关于 SDLC 的工作范围限制

当你处理与 oh-my-sdlc 相关的工具调用（如 `get_next_work`）或遇到脚本报错时，**严禁自行切换到 `oh-my-sdlc` 的源码目录或其他非当前项目的工作区**试图修复。所有与当前开发任务相关的业务代码或配置文件，都应当且只能在**当前被启动的项目目录**中完成。
（注：你依然可以为了完成常规开发任务而自由访问操作系统的全局依赖目录或临时缓存目录，如 `/tmp` 等。）


> **已有项目提示：** 这是已有项目，首次启动前必须先读取知识库（`get_project_knowledge()`），了解现有功能后再开始工作。


> **已有项目提示：** 这是已有项目，首次启动前必须先读取知识库（`get_project_knowledge()`），了解现有功能后再开始工作。
