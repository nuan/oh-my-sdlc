# oh-my-sdlc 实现计划（三）：Plugin 层

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建 oh-my-sdlc Plugin 层：3 个工具引导文件（CLAUDE.md / GEMINI.md / AGENTS.md）和 5 个 skill 文件（bootstrap / requirements / develop / deploy / monitor），让 AI Agent 能够完全自主地执行 SDLC 循环。

**Architecture:** 引导文件是 Agent 的启动入口，告知 MCP 配置位置和启动步骤；skill 文件是各阶段的执行手册，指导 Agent 完成创造性工作。所有文件均为纯 Markdown，无运行时依赖。使用 bash 验证脚本（tests/test-skills.sh）检查文件存在性和必要内容，以 TDD 方式驱动开发。

**Tech Stack:** Markdown, Bash（验证脚本）

**依赖：** 本 Plan 基于 `main` 分支（已含 Plan 1 脚本层和 Plan 2 MCP Server）。

---

## 文件结构

```
CLAUDE.md                    # Claude Code 引导文件（根目录）
GEMINI.md                    # Gemini CLI 引导文件（根目录）
AGENTS.md                    # Codex 及其他工具引导文件（根目录）
skills/
├── bootstrap.md             # 新 Agent 接入流程
├── requirements.md          # 需求精炼（REFINE 阶段）
├── develop.md               # 开发任务（DEVELOP 阶段）
├── deploy.md                # 部署任务（DEPLOY 阶段）
└── monitor.md               # 监控检查（MONITOR 阶段）
tests/
└── test-skills.sh           # 验证所有 skill 文件包含必要内容
```

---

## Task 1：验证脚本（TDD 基础）

**Files:**
- Create: `tests/test-skills.sh`

先写验证脚本。此时所有内容文件均不存在，脚本全部 FAIL——这是正确的起点。

- [ ] **Step 1：写入 `tests/test-skills.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

PASS=0
FAIL=0

check() {
  local file="$ROOT/$1"
  local pattern="$2"
  local label="$3"
  if [ ! -f "$file" ]; then
    echo "FAIL: $1 does not exist"
    FAIL=$((FAIL + 1))
    return
  fi
  if grep -q "$pattern" "$file"; then
    PASS=$((PASS + 1))
  else
    echo "FAIL [$1]: missing '$label'"
    FAIL=$((FAIL + 1))
  fi
}

# ── CLAUDE.md ────────────────────────────────────────
check "CLAUDE.md" "get_next_work" "get_next_work"
check "CLAUDE.md" "claim_task" "claim_task"
check "CLAUDE.md" "complete_task" "complete_task"
check "CLAUDE.md" "NOTION_TOKEN" "NOTION_TOKEN"
check "CLAUDE.md" "skills/" "skills/ reference"

# ── GEMINI.md ────────────────────────────────────────
check "GEMINI.md" "get_next_work" "get_next_work"
check "GEMINI.md" "claim_task" "claim_task"
check "GEMINI.md" "NOTION_TOKEN" "NOTION_TOKEN"

# ── AGENTS.md ────────────────────────────────────────
check "AGENTS.md" "get_next_work" "get_next_work"
check "AGENTS.md" "claim_task" "claim_task"
check "AGENTS.md" "NOTION_TOKEN" "NOTION_TOKEN"

# ── skills/bootstrap.md ──────────────────────────────
check "skills/bootstrap.md" "NOTION_TOKEN" "NOTION_TOKEN"
check "skills/bootstrap.md" "get_next_work" "get_next_work"
check "skills/bootstrap.md" "claim_task" "claim_task"
check "skills/bootstrap.md" "complete_task" "complete_task"
check "skills/bootstrap.md" "get_project_knowledge" "get_project_knowledge"
check "skills/bootstrap.md" "return_task" "return_task"

# ── skills/requirements.md ───────────────────────────
check "skills/requirements.md" "REFINE" "REFINE"
check "skills/requirements.md" "P0" "priority P0"
check "skills/requirements.md" "Ready" "Ready status"
check "skills/requirements.md" "Inbox" "Inbox status"
check "skills/requirements.md" "get_project_knowledge" "get_project_knowledge"
check "skills/requirements.md" "验收标准" "acceptance criteria"

# ── skills/develop.md ────────────────────────────────
check "skills/develop.md" "DEVELOP" "DEVELOP"
check "skills/develop.md" "return_task" "return_task"
check "skills/develop.md" "complete_task" "complete_task"
check "skills/develop.md" "get_project_knowledge" "get_project_knowledge"
check "skills/develop.md" "upsert_knowledge_entry" "upsert_knowledge_entry"
check "skills/develop.md" "做了什么" "result summary"
check "skills/develop.md" "superpowers" "superpowers"

# ── skills/deploy.md ─────────────────────────────────
check "skills/deploy.md" "DEPLOY" "DEPLOY"
check "skills/deploy.md" "return_task" "return_task"
check "skills/deploy.md" "complete_task" "complete_task"
check "skills/deploy.md" "DEPLOY_TOKEN\|DEPLOY_SSH_KEY_PATH" "deploy credentials"
check "skills/deploy.md" "github-actions" "github-actions"

# ── skills/monitor.md ────────────────────────────────
check "skills/monitor.md" "MONITOR" "MONITOR"
check "skills/monitor.md" "return_task" "return_task"
check "skills/monitor.md" "complete_task" "complete_task"
check "skills/monitor.md" "monitor-check.sh" "monitor-check.sh"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

- [ ] **Step 2：设置执行权限**

```bash
chmod +x tests/test-skills.sh
```

- [ ] **Step 3：运行，确认 FAIL（文件尚不存在）**

```bash
./tests/test-skills.sh 2>&1 || true
# 预期：所有文件报 "does not exist"，Results: 0 passed, 39 failed
```

- [ ] **Step 4：Commit**

```bash
git add tests/test-skills.sh
git commit -m "test: add skill file validation script"
```

---

## Task 2：引导文件（CLAUDE.md / GEMINI.md / AGENTS.md）

**Files:**
- Create: `CLAUDE.md`
- Create: `GEMINI.md`
- Create: `AGENTS.md`

- [ ] **Step 1：写入 `CLAUDE.md`**

```markdown
# oh-my-sdlc

