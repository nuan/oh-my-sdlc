# oh-my-sdlc 设计文档

**日期：** 2026-05-03
**状态：** 草稿

---

## 概述

`oh-my-sdlc` 是一个跨工具兼容的插件，支持 Claude Code、Gemini CLI 和 Codex，实现完全自主的闭环软件开发生命周期管理。以 Notion（通过 MCP）作为人类、AI Agent 和项目状态之间的协调中枢。

**核心原则：脚本决定"做什么"，AI 决定"怎么做"。**

---

## 目标

- 任何安装了插件的 AI Agent（CC / Gemini CLI / Codex）可立即加入在途项目并开始贡献
- 完整 SDLC 闭环自主运行：需求 → Sprint 规划 → 任务拆分 → 开发 → 测试 → 部署 → 监控 → 需求
- 人类只需：提交需求、查看项目进度
- 所有技术决策（架构、方案、可行性）由 AI 自主判断
- 固定 Sprint 节奏，确保可预期的上线频率
- 禁止 Sprint 中途插入任务——需求持续积累进 Backlog，只在 Sprint 边界进入开发
- 每个任务完成后输出简洁结果说明到 Notion，Sprint 开始和结束时同样记录摘要
- 每日任务配额控制，防止过度消耗 token；配额耗尽后停止工作，等待次日恢复
- 支持已有项目接入：init 时扫描存量代码，将已有功能描述写入 Notion 知识库
- 新 Agent 加入已有项目时先熟悉知识库，再开始领取任务
- 部署所需的服务器信息在 init 阶段提供，非敏感信息写入配置，敏感信息只走环境变量

---

## 非目标

- 不替代现有 CI/CD 流水线（只负责触发）
- 不管理基础设施资源
- 不处理账单、法律或合规相关工作流

---

## 架构

### 插件目录结构

```
oh-my-sdlc/
├── CLAUDE.md                    # Claude Code 引导文件
├── GEMINI.md                    # Gemini CLI 引导文件
├── AGENTS.md                    # Codex 及其他工具引导文件
├── skills/
│   ├── bootstrap.md             # 新 Agent 接入流程说明
│   ├── requirements.md          # 需求精炼（Inbox → Ready）
│   ├── develop.md               # 认领任务 → 开发 → 测试 → PR
│   ├── deploy.md                # 按项目配置执行部署
│   └── monitor.md               # 健康检查 → 发现问题 → 写入需求库
├── scripts/
│   ├── init.sh                  # 人工一次性初始化：创建 Notion 数据库、写入配置
│   ├── get-next-work.sh         # 查询 Notion → 返回 { 阶段, 任务ID, skill }
│   ├── claim-task.sh            # 乐观锁：写入 Agent 指纹，验证是否抢占成功
│   ├── complete-task.sh         # 标记完成/失败，触发下游系统任务
│   ├── return-task.sh           # 退还无法完成的任务，状态回 Todo 或升级 Blocked
│   ├── sprint-plan.sh           # 需求评分，创建任务，激活 Sprint
│   └── monitor-check.sh         # 执行健康检查，写入 findings
└── mcp/
    └── sdlc-mcp/                # 伴生 MCP Server，将脚本封装为 MCP 工具
        └── index.ts
```

### 职责划分

| 层级 | 职责 |
|---|---|
| 脚本 | 所有状态判断、Notion 读写、调度逻辑 |
| MCP Server | 将脚本封装为 Agent 可调用的 MCP 工具（薄封装，不含业务逻辑） |
| Skills（Markdown） | 指导 Agent 在每个阶段如何完成创造性工作 |
| 引导文件 | Agent 入口：告知配置位置和启动步骤 |

---

## Notion 数据库结构

六张数据库，通过 Notion Relation 互相关联。

### 项目知识库（Project Knowledge DB）

| 字段 | 类型 | 取值 |
|---|---|---|
| 模块名称 | 文本 | |
| 功能描述 | 文本 | 简洁说明该模块做什么（2-5 句话） |
| 关键文件 | 文本 | 主要入口文件路径 |
| 技术栈 | 文本 | 使用的语言、框架、依赖 |
| 类型 | 单选 | feature \| module \| infra \| tech-stack |
| 最后更新 | 日期 | |

