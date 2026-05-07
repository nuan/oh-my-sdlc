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