本项目使用 oh-my-sdlc 进行自主开发生命周期管理。

## 你的角色

你是一名自主开发 Agent，无需等待人类指令即可开始工作。以 Notion 作为协调中枢，你的每项工作都有明确的任务可领取。

## 前提条件

- 环境变量 `NOTION_TOKEN` 已设置（`echo $NOTION_TOKEN` 不为空）
- sdlc MCP Server 已通过 `.claude/mcp.json` 加载（工具列表中可见 `get_next_work`）

`.claude/mcp.json` 配置示例：

​```json
{
  "mcpServers": {
    "sdlc": {
      "command": "npx",
      "args": ["tsx", "mcp/sdlc-mcp/src/index.ts", "--config", ".sdlc/config.json"]
    }
  }
}
​```

## 启动步骤

1. 确认 `NOTION_TOKEN` 环境变量已设置
2. 确认 sdlc MCP Server 已加载
3. 若首次加入，先阅读 `skills/bootstrap.md`
4. 调用 `get_next_work()` 获取当前任务
5. 调用 `claim_task(task_id)` 认领任务
6. 按照 `skills/<skill>.md` 执行（skill 名称由 `get_next_work()` 返回）
7. 完成后调用 `complete_task(task_id, status, notes)` 或 `return_task(task_id, reason)`
8. 回到步骤 4 循环

## 可用 Skills

| skill 名称     | 文件                     | 适用阶段   |
|--------------|------------------------|---------  |
| bootstrap    | skills/bootstrap.md    | 首次接入   |
| requirements | skills/requirements.md | REFINE    |
| develop      | skills/develop.md      | DEVELOP   |
| deploy       | skills/deploy.md       | DEPLOY    |
| monitor      | skills/monitor.md      | MONITOR   |

## 配置

- 项目配置：`.sdlc/config.json`
- Notion Token：环境变量 `NOTION_TOKEN`（不存入任何文件）
```

- [ ] **Step 2：写入 `GEMINI.md`**

```markdown
# oh-my-sdlc