知识库在 init 时由 AI 扫描代码生成初始内容，此后每次 DEVELOP 任务完成后若涉及新功能则自动更新对应条目。新 Agent 接入时必须先读取知识库再开始工作。

### 需求库（Requirements DB）

| 字段 | 类型 | 取值 |
|---|---|---|
| 标题 | 文本 | |
| 状态 | 单选 | Inbox → Refined → Ready → In Sprint → Done |
| 优先级 | 单选 | P0 / P1 / P2 / P3 |
| 来源 | 单选 | Human \| Monitor |
| Sprint | 关联 | → Sprint 表 |
| 创建时间 | 日期 | |

### Sprint 表（Sprint DB）

| 字段 | 类型 | 取值 |
|---|---|---|
| 名称 | 文本 | 如 Sprint-007 |
| 状态 | 单选 | Planning → Active → Completed |
| 开始日期 | 日期 | |
| 结束日期 | 日期 | |
| 目标 | 文本 | Sprint 规划阶段由 AI 自动生成 |
| 开始说明 | 文本 | Sprint 激活时写入：选入的需求列表和优先级依据 |
| 结束说明 | 文本 | Sprint 完成时写入：完成情况、未完成项、遗留问题 |
| 需求 | 关联 | → 需求库 |

### 任务表（Task DB）

| 字段 | 类型 | 取值 |
|---|---|---|
| 标题 | 文本 | |
| 状态 | 单选 | Todo → Claiming → In Progress → Review → Done \| Failed \| **Blocked** |
| 类型 | 单选 | Dev \| Test \| Deploy \| Monitor \| SprintPlan |
| 认领人 | 文本 | `hostname-PID-timestamp`（Agent 指纹） |
| 结果摘要 | 文本 | AI 完成任务后写入的简洁说明（做了什么、结果如何、有无遗留） |
| 退还原因 | 文本 | Agent 退还任务时写入的原因（如：缺少 DEPLOY_SSH_KEY_PATH 环境变量） |
| 退还次数 | 数字 | 累计被退还的次数，超过阈值自动变为 Blocked |
| 需求 | 关联 | → 需求库 |
| Sprint | 关联 | → Sprint 表 |

### 部署记录（Deployment DB）

| 字段 | 类型 | 取值 |
|---|---|---|
| 版本 | 文本 | |
| 状态 | 单选 | Triggered → Success \| Failed |
| 环境 | 单选 | staging \| production |
| Sprint | 关联 | → Sprint 表 |
| 时间 | 日期 | |
| 备注 | 文本 | |

### 监控日志（Monitor Log DB）

| 字段 | 类型 | 取值 |
|---|---|---|
| 时间 | 日期 | |
| 类型 | 单选 | heartbeat \| finding |
| 来源 | 文本 | 配置的检查项名称 |
| 发现内容 | 文本 | AI 分析结果 |
| 状态 | 单选 | New → Processing → Done |
| 需求 | 关联 | → 需求库 |

`heartbeat` 记录（每个项目一条）存储最近一次监控运行的时间戳和认领 Agent 的指纹，用于 `monitor-check.sh` 的分布式锁。

---

## 工作流循环

每个 Agent 启动后执行同一入口循环，由 `get-next-work.sh` 按优先级决定当前任务：

```
Agent 启动
    │
    ▼
get-next-work.sh（按优先级顺序检查）
    │
    ├─ Active Sprint 有 Todo 任务？          → DEVELOP
    ├─ 有 SprintPlan 系统任务待处理？        → SPRINT_PLAN
    ├─ Sprint Active 且已到结束日期？        → DEPLOY
    ├─ 需求库有 Inbox 条目？                 → REFINE
    ├─ 监控检查窗口已到？                    → MONITOR
    └─ 无事可做？                            → IDLE（等待 N 分钟后重试）
    │
    ▼
claim-task.sh（IDLE 以外均先抢占）
    │
    ▼
执行前置条件检查（环境变量、权限、依赖）
    │
    ├─ 条件不满足 → return-task.sh（退还，写入原因）→ 循环
    │
    ▼
执行对应 skill（AI 完成创造性工作）
    │
    ▼
complete-task.sh 或 return-task.sh（执行中发现无法继续）
    │
    └─ 循环
```

### 并发任务抢占（乐观锁）

Notion API 无事务支持，通过 `Claiming` 中间状态实现并发安全：

