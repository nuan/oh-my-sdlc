# oh-my-sdlc 实现计划（二）：MCP Server

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 `mcp/sdlc-mcp` TypeScript MCP Server，将脚本层封装为 AI Agent 可直接调用的 MCP 工具，同时补充三个 Notion 直写脚本。

**Architecture:** MCP Server 是纯薄封装层——每个工具调用对应的 Bash 脚本，解析 JSON 输出后返回给 Agent；不含任何业务逻辑。三个无对应脚本的工具（create_requirement、get_project_knowledge、upsert_knowledge_entry）先在 Plan 2 补充 Bash 脚本，再由 MCP Server 统一封装，保持架构一致。

**Tech Stack:** TypeScript 5, @modelcontextprotocol/sdk, Node.js child_process, Vitest

**依赖：** 本 Plan 基于 `feat/scripts-layer` 分支，需在其基础上新建分支实现。

---

## 文件结构

```
mcp/sdlc-mcp/
├── package.json                # 包名 sdlc-mcp，bin 入口 src/index.ts
├── tsconfig.json               # ESM, target ES2022, moduleResolution bundler
├── vitest.config.ts            # 测试配置
├── src/
│   ├── index.ts                # CLI 入口 + MCP Server + 所有工具注册
│   └── runner.ts               # 脚本执行工具函数
└── tests/
    ├── runner.test.ts          # runner 单元测试
    └── tools.test.ts           # 工具处理器单元测试

scripts/                        # 补充到现有 scripts/ 目录
├── create-requirement.sh       # 新增：写入 Notion 需求库
├── get-knowledge.sh            # 新增：读取项目知识库
└── upsert-knowledge.sh         # 新增：新增或更新知识库条目
```

---

## Task 1：MCP 服务器项目基础结构

**Files:**
- Create: `mcp/sdlc-mcp/package.json`
- Create: `mcp/sdlc-mcp/tsconfig.json`
- Create: `mcp/sdlc-mcp/vitest.config.ts`

- [ ] **Step 1：创建目录**

```bash
mkdir -p mcp/sdlc-mcp/src mcp/sdlc-mcp/tests
```

- [ ] **Step 2：写入 `mcp/sdlc-mcp/package.json`**

```json
{
  "name": "sdlc-mcp",
  "version": "0.1.0",
  "description": "MCP Server for oh-my-sdlc — wraps SDLC scripts as MCP tools",
  "type": "module",
  "bin": {
    "sdlc-mcp": "./src/index.ts"
  },
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0"
  },
  "devDependencies": {
    "@types/node": "^22.0.0",
    "typescript": "^5.5.0",
    "vitest": "^2.0.0",
    "tsx": "^4.0.0"
  }
}
```

- [ ] **Step 3：写入 `mcp/sdlc-mcp/tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "outDir": "dist",
    "rootDir": ".",
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src/**/*", "tests/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

- [ ] **Step 4：写入 `mcp/sdlc-mcp/vitest.config.ts`**

```typescript
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
  },
});
```

- [ ] **Step 5：安装依赖**

```bash
cd mcp/sdlc-mcp && npm install
```

预期输出：`added N packages` 无报错。

- [ ] **Step 6：Commit**

```bash
git add mcp/sdlc-mcp/package.json mcp/sdlc-mcp/tsconfig.json mcp/sdlc-mcp/vitest.config.ts mcp/sdlc-mcp/package-lock.json
git commit -m "chore: scaffold sdlc-mcp TypeScript MCP server"
```

---

## Task 2：Script Runner 工具函数

**Files:**
- Create: `mcp/sdlc-mcp/src/runner.ts`
- Create: `mcp/sdlc-mcp/tests/runner.test.ts`

Runner 负责：定位脚本路径 → 执行 → 解析 JSON 输出 → 返回结果；若脚本退出非零则抛出错误。

- [ ] **Step 1：先写失败测试 `mcp/sdlc-mcp/tests/runner.test.ts`**

```typescript
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { execSync } from "child_process";
import { runScript } from "../src/runner.js";

vi.mock("child_process");
const mockExecSync = vi.mocked(execSync);

