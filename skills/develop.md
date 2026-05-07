# develop.md — 开发任务（DEVELOP 阶段）

适用场景：`get_next_work()` 返回 `phase: "DEVELOP"`。

## 前置条件检查（认领之前）

在调用 `claim_task()` 之前，验证以下条件：

1. 代码库可读写：`git status` 不报错
2. 测试命令可运行：执行项目测试套件，基线全部通过

**任意条件不满足时，立即调用：**

```
return_task(task_id, "无法开始：<原因>（如：git 状态异常 / 基线测试 N 个失败）")
```

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

```
complete_task(task_id, "done", notes)
```

`notes` 格式（每次必须包含这三项）：

```
【做了什么】一句话说明本次完成的工作内容
【结果如何】成功/部分完成/失败，关键指标（如：PR #42 已创建，测试覆盖率 87%）
【遗留问题】无 / 有（具体说明）
```

**任务失败时**：

```
complete_task(task_id, "failed", "【做了什么】...\n【结果如何】失败，<原因>\n【遗留问题】<具体说明>")
```

## 遇到无法继续的情况

在执行过程中如果发现无法继续，调用：

```
return_task(task_id, "<问题类型>：<具体说明>")
```

常见原因示例：
- `缺少环境变量：SOME_API_KEY 未设置`
- `依赖缺失：需要 PostgreSQL 但本地未安装`
- `需求不明确：验收标准存在冲突，需人工确认`

退还是无损操作。任务退还次数达到阈值（默认 3 次）后自动变为 Blocked，需人工介入。