```
1. 写入：Task.状态 = "Claiming"，Task.认领人 = "hostname-PID-timestamp"
2. 等待 500ms
3. 读回 Task.认领人
4. 仍是自己的指纹 → 设状态 = "In Progress"（抢占成功）
5. 指纹不同 → 查找下一个可用任务（抢占失败，重试）

过期抢占恢复：
  任务处于 "Claiming" 超过 5 分钟 → get-next-work.sh 将其视为 Todo 重新放出
```

### Sprint 生命周期

```
sprint-plan.sh 触发条件：
  - 当前 Sprint 状态变为 Completed，或
  - 当前时间 >= 当前 Sprint 结束日期（以先到者为准）

sprint-plan.sh 执行步骤（纯脚本，无 AI）：
  1. 检查 Ready 需求数量是否 >= 1；若为零则退出，不创建 Sprint
     （get-next-work.sh 在下次循环重试；Agent 优先执行 REFINE）
  2. 按优先级分数排序 Ready 需求（P0=40，P1=30，P2=20，P3=10）
  3. 按配置的 Sprint 容量（任务数）截取前 N 条
  4. 创建新 Sprint 记录（开始时间 = 当前时间，结束时间 = 当前时间 + duration_days）
  5. 批量创建任务记录（类型：Dev），关联 Sprint 和需求
  6. Sprint 状态：Planning → Active
  7. 已选需求状态：Ready → In Sprint
```

### 任务前置条件检查

每个 skill 文件开头声明本类型任务所需的前置条件，Agent 认领任务后、开始执行前必须检查：

| 任务类型 | 必须检查的前置条件 |
|---|---|
| Deploy | `DEPLOY_TOKEN` 或 `DEPLOY_SSH_KEY_PATH` 环境变量存在且非空 |
| Monitor | 配置的 checks URL 可访问（简单 ping） |
| Dev | 代码库可读写、能运行测试命令 |
| SprintPlan | Notion 连接正常、有 Ready 状态需求 |

检查失败时立即调用 `return_task()`，**不尝试执行任务**，原因中注明缺少的具体条件（如 `缺少环境变量 DEPLOY_SSH_KEY_PATH`），方便人类快速定位问题。

**Sprint 中途不接受任务插入。** 需求随时进入 Backlog，只在 Sprint 边界进入开发。

### 需求精炼（持续进行）

任何空闲 Agent 均可认领 REFINE 任务：
- 认领一条 Inbox 需求
- AI 读取内容，补充验收标准、估算复杂度、打优先级分
- 人类可随时在 Notion 中覆盖优先级
- 状态流转：Inbox → Refined → Ready

### 监控检查（定时执行）

```
monitor-check.sh 执行流程：
  1. 读取监控日志库中的 heartbeat 记录，检查上次执行时间
  2. 若 上次执行时间 + interval_hours > 当前时间 → 退出（已有 Agent 处理）
  3. 写入 heartbeat：更新时间戳和 Agent 指纹（乐观锁）
  4. 等待 1 秒，验证指纹仍是自己的
  5. 按配置执行所有检查项（HTTP / 自定义脚本）
  6. 将 findings 写入监控日志库
  7. 每个问题 → 在需求库创建一条 Inbox 需求（来源：Monitor）
```

---

## 脚本设计

所有脚本仅依赖 `curl` 和 `jq`，无其他运行时依赖，确保跨环境可用。

### `.sdlc/config.json`（由 init.sh 生成，提交到代码库）

```json
{
  "databases": {
    "requirements": "NOTION_DB_ID",
    "sprints": "NOTION_DB_ID",
    "tasks": "NOTION_DB_ID",
    "deployments": "NOTION_DB_ID",
    "monitor_logs": "NOTION_DB_ID"
  },
  "sprint": {
    "duration_days": 14,
    "capacity": 10
  },
  "deploy": {
    "method": "github-actions",
    "trigger": "workflow_dispatch"
  },
  "monitor": {
    "interval_hours": 6,
    "checks": [
      { "type": "http", "url": "https://yourapp.com/health", "expect_status": 200 },
      { "type": "script", "path": "./scripts/custom-health.sh" }
    ]
  },
  "quota": {
    "daily_task_limit": 10,
    "reset_hour_utc": 0
  }
}
```

Notion Token 通过环境变量 `NOTION_TOKEN` 读取，**不存入任何文件**。

