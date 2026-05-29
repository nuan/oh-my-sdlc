#!/usr/bin/env tsx
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { parseArgs } from "util";
import path from "path";
import { fileURLToPath } from "url";
import { runScript } from "./runner.js";

export function handleToolCall(
  projectRoot: string,
  name: string,
  args: Record<string, unknown>
): unknown {
  function str(key: string): string {
    const v = args[key];
    if (typeof v !== "string" || v === "")
      throw new Error(`Missing required argument: ${key}`);
    return v;
  }

  switch (name) {
    case "get_next_work":
      return runScript(projectRoot, "get-next-work", []);

    case "claim_task": {
      const taskId = str("task_id");
      try {
        runScript(projectRoot, "claim-task", [taskId]);
        return { success: true };
      } catch {
        return { success: false };
      }
    }

    case "complete_task": {
      const completeArgs = [str("task_id"), str("status")];
      const notes = args["notes"];
      if (typeof notes === "string" && notes !== "") completeArgs.push(notes);
      return runScript(projectRoot, "complete-task", completeArgs);
    }

    case "return_task":
      return runScript(projectRoot, "return-task", [
        str("task_id"),
        str("reason"),
      ]);

    case "create_requirement":
      return runScript(projectRoot, "create-requirement", [
        str("title"),
        str("description"),
        str("source"),
      ]);

    case "get_project_knowledge":
      return runScript(projectRoot, "get-knowledge", []);

    case "upsert_knowledge_entry":
      return runScript(projectRoot, "upsert-knowledge", [
        str("module_name"),
        str("description"),
        str("key_files"),
        str("tech_stack"),
      ]);

    case "submit_feedback":
      return runScript(projectRoot, "submit-feedback", [
        str("title"),
        str("description"),
        str("category"),
      ]);

    default:
      throw new Error(`Unknown tool: ${name}`);
  }
}

function createServer(projectRoot: string): Server {
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
      {
        name: "submit_feedback",
        description: "向 oh-my-sdlc 上游提交改进建议或 Bug 反馈",
        inputSchema: {
          type: "object",
          properties: {
            title: { type: "string", description: "反馈标题" },
            description: { type: "string", description: "详细描述" },
            category: {
              type: "string",
              enum: ["bug", "feature", "improvement", "question"],
              description: "分类",
            },
          },
          required: ["title", "description", "category"],
        },
      },
    ],
  }));

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;
    try {
      const result = handleToolCall(projectRoot, name, (args ?? {}) as Record<string, unknown>);
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

  return server;
}

async function main(): Promise<void> {
  const { values } = parseArgs({
    args: process.argv.slice(2),
    options: {
      config: { type: "string", default: ".sdlc/config.json" },
    },
  });

  const configPath = path.resolve(values.config!);
  const projectRoot = path.dirname(configPath);

  const server = createServer(projectRoot);
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

const isMain =
  process.argv[1] === fileURLToPath(import.meta.url) ||
  process.argv[1]?.endsWith("/sdlc-mcp");

if (isMain) {
  main().catch((err) => {
    process.stderr.write(`Fatal: ${err}\n`);
    process.exit(1);
  });
}