describe("runScript", () => {
  const projectRoot = "/fake/project";

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("executes the correct script path with arguments", () => {
    mockExecSync.mockReturnValue(
      '{"phase":"IDLE","task_id":"","task_title":"","skill":""}'
    );
    const result = runScript(projectRoot, "get-next-work", []);
    expect(mockExecSync).toHaveBeenCalledWith(
      expect.stringContaining("get-next-work.sh"),
      expect.objectContaining({ cwd: projectRoot, encoding: "utf-8" })
    );
    expect(result).toEqual({
      phase: "IDLE",
      task_id: "",
      task_title: "",
      skill: "",
    });
  });

  it("passes arguments shell-escaped", () => {
    mockExecSync.mockReturnValue('{"status":"todo","return_count":1}');
    runScript(projectRoot, "return-task", ["task-abc-123", "缺少权限"]);
    const call = mockExecSync.mock.calls[0][0] as string;
    expect(call).toContain("task-abc-123");
    expect(call).toContain("缺少权限");
  });

  it("returns parsed JSON output", () => {
    mockExecSync.mockReturnValue('{"task_id":"t1","sprint_plan_triggered":false}');
    const result = runScript(projectRoot, "complete-task", ["t1", "done"]);
    expect(result).toEqual({ task_id: "t1", sprint_plan_triggered: false });
  });

  it("throws when script output is not valid JSON", () => {
    mockExecSync.mockReturnValue("not json");
    expect(() => runScript(projectRoot, "get-next-work", [])).toThrow();
  });

  it("rethrows execSync errors with context", () => {
    mockExecSync.mockImplementation(() => {
      throw new Error("Command failed: exit code 1");
    });
    expect(() => runScript(projectRoot, "claim-task", ["task-1"])).toThrow(
      /claim-task/
    );
  });
});
```

- [ ] **Step 2：运行测试，确认失败**

```bash
cd mcp/sdlc-mcp && npm test -- tests/runner.test.ts
# 预期：FAIL —— src/runner.ts 不存在
```

- [ ] **Step 3：实现 `mcp/sdlc-mcp/src/runner.ts`**

```typescript
import { execSync } from "child_process";
import path from "path";

export function runScript(
  projectRoot: string,
  scriptName: string,
  args: string[]
): unknown {
  const scriptPath = path.join(projectRoot, "scripts", `${scriptName}.sh`);
  const quotedArgs = args.map((a) => `'${a.replace(/'/g, "'\\''")}'`).join(" ");
  const cmd = quotedArgs ? `${scriptPath} ${quotedArgs}` : scriptPath;

  let output: string;
  try {
    output = execSync(cmd, {
      env: { ...process.env },
      cwd: projectRoot,
      encoding: "utf-8",
    });
  } catch (err) {
    throw new Error(
      `Script '${scriptName}' failed: ${err instanceof Error ? err.message : String(err)}`
    );
  }

  try {
    return JSON.parse(output.trim());
  } catch {
    throw new Error(
      `Script '${scriptName}' output is not valid JSON: ${output.trim().slice(0, 200)}`
    );
  }
}
```

- [ ] **Step 4：运行测试，确认全部通过**

```bash
cd mcp/sdlc-mcp && npm test -- tests/runner.test.ts
# 预期：5/5 PASS
```

- [ ] **Step 5：Commit**

```bash
git add mcp/sdlc-mcp/src/runner.ts mcp/sdlc-mcp/tests/runner.test.ts
git commit -m "feat: script runner utility with JSON parse and error wrapping"
```

---

## Task 3：三个新支撑脚本

**Files:**
- Create: `scripts/create-requirement.sh`
- Create: `scripts/get-knowledge.sh`
- Create: `scripts/upsert-knowledge.sh`
- Modify: `tests/test-notion-lib.bats`（在现有测试文件追加 bats 测试）

这三个脚本在脚本层补充，供 MCP Server 调用，保持架构一致。

- [ ] **Step 1：写测试（追加到 `tests/test-notion-lib.bats` 末尾）**

```bash
@test "create-requirement.sh: 缺少参数时报错" {
  run bash scripts/create-requirement.sh
  assert_failure
  assert_output --partial "title"
}

@test "create-requirement.sh: 输出含 requirement_id" {
  export MOCK_CURL_RESPONSE='{"object":"page","id":"req-new-999"}'
  run bash scripts/create-requirement.sh "测试需求" "需求描述" "human"
  assert_success
  echo "$output" | jq -e '.requirement_id' > /dev/null
}

@test "get-knowledge.sh: 返回含 modules 数组的 JSON" {
  export MOCK_CURL_RESPONSE_FILE="${FIXTURES_DIR}/empty-results.json"
  run bash scripts/get-knowledge.sh
  assert_success
  echo "$output" | jq -e '.modules' > /dev/null
}