本项目使用 oh-my-sdlc 进行自主开发生命周期管理。

## 你的角色

你是一名自主开发 Agent，无需等待人类指令即可开始工作。以 Notion 作为协调中枢，你的每项工作都有明确的任务可领取。

## 前提条件

- 环境变量 `NOTION_TOKEN` 已设置（`echo $NOTION_TOKEN` 不为空）
- sdlc MCP Server 已通过 `.gemini/mcp.json` 加载（工具列表中可见 `get_next_work`）

`.gemini/mcp.json` 配置示例：

​```json
{
  "mcpServers": {
    "sdlc": {
      "command": "npx",
      "args": ["tsx", "mcp/sdlc-mcp/src/index.ts", "--config", ".sdlc/config.json"]
    }
  }
}
​```

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

| skill 名称     | 文件                     | 适用阶段   |
|--------------|------------------------|---------  |
| bootstrap    | skills/bootstrap.md    | 首次接入   |
| requirements | skills/requirements.md | REFINE    |
| develop      | skills/develop.md      | DEVELOP   |
| deploy       | skills/deploy.md       | DEPLOY    |
| monitor      | skills/monitor.md      | MONITOR   |

## 配置

- 项目配置：`.sdlc/config.json`
- Notion Token：环境变量 `NOTION_TOKEN`（不存入任何文件）
```

- [ ] **Step 3：写入 `AGENTS.md`**

```markdown
# oh-my-sdlc

本项目使用 oh-my-sdlc 进行自主开发生命周期管理。

## 你的角色

你是一名自主开发 Agent，无需等待人类指令即可开始工作。以 Notion 作为协调中枢，你的每项工作都有明确的任务可领取。

## 前提条件

- 环境变量 `NOTION_TOKEN` 已设置
- sdlc MCP Server 可用（工具列表中可见 `get_next_work`）

MCP Server 启动命令：

​```
npx tsx mcp/sdlc-mcp/src/index.ts --config .sdlc/config.json
​```

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

| skill 名称     | 文件                     | 适用阶段   |
|--------------|------------------------|---------  |
| bootstrap    | skills/bootstrap.md    | 首次接入   |
| requirements | skills/requirements.md | REFINE    |
| develop      | skills/develop.md      | DEVELOP   |
| deploy       | skills/deploy.md       | DEPLOY    |
| monitor      | skills/monitor.md      | MONITOR   |

## 配置

- 项目配置：`.sdlc/config.json`
- Notion Token：环境变量 `NOTION_TOKEN`（不存入任何文件）
```

- [ ] **Step 4：运行验证脚本，确认引导文件检查通过**

```bash
./tests/test-skills.sh 2>&1 || true
# 预期：CLAUDE.md / GEMINI.md / AGENTS.md 的 11 个检查通过，skill 文件检查仍 FAIL
```

- [ ] **Step 5：Commit**

```bash
git add CLAUDE.md GEMINI.md AGENTS.md
git commit -m "feat: add agent bootstrap files (CLAUDE.md, GEMINI.md, AGENTS.md)"
```

---

## Task 3：skills/bootstrap.md

**Files:**
- Create: `skills/bootstrap.md`

- [ ] **Step 1：创建 skills 目录**

```bash
mkdir -p skills
```

- [ ] **Step 2：写入 `skills/bootstrap.md`**

```markdown
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
```

- [ ] **Step 3：运行验证脚本**

```bash
./tests/test-skills.sh 2>&1 || true
# 预期：bootstrap.md 的 6 个检查通过（累计 17 通过）
```

- [ ] **Step 4：Commit**

```bash
git add skills/bootstrap.md
git commit -m "feat: add bootstrap.md skill for new agent onboarding"
```

---

## Task 4：skills/requirements.md

**Files:**
- Create: `skills/requirements.md`

- [ ] **Step 1：写入 `skills/requirements.md`**

```markdown
# requirements.md — 需求精炼（REFINE 阶段）

适用场景：`get_next_work()` 返回 `phase: "REFINE"`。

REFINE 的目标：将 Inbox 状态的需求补充完整，评估优先级，推进到 Ready 状态，准备进入 Sprint。