### init.sh（人工执行一次）

支持两种模式，交互时选择：

**模式 A：全新项目**
```
交互式输入：
  - Notion Token（写入 shell profile 作为 NOTION_TOKEN，不写入文件）
  - 项目名称、Sprint 周期（天数）、Sprint 容量（任务数）
  - 部署方式（github-actions / script / manual）
  - 部署服务器信息（见下方「部署信息收集」）

执行操作：
  - 调用 Notion API 创建六张数据库
  - 在监控日志库创建 heartbeat 记录
  - 生成 .sdlc/config.json（可提交，不含敏感信息）
  - 生成 CLAUDE.md / GEMINI.md / AGENTS.md
  - 按工具写入 MCP 配置文件
  - 创建第一个 Sprint 记录（状态：Planning）
```

**模式 B：已有项目接入**
```
在模式 A 的基础上，额外执行：
  - AI 扫描现有代码库，按模块生成功能描述
  - 将描述批量写入项目知识库（Project Knowledge DB）
  - 在 CLAUDE.md / GEMINI.md / AGENTS.md 中标注：
    "这是已有项目，首次启动前必须先读取知识库"
  - 扫描结果输出摘要供人类审阅，人类可在 Notion 中补充或修正
```

**部署信息收集（两种模式均执行）**
```
非敏感信息 → 写入 .sdlc/config.json：
  - 服务器地址 / 域名
  - 部署环境名（staging / production）
  - 云服务商和区域（如 AWS ap-east-1）
  - CI/CD 流水线名称或 workflow 文件路径

敏感信息 → 只写入 shell profile 作为环境变量，绝不进文件或 Notion：
  - SSH 密钥路径（DEPLOY_SSH_KEY_PATH）
  - 云服务 Access Key（AWS_ACCESS_KEY_ID 等）
  - 部署用密码或 Token（DEPLOY_TOKEN）

init.sh 输出提示：列出所有需要设置的环境变量名称，
  供用户自行配置（脚本不代替用户写入这些值）
```

### get-next-work.sh

返回 JSON：
```json
{ "phase": "DEVELOP", "task_id": "xxx", "task_title": "...", "skill": "develop" }
```

### claim-task.sh `<task_id>`

返回退出码 0（抢占成功）或 1（被抢，查找下一个任务）。

### complete-task.sh `<task_id> <done|failed> [备注]`

更新任务状态。若当前 Sprint 所有任务均为 Done/Failed，则将 Sprint 状态设为 Completed，并在任务表中创建一条 SprintPlan 系统任务（状态：Todo），等待任意 Agent 在下次循环中认领并执行 `sprint-plan.sh`。

同时将 AI 生成的结果说明写入任务的「结果摘要」字段（见任务结果输出规范章节），并将当日已完成任务数 +1（用于配额控制）。

### return-task.sh `<task_id> <原因>`

Agent 发现无法完成任务时调用：

```
1. 将 Task.退还原因 写入原因说明
2. Task.退还次数 +1
3. 清空 Task.认领人
4. 判断退还次数：
   - < 配置阈值（默认 3）→ Task.状态 = "Todo"（重新放回队列）
   - >= 阈值 → Task.状态 = "Blocked"（需要人工介入）
     并在任务的退还原因字段追加：
     "已被退还 N 次，等待人工处理"
5. 返回退出码 0
```

退还是无损操作：任务回到 Todo 后，其他具备条件的 Agent 可立即认领。Blocked 状态的任务不会被 `get-next-work.sh` 返回，需要人类在 Notion 中手动解决后重置为 Todo。

### sprint-plan.sh

纯确定性执行。按优先级评分（P0=40，P1=30，P2=20，P3=10）排序 Ready 需求，取前 N 条创建任务。Sprint 激活后由 AI 生成 Sprint 目标摘要写入 Sprint 表的「目标」字段，同时在 Sprint 表的「开始说明」字段记录本次选入的需求列表和优先级依据。Sprint 完成时由 AI 生成 Sprint 回顾摘要写入「结束说明」字段，包含完成情况和遗留问题。

### monitor-check.sh

按配置执行所有检查项，将结构化 findings 写入监控日志库，为每个问题在需求库创建 Inbox 条目。

---

## 任务结果输出规范

