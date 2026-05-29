import { describe, it, expect, vi, beforeEach } from "vitest";
import * as runner from "../src/runner.js";
import { handleToolCall } from "../src/index.js";

vi.mock("../src/runner.js");
const mockRunScript = vi.mocked(runner.runScript);

const PROJECT_ROOT = "/fake/project";

describe("get_next_work", () => {
  beforeEach(() => vi.clearAllMocks());

  it("calls get-next-work with no args and returns result", () => {
    mockRunScript.mockReturnValue({ phase: "IDLE", task_id: "", task_title: "", skill: "" });
    const result = handleToolCall(PROJECT_ROOT, "get_next_work", {}) as { phase: string };
    expect(mockRunScript).toHaveBeenCalledWith(PROJECT_ROOT, "get-next-work", []);
    expect(result.phase).toBe("IDLE");
  });
});

describe("claim_task", () => {
  beforeEach(() => vi.clearAllMocks());

  it("returns {success: true} when script succeeds", () => {
    mockRunScript.mockReturnValue({ claimed: true });
    const result = handleToolCall(PROJECT_ROOT, "claim_task", { task_id: "task-abc" }) as { success: boolean };
    expect(mockRunScript).toHaveBeenCalledWith(PROJECT_ROOT, "claim-task", ["task-abc"]);
    expect(result.success).toBe(true);
  });

  it("returns {success: false} when script throws", () => {
    mockRunScript.mockImplementation(() => {
      throw new Error("Script 'claim-task' failed: exit code 1");
    });
    const result = handleToolCall(PROJECT_ROOT, "claim_task", { task_id: "task-abc" }) as { success: boolean };
    expect(result.success).toBe(false);
  });

  it("throws when task_id is missing", () => {
    expect(() => handleToolCall(PROJECT_ROOT, "claim_task", {})).toThrow("task_id");
  });
});

describe("complete_task", () => {
  beforeEach(() => vi.clearAllMocks());

  it("passes task_id, status, and notes when provided", () => {
    mockRunScript.mockReturnValue({ task_id: "t1", sprint_plan_triggered: false });
    const result = handleToolCall(PROJECT_ROOT, "complete_task", {
      task_id: "t1",
      status: "done",
      notes: "实现了登录",
    }) as { task_id: string };
    expect(mockRunScript).toHaveBeenCalledWith(PROJECT_ROOT, "complete-task", ["t1", "done", "实现了登录"]);
    expect(result.task_id).toBe("t1");
  });

  it("omits notes when not provided", () => {
    mockRunScript.mockReturnValue({ task_id: "t2", sprint_plan_triggered: true });
    handleToolCall(PROJECT_ROOT, "complete_task", { task_id: "t2", status: "failed" });
    expect(mockRunScript).toHaveBeenCalledWith(PROJECT_ROOT, "complete-task", ["t2", "failed"]);
  });
});

describe("return_task", () => {
  beforeEach(() => vi.clearAllMocks());

  it("calls return-task with task_id and reason", () => {
    mockRunScript.mockReturnValue({ status: "todo", return_count: 1 });
    const result = handleToolCall(PROJECT_ROOT, "return_task", {
      task_id: "task-xyz",
      reason: "缺少环境变量",
    }) as { status: string };
    expect(mockRunScript).toHaveBeenCalledWith(PROJECT_ROOT, "return-task", ["task-xyz", "缺少环境变量"]);
    expect(result.status).toBe("todo");
  });
});

describe("create_requirement", () => {
  beforeEach(() => vi.clearAllMocks());

  it("calls create-requirement with title, description, source", () => {
    mockRunScript.mockReturnValue({ requirement_id: "req-new-999" });
    const result = handleToolCall(PROJECT_ROOT, "create_requirement", {
      title: "新功能",
      description: "用户可以导出报告",
      source: "human",
    }) as { requirement_id: string };
    expect(mockRunScript).toHaveBeenCalledWith(PROJECT_ROOT, "create-requirement", [
      "新功能",
      "用户可以导出报告",
      "human",
    ]);
    expect(result.requirement_id).toBe("req-new-999");
  });
});

describe("get_project_knowledge", () => {
  beforeEach(() => vi.clearAllMocks());

  it("calls get-knowledge with no args and returns modules array", () => {
    mockRunScript.mockReturnValue({ modules: [] });
    const result = handleToolCall(PROJECT_ROOT, "get_project_knowledge", {}) as { modules: unknown[] };
    expect(mockRunScript).toHaveBeenCalledWith(PROJECT_ROOT, "get-knowledge", []);
    expect(Array.isArray(result.modules)).toBe(true);
  });
});

describe("upsert_knowledge_entry", () => {
  beforeEach(() => vi.clearAllMocks());

  it("calls upsert-knowledge with all 4 fields", () => {
    mockRunScript.mockReturnValue({ entry_id: "entry-aaa" });
    const result = handleToolCall(PROJECT_ROOT, "upsert_knowledge_entry", {
      module_name: "auth",
      description: "JWT 认证模块",
      key_files: "src/auth.ts",
      tech_stack: "TypeScript,Express",
    }) as { entry_id: string };
    expect(mockRunScript).toHaveBeenCalledWith(PROJECT_ROOT, "upsert-knowledge", [
      "auth",
      "JWT 认证模块",
      "src/auth.ts",
      "TypeScript,Express",
    ]);
    expect(result.entry_id).toBe("entry-aaa");
  });
});

describe("submit_feedback", () => {
  beforeEach(() => vi.clearAllMocks());

  it("calls submit-feedback with title, description, category", () => {
    mockRunScript.mockReturnValue({ feedback_id: "fb-123", source_project: "my-app" });
    const result = handleToolCall(PROJECT_ROOT, "submit_feedback", {
      title: "Sprint 规划应支持手动选择需求",
      description: "目前 sprint-plan.sh 只按优先级自动选入，建议支持手动指定需求列表",
      category: "feature",
    }) as { feedback_id: string; source_project: string };
    expect(mockRunScript).toHaveBeenCalledWith(PROJECT_ROOT, "submit-feedback", [
      "Sprint 规划应支持手动选择需求",
      "目前 sprint-plan.sh 只按优先级自动选入，建议支持手动指定需求列表",
      "feature",
    ]);
    expect(result.feedback_id).toBe("fb-123");
    expect(result.source_project).toBe("my-app");
  });

  it("throws when required fields are missing", () => {
    expect(() => handleToolCall(PROJECT_ROOT, "submit_feedback", {
      title: "缺少字段",
    })).toThrow("description");
  });
});