**注意：REFINE 阶段直接操作 Notion 页面属性，不使用 `claim_task()` / `complete_task()`。**

## 步骤

### 1. 读取需求内容

`get_next_work()` 返回的 `task_id` 是 Notion 需求页面的 ID。通过 Notion MCP 读取该页面：

- 需求标题（`标题` 属性）
- 页面 body（用户填写的需求描述）
- 来源（`来源` 属性：Human / Monitor）

### 2. 判断需求质量

**可精炼**：需求描述清晰，能理解用户意图，可以制定验收标准 → 继续步骤 3。

**不可精炼**（以下任一情况）：
- 描述太模糊（如仅写"改进性能"），无法确定具体目标
- 与已有功能完全重复（先调用 `get_project_knowledge()` 对比知识库）
- 需要人类补充更多背景信息

不可精炼时：在页面 body 末尾追加说明（如"需求描述不足，等待补充"），保留 `Inbox` 状态，然后继续调用 `get_next_work()` 处理下一个。

### 3. 补充验收标准

在页面 body 末尾追加「验收标准」区块，至少 3 条可验证的接受条件：

​```
## 验收标准

- [ ] <具体、可验证的条件 1>
- [ ] <具体、可验证的条件 2>
- [ ] <具体、可验证的条件 3>
​```

示例（需求：用户可以导出报告）：

​```
## 验收标准

- [ ] 用户点击"导出"按钮后，3 秒内开始下载
- [ ] 导出的 CSV 文件包含所有可见列的数据
- [ ] 导出失败时显示错误提示，不静默失败
​```

### 4. 评估优先级

通过 Notion MCP 更新 `优先级` 属性：

| 优先级 | 适用场景 |
|-------|---------|
| P0 | 生产环境 Bug、安全漏洞、数据丢失风险 |
| P1 | 核心功能受损、重要用户路径阻断 |
| P2 | 功能增强、体验改善、效率提升 |
| P3 | Nice-to-have、内部工具优化 |

人类可随时在 Notion 中覆盖优先级——AI 的评估仅作参考。

### 5. 推进状态

通过 Notion MCP 更新 `状态` 属性为 `Ready`。

需求进入 Ready 后，将在下次 Sprint 规划（`sprint-plan.sh`）时按优先级分数（P0=40，P1=30，P2=20，P3=10）自动选入开发队列。

## 参考：知识库辅助判断

调用 `get_project_knowledge()` 获取已有模块信息，用于：
- 判断需求是否与已有功能重复
- 评估实现复杂度（影响优先级）
- 了解相关技术栈，确保验收标准符合实际
```

- [ ] **Step 2：运行验证脚本**

```bash
./tests/test-skills.sh 2>&1 || true
# 预期：requirements.md 的 6 个检查通过（累计 23 通过）
```

- [ ] **Step 3：Commit**

```bash
git add skills/requirements.md
git commit -m "feat: add requirements.md skill for REFINE phase"
```

---

## Task 5：skills/develop.md

**Files:**
- Create: `skills/develop.md`

- [ ] **Step 1：写入 `skills/develop.md`**

```markdown
# develop.md — 开发任务（DEVELOP 阶段）

适用场景：`get_next_work()` 返回 `phase: "DEVELOP"`。

## 前置条件检查（认领之前）

在调用 `claim_task()` 之前，验证以下条件：

1. 代码库可读写：`git status` 不报错
2. 测试命令可运行：执行项目测试套件，基线全部通过

**任意条件不满足时，立即调用：**

​```
return_task(task_id, "无法开始：<原因>（如：git 状态异常 / 基线测试 N 个失败）")
​```

## 工作流程

### 1. 了解任务

- 通过 Notion MCP 读取任务页面，获取任务描述和关联需求
- 读取关联需求的验收标准（页面 body 中的"验收标准"区块）
- 调用 `get_project_knowledge()` 找到相关模块，了解关键文件和技术栈

### 2. 执行开发

#### 有 superpowers 时（推荐路径）

