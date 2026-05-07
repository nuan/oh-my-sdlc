import { describe, it, expect, vi, beforeEach } from "vitest";
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
