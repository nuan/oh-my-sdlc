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