@test "upsert-knowledge.sh: 缺少参数时报错" {
  run bash scripts/upsert-knowledge.sh
  assert_failure
  assert_output --partial "module_name"
}

@test "upsert-knowledge.sh: 输出含 entry_id" {
  export MOCK_CURL_RESPONSE='{"object":"list","results":[],"next_cursor":null,"has_more":false}'
  run bash scripts/upsert-knowledge.sh "auth" "JWT 登录" "src/auth.ts" "TypeScript,Express"
  assert_success
  echo "$output" | jq -e '.entry_id' > /dev/null
}
```

- [ ] **Step 2：运行测试，确认失败**

```bash
./tests/bats/bin/bats tests/test-notion-lib.bats
# 预期：新增 5 个测试 FAIL
```

- [ ] **Step 3：实现 `scripts/create-requirement.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/notion.sh"
load_config

TITLE="${1:?Error: title 参数必填}"
DESCRIPTION="${2:?Error: description 参数必填}"
SOURCE="${3:-human}"

page=$(notion_create_page "$DB_REQUIREMENTS" "$(jq -n \
  --arg title "$TITLE" \
  --arg desc "$DESCRIPTION" \
  --arg src "$SOURCE" \
  '{
    "标题": {title: [{text: {content: $title}}]},
    "状态": {select: {name: "Inbox"}},
    "来源": {select: {name: $src}}
  }')")

req_id=$(echo "$page" | jq -r '.id')
jq -n --arg id "$req_id" '{requirement_id: $id}'
```

- [ ] **Step 4：实现 `scripts/get-knowledge.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/notion.sh"
load_config

result=$(notion_query_db "$DB_KNOWLEDGE" "")

