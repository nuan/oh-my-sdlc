# oh-my-sdlc 使用指南

本指南覆盖三种 AI 工具的完整接入流程：Claude Code、Gemini CLI、Codex（及其他工具）。

---

## 目录

1. [前提条件](#前提条件)
2. [第一步：获取 Notion Token](#第一步获取-notion-token)
3. [第二步：安装 oh-my-sdlc](#第二步安装-oh-my-sdlc)
4. [第三步：运行初始化脚本](#第三步运行初始化脚本)
5. [第四步：配置 AI 工具](#第四步配置-ai-工具)
   - [Claude Code](#claude-code)
   - [Gemini CLI](#gemini-cli)
   - [Codex（及其他工具）](#codex及其他工具)
6. [日常工作流：提交需求](#日常工作流提交需求)
7. [多 Agent 并发](#多-agent-并发)
8. [配置调整](#配置调整)

---

## 前提条件

- **Node.js 18+**（用于运行 MCP Server）
- **curl** 和 **jq**（所有脚本依赖）
- **Notion 账号**，并有权限创建 Integration
- 项目代码库（git 仓库）

验证依赖：

```bash
node --version   # 需要 v18 或以上
curl --version
jq --version
```

---

## 第一步：获取 Notion Token

1. 打开 [https://www.notion.so/my-integrations](https://www.notion.so/my-integrations)
2. 点击 **New integration**
3. 填写名称（如 `my-sdlc`），选择工作区，提交
4. 复制 **Internal Integration Token**（`secret_xxx...` 或 `ntn_xxx...` 开头）

然后在 Notion 中创建一个**父页面**，用于存放所有数据库：

1. 在 Notion 创建任意页面，命名为项目名（如 `MyApp SDLC`）
2. 打开页面，点击右上角 **...** → **Add connections** → 选择刚才创建的 Integration
3. 从页面 URL 中复制页面 ID：
   ```
   https://notion.so/MyApp-SDLC-<页面ID>
   ```
   页面 ID 是 URL 最后一段，32 位十六进制（去掉连字符）

---

## 第二步：安装 oh-my-sdlc

**选项 A：作为 CLI 安装（推荐）**

把 oh-my-sdlc 安装成全局命令，然后在你的真实项目根目录初始化：

```bash
npm install -g oh-my-sdlc
mkdir my-project
cd my-project
sdlc init
```

`sdlc init` 会先安装 SDLC 资产，再调用初始化流程创建 Notion 数据库和本地配置。

如果项目已经存在：

```bash
cd your-project
sdlc init
```

只安装某个工具的配置时：

```bash
sdlc install claude
sdlc install codex
sdlc install gemini
sdlc install all
```

**选项 B：手动接入（备用）**

如果不想使用全局 CLI，可以将 oh-my-sdlc 内容合并到你的项目根目录：

```bash
cd your-project
git remote add sdlc https://github.com/nuan/oh-my-sdlc.git
git fetch sdlc
git merge sdlc/main --allow-unrelated-histories
```

或者手动复制以下目录/文件：

```
scripts/
mcp/
skills/
CLAUDE.md
GEMINI.md
AGENTS.md
```

---

## 第三步：运行初始化脚本

使用 CLI 时，在**项目根目录**执行：

```bash
sdlc init
```

手动接入时执行：

```bash
bash scripts/init.sh
```

脚本会交互式询问以下信息：

```
=== oh-my-sdlc 初始化 ===

Notion Integration Token (sk-...): <粘贴你的 Token>
Notion 父页面 ID: <粘贴页面 ID>
项目名称: MyApp
Sprint 周期（天） [14]: 14
Sprint 容量（任务数） [10]: 10

部署方式：
  1) github-actions
  2) script
  3) manual
选择 [3]: 1
Workflow 文件路径 [.github/workflows/deploy.yml]:

项目类型：
  A) 全新项目
  B) 已有项目接入
选择 [A]: A
```

脚本完成后会输出：

```
=== 初始化完成 ===

下一步：
  1. 确认 NOTION_TOKEN 已配置（重新加载终端或运行 source ~/.bashrc）
  2. 在 Claude Code 中通过 .claude/mcp.json 加载 MCP Server
  3. 运行 scripts/get-next-work.sh 开始工作
```

初始化会自动创建：

| 文件 | 内容 |
|---|---|
| `.sdlc/config.json` | 项目配置（数据库 ID、Sprint 设置等），**提交到 git** |
| `.claude/mcp.json` | Claude Code MCP 配置 |
| `.gemini/mcp.json` | Gemini CLI MCP 配置 |
| Notion 中 | 6 张数据库 + Sprint-001 + heartbeat 记录 |

> **已有项目（模式 B）**：初始化完成后，第一次启动 Agent 时会自动执行 `skills/bootstrap.md`，扫描现有代码库并写入 Notion 知识库。

重新加载环境变量：

```bash
source ~/.bashrc   # 或 source ~/.zshrc
echo $NOTION_TOKEN  # 确认非空
```

---

## 第四步：配置 AI 工具

CLI 安装后，三个工具都复用同一个 MCP 命令：

```bash
sdlc-mcp --config .sdlc/config.json
```

### Claude Code

使用 CLI 写入项目级配置：

```bash
cd your-project
sdlc install claude
```

**安装并进入项目：**

```bash
cd your-project
claude  # 启动 Claude Code
```

Claude Code 会自动读取 `.claude/mcp.json`，无需额外配置。验证 MCP 已加载：

```
> 请调用 get_next_work 工具
```

如果工具不可见，检查 `.claude/mcp.json`：

```json
{
  "mcpServers": {
    "sdlc": {
      "command": "sdlc-mcp",
      "args": ["--config", ".sdlc/config.json"]
    }
  }
}
```

也可以把 `plugins/claude-code` 作为 Claude Code plugin 开发/分发目录。插件内包含 `.mcp.json` 和 `sdlc-loop` skill，适合团队统一安装。

如果使用手动接入方式，确认 MCP Server 的 node_modules 存在：

```bash
cd mcp/sdlc-mcp && npm install
```

**首次启动 Agent：**

在 Claude Code 会话中输入：

```
请阅读 CLAUDE.md，然后开始工作。
```

Claude Code 会自动进入工作循环，无需进一步指令。

---

### Gemini CLI

使用 CLI 写入项目级配置和 extension 模板：

```bash
cd your-project
sdlc install gemini
```

**安装 Gemini CLI：**

```bash
npm install -g @google/gemini-cli
# 或
pip install gemini-cli
```

**配置 MCP：**

`.gemini/mcp.json` 已由 `init.sh` 生成，Gemini CLI 会自动读取。

验证格式：

```json
{
  "mcpServers": {
    "sdlc": {
      "command": "sdlc-mcp",
      "args": ["--config", ".sdlc/config.json"]
    }
  }
}
```

CLI 也会生成 `.gemini/extensions/oh-my-sdlc/gemini-extension.json`，用于 Gemini CLI extension 形态分发。

**设置 API Key：**

```bash
export GEMINI_API_KEY="your-key"
# 或通过 gemini auth login
```

**进入项目目录并启动：**

```bash
cd your-project
gemini
```

Gemini CLI 会读取当前目录的 `GEMINI.md` 作为上下文。首次启动输入：

```
请阅读 GEMINI.md，然后开始工作。
```

**如果 MCP 未自动加载，手动指定：**

```bash
gemini --mcp-config .gemini/mcp.json
```

---

### Codex（及其他工具）

Codex 通过 `AGENTS.md` 和 MCP 配置接入。使用 CLI 时：

```bash
cd your-project
sdlc install codex
```

这会写入：

```text
AGENTS.md
.codex/config.toml
```

其中 MCP Server 配置为：

```toml
[mcp_servers.sdlc]
command = "sdlc-mcp"
args = ["--config", ".sdlc/config.json"]
```

**手动接入时安装依赖：**

```bash
cd mcp/sdlc-mcp
npm install
```

**手动启动 MCP Server：**

```bash
cd your-project
sdlc-mcp --config .sdlc/config.json
```

如果没有安装 CLI，也可以使用仓库内 MCP Server：

```bash
npx tsx mcp/sdlc-mcp/src/index.ts --config .sdlc/config.json
```

**启动 Agent：**

Codex 和其他工具读取 `AGENTS.md` 作为上下文。将其内容作为系统提示词或上下文注入，或者直接告诉 Agent：

```
请阅读项目根目录的 AGENTS.md，然后开始工作。
```

---

## 日常工作流：提交需求

在 Notion 的**需求库**数据库中直接添加记录：

| 字段 | 填写说明 |
|---|---|
| 标题 | 需求一句话描述 |
| 状态 | 留空（默认 Inbox） |
| 优先级 | P0（紧急）/ P1 / P2 / P3（低优先级） |
| 来源 | Human |

添加后，Agent 在下一次循环时会自动发现并处理（Inbox → 精炼 → Ready → Sprint → 开发）。

**无需主动通知 Agent**，它会自主轮询。

---

## 多 Agent 并发

oh-my-sdlc 内置乐观锁，多个 Agent 可以同时运行，互不冲突：

```bash
# 终端 1
claude  # 启动第一个 Claude Code Agent

# 终端 2
claude  # 启动第二个 Claude Code Agent（或 gemini）
```

两个 Agent 会自动协调任务抢占，不会重复执行同一任务。

---

## 配置调整

初始化后可以编辑 `.sdlc/config.json` 调整以下参数（修改后**提交到 git**）：

```json
{
  "sprint": {
    "duration_days": 14,   // Sprint 周期天数
    "capacity": 10         // 每个 Sprint 最多任务数
  },
  "monitor": {
    "interval_hours": 6,   // 监控检查间隔
    "checks": [
      { "type": "http", "url": "https://yourapp.com/health", "expect_status": 200 },
      { "type": "script", "path": "./scripts/custom-health.sh" }
    ]
  },
  "quota": {
    "daily_task_limit": 10,  // 每日任务配额（防止过度消耗 token）
    "reset_hour_utc": 0
  }
}
```

**敏感信息**（SSH 密钥、部署 Token）只通过环境变量传递，永远不写入任何文件：

```bash
export DEPLOY_TOKEN="xxx"
export DEPLOY_SSH_KEY_PATH="~/.ssh/deploy_key"
```

---

## 常见问题

**Q: `get_next_work` 返回 IDLE**

A: 可能原因：① 需求库没有 Inbox 条目；② Sprint 已满且无 Ready 需求；③ 当日配额耗尽。在 Notion 需求库添加一条 Inbox 需求即可。

**Q: MCP Server 启动失败**

```bash
cd mcp/sdlc-mcp
npm install          # 安装依赖
npx tsx src/index.ts --config ../../.sdlc/config.json  # 手动测试
```

**Q: `NOTION_TOKEN` 未设置**

```bash
echo $NOTION_TOKEN   # 空则需要重新加载
source ~/.bashrc
```

**Q: 任务状态卡在 Claiming 超过 5 分钟**

在 Notion 任务表将该任务状态手动改回 `Todo`，Agent 会在下次循环重新认领。
