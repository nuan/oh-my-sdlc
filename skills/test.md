# test.md — Sprint QA 测试执行流程

适用场景：`get_next_work()` 返回 `phase = "TEST"` 时，执行本 skill。

## 前置条件检查

1. 确认 `DB_BUGS` 和 `DB_TEST_REPORTS` 环境变量非空（需在 config.json 中配置 `bugs` 和 `test_reports` 数据库 ID）
2. 若为空，调用 `return_task(task_id, "配置缺失：config.json 中未找到 bugs/test_reports 数据库 ID，请先运行 init.sh")`

## 执行步骤

### 1. 了解测试范围

- 读取当前任务页面，获取关联的 Sprint ID
- 查询该 Sprint 下所有已完成的 Dev 任务，获取任务列表（了解本次 Sprint 交付了哪些功能）
- 查询项目知识库 `get_project_knowledge()`，了解功能模块和关键文件

### 2. 制定测试计划

根据 Sprint 交付内容，制定测试范围：
- **功能测试**：针对每个 Dev 任务覆盖核心用户场景
- **集成测试**：验证功能间的交互和数据流
- **回归测试**：确认历史功能未被破坏

### 3. 创建测试报告

调用 `create_test_report(sprint_id, title?, description?)` 创建本次测试报告：
- `sprint_id`：关联的 Sprint ID
- `description`：测试范围和用例简述

### 4. 执行测试

按照测试计划逐项执行测试。对于每个发现的 Bug：

```
report_bug(
  title:    "简短描述（功能+现象）",
  severity: "P0-Critical | P1-High | P2-Medium | P3-Low",
  source:   "Test",
  sprint_id: <当前 Sprint ID>,
  notes:    "复现步骤、期望行为、实际行为"
)
```

**严重程度判断标准：**
| 级别 | 描述 |
|------|------|
| P0-Critical | 核心功能不可用，阻塞用户使用 |
| P1-High | 重要功能异常，影响主要流程 |
| P2-Medium | 次要功能异常，有可接受的绕过方式 |
| P3-Low | 界面/体验问题，不影响核心功能 |

### 5. 决策：通过 or 失败

**测试通过条件（全部满足）：**
- 无 P0-Critical Bug
- P1-High Bug 数量 ≤ 配置阈值（默认 0）

**测试失败处理：**
- P0/P1 Bug 存在时，调用 `complete_task(task_id, "failed", "测试未通过：发现 N 个 P0/P1 Bug，待修复后重测")`
- 由人工决策是否触发补丁 Sprint 或回退 Sprint

**测试通过处理：**
- 调用 `complete_task(task_id, "done", "QA 测试通过：共发现 N 个 Bug（P0:x P1:x P2:x P3:x），已记录")`
- 系统自动将 Sprint 状态置为 Completed 并触发 SprintPlan

### 6. Bug 状态追踪规范

每次对 Bug 状态的变更都需要调用 `update_bug`：

| 状态流转 | 触发条件 |
|---------|---------|
| Open → In Fix | 开发人员认领该 Bug |
| In Fix → Verified | 修复后重测通过 |
| In Fix → Open | 修复后重测仍失败 |
| Open/In Fix → Won't Fix | 人工决策不修复 |
| Verified → Closed | 最终关闭确认 |

## Notion 视图建议

在 Bug 追踪库中，可通过以下方式按 Sprint 维度追踪：
- **过滤器**：`Sprint = 当前 Sprint`
- **分组**：按`严重程度`分组
- **筛选**：`状态 ≠ Closed` 查看待处理 Bug

## 完成标准

- ✅ 测试报告已创建
- ✅ 所有 Bug 已录入并分级
- ✅ `complete_task` 已调用（done 或 failed）
