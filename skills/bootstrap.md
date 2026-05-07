# bootstrap.md — 新 Agent 接入流程

适用场景：你是第一次加入本项目的 Agent，需要了解项目背景后开始工作。

## 1. 环境检查

确认以下条件满足，否则无法工作：

- `NOTION_TOKEN` 环境变量已设置（`echo $NOTION_TOKEN` 不为空）
- sdlc MCP Server 已加载：尝试调用 `get_next_work()`，若报错则检查 MCP 配置

如果 MCP 未加载：
- Claude Code 用户：检查 `.claude/mcp.json`，重启会话后重试
- Gemini CLI 用户：检查 `.gemini/mcp.json`，重启会话后重试
- 其他工具：参考 `AGENTS.md` 中的 MCP Server 启动命令

## 2. 已有项目：读取知识库（不可跳过）

如果引导文件（CLAUDE.md / GEMINI.md / AGENTS.md）中标注了"这是已有项目"：

1. 调用 `get_project_knowledge()` 获取项目知识库全部条目
2. 阅读所有模块条目，建立项目功能地图：
   - 每个模块的关键文件路径
   - 技术栈和依赖
   - 功能描述
3. **此步骤不可跳过**——知识库是快速上手的唯一途径，跳过会导致重复实现或破坏已有功能

## 3. 主循环

完成上述检查后，进入主循环：

```
loop:
  result = get_next_work()

  if result.phase == "IDLE":
    # 当日配额耗尽或暂无工作，等待后重试
    等待若干分钟后重试
    continue

  if result.phase == "SPRINT_PLAN":
    # 纯脚本阶段，需 AI 补充 Sprint 目标摘要
    success = claim_task(result.task_id)
    if not success: continue
    bash scripts/sprint-plan.sh
    # 完成后写入 Sprint 目标（见下方说明）
    complete_task(result.task_id, "done", "<Sprint 目标摘要>")
    continue

  # DEVELOP / REFINE / DEPLOY / MONITOR 阶段
  success = claim_task(result.task_id)
  if not success: continue  # 被其他 Agent 抢占，重新查询

  # 前置条件检查（见各 skill 文件首部）
  # 执行对应 skill：skills/<result.skill>.md
  # 完成后调用 complete_task 或 return_task
```

## 4. SPRINT_PLAN 阶段：写入 Sprint 摘要

`scripts/sprint-plan.sh` 是纯确定性脚本，完成后 AI 需要额外写入 Sprint 说明：

1. 通过 Notion MCP 读取刚刚创建的 Sprint 页面
2. 生成并写入两个字段：
   - **目标**（Sprint 的核心交付价值，1-2 句话）
   - **开始说明**（本次选入的需求列表、优先级依据）
3. 调用 `complete_task(task_id, "done", "Sprint N 已激活，共选入 N 个需求：<需求标题列表>")`

## 5. 使用 return_task 退还任务

当任务无法执行时（环境问题、依赖缺失、需求不明确），立即调用：

```
return_task(task_id, "<问题类型>：<具体说明>")
```

退还是无损操作。任务退还次数达到阈值（默认 3 次）后自动变为 Blocked，需人工介入。