每个任务完成后，AI 必须在调用 `complete_task()` 前生成简洁的结果说明，写入任务表的「结果摘要」字段。

### 结果摘要格式

```
【做了什么】一句话说明本次完成的工作内容
【结果如何】成功 / 部分完成 / 失败，以及关键指标或输出
【遗留问题】无 / 有（具体说明）
```

示例：
```
【做了什么】实现用户登录 API，包含 JWT 签发和刷新逻辑
【结果如何】成功，单元测试覆盖率 87%，PR #42 已创建
【遗留问题】无
```

### Sprint 节点说明

| 节点 | 写入位置 | 内容 |
|---|---|---|
| Sprint 激活时 | Sprint 表「开始说明」 | 本次选入的需求列表、优先级依据、Sprint 目标 |
| Sprint 完成时 | Sprint 表「结束说明」 | 完成任务数/总任务数、未完成项说明、发现的遗留问题 |

Sprint 说明由执行 `sprint-plan.sh` 和触发 Sprint 完成的 Agent 负责生成并写入，内容简洁，供人类在 Notion 中快速了解进展。

---

## 每日工作配额控制

防止 Agent 过度消耗 token，每日完成任务数受配额限制。配额耗尽后 Agent 进入 IDLE 等待次日重置。

### Notion 配额记录

在任务表中维护一类特殊系统记录（类型：`DailyQuota`），字段：

| 字段 | 说明 |
|---|---|
| 标题 | `quota-YYYY-MM-DD`（按日期唯一） |
| 已完成任务数 | 当日所有 Agent 累计完成的任务数 |
| 配额上限 | 来自 config.json 的 `daily_task_limit` |
| 重置时间 | 按 `reset_hour_utc` 配置 |

### get-next-work.sh 配额检查逻辑

```
1. 读取今日 DailyQuota 记录（按 quota-YYYY-MM-DD 查找）
2. 若不存在 → 创建，已完成任务数 = 0
3. 若 已完成任务数 >= 配额上限 → 返回 IDLE，附带说明"每日配额已耗尽，等待次日重置"
4. 若未达上限 → 正常返回下一个任务
```

### complete-task.sh 配额更新逻辑

```
任务标记为 Done 或 Failed 后：
  → 对今日 DailyQuota 记录的「已完成任务数」执行 +1（乐观锁更新）
```

### 配额设计原则

- `daily_task_limit` 建议初始值：10（保守起步，视项目节奏调整）
- 配额以任务数为单位，而非 token 数，简单可观测
- 人类可随时在 Notion 中手动修改当日 DailyQuota 记录的上限值来临时调整
- Agent 不跨日累计；每天零点（UTC）自动开始新的配额记录

---

## MCP Server

`sdlc-mcp` 是 TypeScript 薄封装层，将脚本暴露为 MCP 工具，不含业务逻辑。

### 暴露的工具

```typescript
get_next_work()
  → 调用 get-next-work.sh
  → 返回 { phase, task_id, task_title, skill }

claim_task(task_id: string)
  → 调用 claim-task.sh
  → 返回 { success: boolean }

complete_task(task_id: string, status: "done" | "failed", notes?: string)
  → 调用 complete-task.sh
  → 返回 { sprint_plan_triggered?: boolean }

create_requirement(title: string, description: string, source: "human" | "monitor")
  → 直接写入 Notion 需求库
  → 返回 { requirement_id }

return_task(task_id: string, reason: string)
  → 调用 return-task.sh
  → 返回 { status: "todo" | "blocked", return_count: number }

get_project_knowledge()
  → 读取 Notion 项目知识库所有条目
  → 返回 { modules: [{ name, description, key_files, tech_stack }] }

upsert_knowledge_entry(module_name: string, description: string, key_files: string, tech_stack: string)
  → 新增或更新项目知识库条目（按 module_name 匹配）
  → 返回 { entry_id }
```

### 安装方式

`init.sh` 根据工具类型写入对应的 MCP 配置位置：

| 工具 | MCP 配置路径 |
|---|---|
| Claude Code | `.claude/mcp.json`（项目级） |
| Gemini CLI | `.gemini/mcp.json`（项目级） |
| Codex | `AGENTS.md` 内联工具声明 |

`.claude/mcp.json` 示例：
```json
{
  "mcpServers": {
    "sdlc": {
      "command": "npx",
      "args": ["sdlc-mcp", "--config", ".sdlc/config.json"]
    }
  }
}
```

