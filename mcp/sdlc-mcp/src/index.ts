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