1. 调用 `superpowers:brainstorming` skill — 理解需求，设计方案
2. 调用 `superpowers:writing-plans` skill — 制定逐步实现计划
3. 调用 `superpowers:subagent-driven-development` skill — 按计划实现（含 TDD 和代码审查）
4. 创建 PR，等待 CI 通过

#### 无 superpowers 时

1. 阅读相关代码，理解当前实现（重点：关键文件、接口、测试）
2. TDD 开发：
   - 先写测试（描述期望行为），运行确认失败
   - 实现功能，运行测试确认通过
3. 创建 PR：`gh pr create --title "<title>" --body "<summary>"`
4. 等待 CI 通过

### 3. 更新知识库（按需）

完成后判断是否需要更新知识库：

- **新增了模块或功能** → `upsert_knowledge_entry(module_name, description, key_files, tech_stack)`
- **修改了已有功能的接口或行为** → 调用 `upsert_knowledge_entry()` 更新对应条目

### 4. 完成任务

生成结果摘要并调用 `complete_task()`：

​```
complete_task(task_id, "done", notes)
​```

`notes` 格式（每次必须包含这三项）：

​```
【做了什么】一句话说明本次完成的工作内容
【结果如何】成功/部分完成/失败，关键指标（如：PR #42 已创建，测试覆盖率 87%）
【遗留问题】无 / 有（具体说明）
​```

**任务失败时**：

​```
complete_task(task_id, "failed", "【做了什么】...\n【结果如何】失败，<原因>\n【遗留问题】<具体说明>")
​```

## 遇到无法继续的情况

在执行过程中如果发现无法继续，调用：

​```
return_task(task_id, "<问题类型>：<具体说明>")
​```

常见原因示例：
- `缺少环境变量：SOME_API_KEY 未设置`
- `依赖缺失：需要 PostgreSQL 但本地未安装`
- `需求不明确：验收标准存在冲突，需人工确认`

退还是无损操作。任务退还次数达到阈值（默认 3 次）后自动变为 Blocked，需人工介入。
```

- [ ] **Step 2：运行验证脚本**

```bash
./tests/test-skills.sh 2>&1 || true
# 预期：develop.md 的 7 个检查通过（累计 30 通过）
```

- [ ] **Step 3：Commit**

```bash
git add skills/develop.md
git commit -m "feat: add develop.md skill for DEVELOP phase"
```

---

## Task 6：skills/deploy.md + skills/monitor.md

**Files:**
- Create: `skills/deploy.md`
- Create: `skills/monitor.md`

- [ ] **Step 1：写入 `skills/deploy.md`**

```markdown
# deploy.md — 部署任务（DEPLOY 阶段）

适用场景：`get_next_work()` 返回 `phase: "DEPLOY"`。

部署任务由 `complete-task.sh` 在当前 Sprint 到期时自动创建，无需人工触发。

## 前置条件检查（认领之前）

读取 `.sdlc/config.json` 中的 `deploy.method`，验证对应凭证：

| deploy.method    | 必须满足的条件                                           |
|----------------|------------------------------------------------------|
| github-actions | 已通过 `gh auth status` 验证，或 `GITHUB_TOKEN` 已设置 |
| script         | `DEPLOY_TOKEN` 或 `DEPLOY_SSH_KEY_PATH` 已设置         |
| manual         | 无（但会立即 return_task，不执行部署）                   |

**凭证缺失时**：

​```
return_task(task_id, "缺少部署凭证：DEPLOY_TOKEN 或 DEPLOY_SSH_KEY_PATH 未设置")
​```

## 部署流程

### method: "github-actions"

​```bash
trigger=$(jq -r '.deploy.trigger' .sdlc/config.json)
gh workflow run "$trigger" --ref main
run_id=$(gh run list --workflow="$trigger" --limit=1 --json databaseId -q '.[0].databaseId')
gh run watch "$run_id"
conclusion=$(gh run view "$run_id" --json conclusion -q '.conclusion')
​```

`conclusion == "success"` → `complete_task(..., "done", ...)`
`conclusion != "success"` → `complete_task(..., "failed", ...)`

### method: "script"

​```bash
deploy_script=$(jq -r '.deploy.script' .sdlc/config.json)
bash "$deploy_script"
# 退出码 0 → done，非 0 → failed
​```