---

## 新 Agent 接入流程

任何安装了插件并加入已有项目的 Agent：

```
1. 插件已安装 → 代码库中存在 CLAUDE.md / GEMINI.md / AGENTS.md
2. Agent 读取引导文件，获取：
   - 项目说明和项目类型（全新 / 已有）
   - 指令：读取 .sdlc/config.json，启动 sdlc-mcp
   - Notion Token：从环境变量 NOTION_TOKEN 读取

3. 若为已有项目（引导文件中有标注）：
   - 调用 get_project_knowledge() 读取项目知识库全部条目
   - 在内存中建立项目功能地图后再开始工作
   - 此步骤必须完成，不可跳过

4. Agent 调用 get_next_work() → 获得当前任务
5. Agent 从第一条消息起即可开始贡献
```

初始化完成后，新 Agent 接入无需任何人工干预。

### 知识库更新机制

知识库不是一次性文档，随项目演进持续更新：

| 触发时机 | 更新内容 |
|---|---|
| DEVELOP 任务完成，涉及新功能 | 新增知识库条目 |
| DEVELOP 任务完成，修改已有功能 | 更新对应条目的功能描述 |
| 人类直接在 Notion 中编辑 | 优先级最高，Agent 不覆盖人类修改 |

---

## Superpowers 集成（可选依赖）

运行时检测 superpowers skills 是否已安装。

**已安装 superpowers 时：**
- DEVELOP 阶段使用：`brainstorming` → `writing-plans` → `test-driven-development` → `requesting-code-review`
- REFINE 阶段使用：`brainstorming` 辅助生成验收标准

**未安装 superpowers 时：**
- 使用内置简化版 `develop.md` skill 完成开发阶段
- SDLC 循环机制不受影响，仅实现阶段的结构化程度降低

---

## 引导文件内容

`CLAUDE.md` / `GEMINI.md` / `AGENTS.md` 均包含以下内容（由 `init.sh` 根据项目名称生成）：

```markdown
# [项目名称] — oh-my-sdlc

本项目使用 oh-my-sdlc 进行自主开发生命周期管理。

## 你的角色
你是一名自主开发 Agent，无需等待人类指令即可开始工作。

## 启动步骤
1. 确认环境变量 NOTION_TOKEN 已设置
2. sdlc MCP Server 已通过对应工具的 MCP 配置文件加载
3. 调用 get_next_work() 获取当前任务
4. 调用 claim_task() 认领任务
5. 按照 skills/<skill>.md 执行
6. 完成后调用 complete_task()
7. 循环

## 配置
项目配置：.sdlc/config.json
Skills 目录：skills/
```

---

## 关键设计决策

| 决策点 | 选择 | 原因 |
|---|---|---|
| 协调模型 | 去中心化 | 无单点故障，任意 Agent 可承担任意阶段 |
| 状态存储 | Notion 多数据库 | 免费版兼容，人类可读，已有 MCP 支持 |
| 并发控制 | Notion 字段乐观锁 | 无需中央协调器，过期抢占恢复机制兜底 |
| Sprint 触发 | 时间或完成，以先到者为准 | 防止 Sprint 空转等待，也防止任务无限拖延 |
| 需求注入 | 仅 Sprint 边界 | 保证可预期的上线节奏 |
| 脚本运行时 | 仅 curl + jq | 零额外依赖，任意机器均可运行 |
| Token 存储 | 仅环境变量 | 永不写入代码库 |
| 结果输出 | 每任务强制写入 Notion | 人类可在 Notion 直接查看进展，无需询问 Agent |
| 配额控制 | 每日任务数上限 | 以任务数为代理指标，简单可观测，人类可手动调整 |
| 任务退还 | return-task.sh + 退还次数阈值 | 无法执行的任务自动让给其他 Agent；多次退还升级 Blocked 触发人工介入 |
| 已有项目接入 | init 时 AI 扫描代码生成知识库 | Agent 无需读遍代码即可快速上手，降低 context 消耗 |
| 部署敏感信息 | 仅环境变量，不进文件和 Notion | 避免密钥泄露；init 只提示变量名，不代写值 |
| Superpowers | 可选依赖 | 优雅降级，无 superpowers 亦可独立运行 |