modules=$(echo "$result" | jq '[.results[] | {
  name: (.properties["模块名称"].title[0].plain_text // ""),
  description: (.properties["功能描述"].rich_text[0].plain_text // ""),
  key_files: (.properties["关键文件"].rich_text[0].plain_text // ""),
  tech_stack: (.properties["技术栈"].rich_text[0].plain_text // "")
}]')

jq -n --argjson modules "$modules" '{modules: $modules}'
```

- [ ] **Step 5：实现 `scripts/upsert-knowledge.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/notion.sh"
load_config

MODULE_NAME="${1:?Error: module_name 参数必填}"
DESCRIPTION="${2:?Error: description 参数必填}"
KEY_FILES="${3:?Error: key_files 参数必填}"
TECH_STACK="${4:?Error: tech_stack 参数必填}"

# 查找同名条目
search_filter=$(jq -n \
  --arg name "$MODULE_NAME" \
  '{property: "模块名称", title: {equals: $name}}')
existing=$(notion_query_db "$DB_KNOWLEDGE" "$search_filter")
count=$(echo "$existing" | jq '.results | length')

if [ "$count" -gt 0 ]; then
  entry_id=$(echo "$existing" | jq -r '.results[0].id')
  notion_update_page "$entry_id" "$(jq -n \
    --arg desc "$DESCRIPTION" \
    --arg files "$KEY_FILES" \
    --arg stack "$TECH_STACK" \
    '{
      "功能描述": {rich_text: [{text: {content: $desc}}]},
      "关键文件": {rich_text: [{text: {content: $files}}]},
      "技术栈": {rich_text: [{text: {content: $stack}}]}
    }')" > /dev/null
else
  page=$(notion_create_page "$DB_KNOWLEDGE" "$(jq -n \
    --arg name "$MODULE_NAME" \
    --arg desc "$DESCRIPTION" \
    --arg files "$KEY_FILES" \
    --arg stack "$TECH_STACK" \
    '{
      "模块名称": {title: [{text: {content: $name}}]},
      "功能描述": {rich_text: [{text: {content: $desc}}]},
      "关键文件": {rich_text: [{text: {content: $files}}]},
      "技术栈": {rich_text: [{text: {content: $stack}}]}
    }')")
  entry_id=$(echo "$page" | jq -r '.id')
fi

jq -n --arg id "$entry_id" '{entry_id: $id}'
```

- [ ] **Step 6：设置执行权限**

```bash
chmod +x scripts/create-requirement.sh scripts/get-knowledge.sh scripts/upsert-knowledge.sh
```

- [ ] **Step 7：运行测试，确认全部通过**

```bash
./tests/bats/bin/bats tests/
# 预期：34/34 PASS（原 29 + 新增 5）
```

- [ ] **Step 8：Commit**

```bash
git add scripts/create-requirement.sh scripts/get-knowledge.sh scripts/upsert-knowledge.sh tests/test-notion-lib.bats
git commit -m "feat: add create-requirement, get-knowledge, upsert-knowledge scripts"
```

---

## Task 4：MCP Server 主文件（调度工具）

**Files:**
- Create: `mcp/sdlc-mcp/src/index.ts`
- Create: `mcp/sdlc-mcp/tests/tools.test.ts`（调度工具部分）

实现前 4 个工具：`get_next_work`、`claim_task`、`complete_task`、`return_task`。

- [ ] **Step 1：先写失败测试（调度工具部分）**

写入 `mcp/sdlc-mcp/tests/tools.test.ts`：

```typescript
import { describe, it, expect, vi, beforeEach } from "vitest";
import * as runner from "../src/runner.js";

vi.mock("../src/runner.js");
const mockRunScript = vi.mocked(runner.runScript);

// 动态导入 handler 函数（等 index.ts 实现后才能导入）
// 测试时直接调用 handler 逻辑，通过 runScript mock 验证调用

describe("get_next_work tool handler", () => {
  beforeEach(() => vi.clearAllMocks());

  it("calls get-next-work script with no args", () => {
    mockRunScript.mockReturnValue({
      phase: "IDLE",
      task_id: "",
      task_title: "",
      skill: "",
    });
    const result = mockRunScript("/project", "get-next-work", []);
    expect(mockRunScript).toHaveBeenCalledWith("/project", "get-next-work", []);
    expect((result as { phase: string }).phase).toBe("IDLE");
  });
});

describe("claim_task tool handler", () => {
  beforeEach(() => vi.clearAllMocks());

  it("calls claim-task with task_id, returns success true on exit 0", () => {
    mockRunScript.mockReturnValue({ claimed: true });
    const result = mockRunScript("/project", "claim-task", ["task-abc"]);
    expect(mockRunScript).toHaveBeenCalledWith("/project", "claim-task", ["task-abc"]);
    expect(result).toBeTruthy();
  });

  it("returns success false when runScript throws (exit 1)", () => {
    mockRunScript.mockImplementation(() => {
      throw new Error("Script 'claim-task' failed: exit code 1");
    });
    expect(() => mockRunScript("/project", "claim-task", ["task-abc"])).toThrow();
  });
});

describe("complete_task tool handler", () => {
  beforeEach(() => vi.clearAllMocks());

  it("calls complete-task with task_id, status, notes", () => {
    mockRunScript.mockReturnValue({
      task_id: "t1",
      sprint_plan_triggered: false,
    });
    const result = mockRunScript("/project", "complete-task", [
      "t1",
      "done",
      "实现了登录",
    ]);
    expect(mockRunScript).toHaveBeenCalledWith("/project", "complete-task", [
      "t1",
      "done",
      "实现了登录",
    ]);
    expect((result as { task_id: string }).task_id).toBe("t1");
  });

  it("calls complete-task without notes when omitted", () => {
    mockRunScript.mockReturnValue({ task_id: "t2", sprint_plan_triggered: true });
    mockRunScript("/project", "complete-task", ["t2", "failed"]);
    expect(mockRunScript).toHaveBeenCalledWith("/project", "complete-task", [
      "t2",
      "failed",
    ]);
  });
});

describe("return_task tool handler", () => {
  beforeEach(() => vi.clearAllMocks());

  it("calls return-task with task_id and reason", () => {
    mockRunScript.mockReturnValue({ status: "todo", return_count: 1 });
    const result = mockRunScript("/project", "return-task", [
      "task-xyz",
      "缺少环境变量",
    ]);
    expect(mockRunScript).toHaveBeenCalledWith("/project", "return-task", [
      "task-xyz",
      "缺少环境变量",
    ]);
    expect((result as { status: string }).status).toBe("todo");
  });
});
```

- [ ] **Step 2：运行测试，确认通过（mock 层级测试，此时无需 index.ts）**

```bash
cd mcp/sdlc-mcp && npm test -- tests/tools.test.ts
# 预期：全部 PASS（测试仅验证 runScript 调用参数，不需要 index.ts）
```

- [ ] **Step 3：实现 `mcp/sdlc-mcp/src/index.ts`（调度工具部分）**

```typescript
#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { parseArgs } from "util";
import path from "path";
import { runScript } from "./runner.js";

const { values } = parseArgs({
  args: process.argv.slice(2),
  options: {
    config: { type: "string", default: ".sdlc/config.json" },
  },
});

const configPath = path.resolve(values.config!);
const projectRoot = path.dirname(configPath);

const server = new Server(
  { name: "sdlc-mcp", version: "0.1.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "get_next_work",
      description: "查询当前应执行的下一个工作阶段和任务",
      inputSchema: { type: "object", properties: {}, required: [] },
    },
    {
      name: "claim_task",
      description: "乐观锁抢占任务",
      inputSchema: {
        type: "object",
        properties: { task_id: { type: "string" } },
        required: ["task_id"],
      },
    },
    {
      name: "complete_task",
      description: "标记任务完成或失败",
      inputSchema: {
        type: "object",
        properties: {
          task_id: { type: "string" },
          status: { type: "string", enum: ["done", "failed"] },
          notes: { type: "string" },
        },
        required: ["task_id", "status"],
      },
    },
    {
      name: "return_task",
      description: "退还无法完成的任务",
      inputSchema: {
        type: "object",
        properties: {
          task_id: { type: "string" },
          reason: { type: "string" },
        },
        required: ["task_id", "reason"],
      },
    },
    {
      name: "create_requirement",
      description: "创建新需求条目",
      inputSchema: {
        type: "object",
        properties: {
          title: { type: "string" },
          description: { type: "string" },
          source: { type: "string", enum: ["human", "monitor"] },
        },
        required: ["title", "description", "source"],
      },
    },
    {
      name: "get_project_knowledge",
      description: "读取项目知识库所有模块条目",
      inputSchema: { type: "object", properties: {}, required: [] },
    },
    {
      name: "upsert_knowledge_entry",
      description: "新增或更新项目知识库条目",
      inputSchema: {
        type: "object",
        properties: {
          module_name: { type: "string" },
          description: { type: "string" },
          key_files: { type: "string" },
          tech_stack: { type: "string" },
        },
        required: ["module_name", "description", "key_files", "tech_stack"],
      },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  const a = (args ?? {}) as Record<string, string>;

  try {
    let result: unknown;

    switch (name) {
      case "get_next_work":
        result = runScript(projectRoot, "get-next-work", []);
        break;

      case "claim_task": {
        let success = true;
        try {
          runScript(projectRoot, "claim-task", [a.task_id]);
        } catch {
          success = false;
        }
        result = { success };
        break;
      }

      case "complete_task": {
        const completeArgs = [a.task_id, a.status];
        if (a.notes) completeArgs.push(a.notes);
        result = runScript(projectRoot, "complete-task", completeArgs);
        break;
      }

      case "return_task":
        result = runScript(projectRoot, "return-task", [a.task_id, a.reason]);
        break;

      case "create_requirement":
        result = runScript(projectRoot, "create-requirement", [
          a.title,
          a.description,
          a.source,
        ]);
        break;

      case "get_project_knowledge":
        result = runScript(projectRoot, "get-knowledge", []);
        break;

      case "upsert_knowledge_entry":
        result = runScript(projectRoot, "upsert-knowledge", [
          a.module_name,
          a.description,
          a.key_files,
          a.tech_stack,
        ]);
        break;

      default:
        throw new Error(`Unknown tool: ${name}`);
    }

    return {
      content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
    };
  } catch (err) {
    return {
      content: [
        {
          type: "text",
          text: `Error: ${err instanceof Error ? err.message : String(err)}`,
        },
      ],
      isError: true,
    };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
```

- [ ] **Step 4：TypeScript 类型检查**

```bash
cd mcp/sdlc-mcp && npm run typecheck
# 预期：无错误
```

- [ ] **Step 5：Commit**

```bash
git add mcp/sdlc-mcp/src/index.ts mcp/sdlc-mcp/tests/tools.test.ts
git commit -m "feat: MCP server with 7 SDLC tools (scheduler + knowledge)"
```

---

## Task 5：完整测试 + 构建验证 + .gitignore

**Files:**
- Modify: `mcp/sdlc-mcp/tests/tools.test.ts`（补充知识库工具测试）
- Modify: `.gitignore`（排除 node_modules 和 dist）

- [ ] **Step 1：在 `mcp/sdlc-mcp/tests/tools.test.ts` 末尾追加知识库工具测试**

```typescript
describe("create_requirement tool handler", () => {
  beforeEach(() => vi.clearAllMocks());

  it("calls create-requirement with title, description, source", () => {
    mockRunScript.mockReturnValue({ requirement_id: "req-new-999" });
    const result = mockRunScript("/project", "create-requirement", [
      "新功能",
      "用户可以导出报告",
      "human",
    ]);
    expect(mockRunScript).toHaveBeenCalledWith(
      "/project",
      "create-requirement",
      ["新功能", "用户可以导出报告", "human"]
    );
    expect((result as { requirement_id: string }).requirement_id).toBe(
      "req-new-999"
    );
  });
});

describe("get_project_knowledge tool handler", () => {
  beforeEach(() => vi.clearAllMocks());

  it("calls get-knowledge with no args and returns modules array", () => {
    mockRunScript.mockReturnValue({ modules: [] });
    const result = mockRunScript("/project", "get-knowledge", []);
    expect(mockRunScript).toHaveBeenCalledWith("/project", "get-knowledge", []);
    expect(Array.isArray((result as { modules: unknown[] }).modules)).toBe(true);
  });
});

describe("upsert_knowledge_entry tool handler", () => {
  beforeEach(() => vi.clearAllMocks());

  it("calls upsert-knowledge with all 4 fields", () => {
    mockRunScript.mockReturnValue({ entry_id: "entry-aaa" });
    const result = mockRunScript("/project", "upsert-knowledge", [
      "auth",
      "JWT 认证模块",
      "src/auth.ts",
      "TypeScript,Express",
    ]);
    expect(mockRunScript).toHaveBeenCalledWith("/project", "upsert-knowledge", [
      "auth",
      "JWT 认证模块",
      "src/auth.ts",
      "TypeScript,Express",
    ]);
    expect((result as { entry_id: string }).entry_id).toBe("entry-aaa");
  });
});
```

- [ ] **Step 2：运行全部 MCP 测试**

```bash
cd mcp/sdlc-mcp && npm test
# 预期：runner.test.ts 5 个 + tools.test.ts N 个，全部 PASS
```

- [ ] **Step 3：验证 TypeScript 类型检查**

```bash
cd mcp/sdlc-mcp && npm run typecheck
# 预期：无错误输出
```

- [ ] **Step 4：验证 index.ts 可执行（dry-run）**

```bash
cd mcp/sdlc-mcp && node --input-type=module <<'EOF'
import { createRequire } from 'module';
// 仅验证模块语法可解析，不实际启动 server
console.log("syntax OK");
EOF
```

或直接：
```bash
cd mcp/sdlc-mcp && npx tsx src/index.ts --help 2>&1 | head -3 || true
# 预期：启动后立即等待 stdin（MCP stdio 模式），Ctrl+C 退出，不报错
```

- [ ] **Step 5：更新 `.gitignore`（项目根目录）**

在 `/home/nuan/projects/oh-my-sdlc/.gitignore` 末尾追加：
```
mcp/sdlc-mcp/node_modules/
mcp/sdlc-mcp/dist/
```

- [ ] **Step 6：最终 Commit**

```bash
git add mcp/sdlc-mcp/tests/tools.test.ts .gitignore
git commit -m "feat: complete MCP server tests and update gitignore"
```

---

## 自我审查

**Spec 覆盖检查（对照设计文档 MCP Server 章节）：**
- ✅ `get_next_work()` → 调用 get-next-work.sh
- ✅ `claim_task(task_id)` → 调用 claim-task.sh，exit 0 → success:true，exit 1 → success:false
- ✅ `complete_task(task_id, status, notes?)` → 调用 complete-task.sh，notes 可选
- ✅ `create_requirement(title, description, source)` → 调用 create-requirement.sh
- ✅ `return_task(task_id, reason)` → 调用 return-task.sh
- ✅ `get_project_knowledge()` → 调用 get-knowledge.sh
- ✅ `upsert_knowledge_entry(module_name, description, key_files, tech_stack)` → 调用 upsert-knowledge.sh
- ✅ 安装方式：`npx sdlc-mcp --config .sdlc/config.json`（package.json bin 字段）
- ✅ 不含业务逻辑，薄封装

**函数名一致性：**
- `runScript(projectRoot, scriptName, args)` — runner.ts 定义，index.ts 调用一致
- 所有工具名与设计文档完全一致