### method: "manual"

​```
return_task(task_id, "部署方式为 manual，需要人工操作后手动将任务标记完成")
​```

## 完成任务

​```
complete_task(task_id, "done",
  "【做了什么】触发 <method> 部署\n【结果如何】成功，run #<id>\n【遗留问题】无")

complete_task(task_id, "failed",
  "【做了什么】触发 <method> 部署\n【结果如何】失败，<错误信息>\n【遗留问题】<具体问题>")
​```
```

- [ ] **Step 2：写入 `skills/monitor.md`**

```markdown
# monitor.md — 监控检查（MONITOR 阶段）

适用场景：`get_next_work()` 返回 `phase: "MONITOR"`。

监控检查由 `get-next-work.sh` 根据 `.sdlc/config.json` 中 `monitor.interval_hours` 定时触发。

## 前置条件检查（认领之前）

验证基础网络可用（不是健康检查本身，是网络连通性）：

​```bash
url=$(jq -r '.monitor.checks[] | select(.type=="http") | .url' .sdlc/config.json | head -1)
if [ -n "$url" ]; then
  status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" || echo "000")
  if [ "$status" = "000" ]; then
    return_task "$task_id" "网络不可达：无法连接到 $url（非健康问题，是本机网络问题）"
    exit 0
  fi
fi
​```

**注意：HTTP 非 200 响应是监控发现的问题，不是前置条件失败——应继续执行，让 monitor-check.sh 记录该发现。**

## 执行监控

调用 `claim_task()` 认领后，执行：

​```bash
bash scripts/monitor-check.sh
​```

`monitor-check.sh` 会自动：
1. 执行所有配置的检查项（HTTP 健康检查、自定义脚本）
2. 将结构化 findings 写入 Notion 监控日志库
3. 对每个发现的问题，在需求库自动创建 Inbox 条目（来源：Monitor）

## 完成任务

脚本正常退出后：

​```
complete_task(task_id, "done",
  "【做了什么】执行监控检查，共 <N> 个检查项\n【结果如何】完成，发现 <N> 个问题，已写入需求库\n【遗留问题】无")
​```

脚本本身报错（非监控到问题，是脚本执行失败）：

​```
complete_task(task_id, "failed",
  "【做了什么】执行监控检查\n【结果如何】失败，脚本报错：<error>\n【遗留问题】需排查 monitor-check.sh")
​```
```

- [ ] **Step 3：运行验证脚本，确认全部通过**

```bash
./tests/test-skills.sh
# 预期：全部通过，Results: 39 passed, 0 failed
```

- [ ] **Step 4：Commit**

```bash
git add skills/deploy.md skills/monitor.md
git commit -m "feat: add deploy.md and monitor.md skills"
```

---

## 自我审查

**Spec 覆盖检查（对照设计文档 Plugin 层章节）：**

- ✅ CLAUDE.md — 启动步骤、NOTION_TOKEN、MCP 配置示例、skills 目录
- ✅ GEMINI.md — 同上，gemini 工具配置
- ✅ AGENTS.md — 同上，Codex 工具声明格式
- ✅ skills/bootstrap.md — 环境检查、知识库读取（不可跳过）、主循环、SPRINT_PLAN 摘要写入
- ✅ skills/requirements.md — REFINE 阶段、优先级 P0~P3、验收标准格式、状态推进、知识库辅助
- ✅ skills/develop.md — 前置条件检查、superpowers/普通双路径、知识库更新、结果摘要格式（做了什么/结果如何/遗留问题）、return_task 说明
- ✅ skills/deploy.md — 前置条件（凭证检查）、3 种部署方式（github-actions/script/manual）、完成/失败结果摘要
- ✅ skills/monitor.md — 前置条件（网络而非健康）、monitor-check.sh 调用、完成/失败结果摘要
- ✅ 任务结果摘要格式 — 覆盖 develop / deploy / monitor 三个 skill

**Placeholder 扫描：** 无 TBD / TODO / 空洞描述

**工具名一致性：** 所有 MCP 工具名与 `mcp/sdlc-mcp/src/index.ts` 实现完全一致
