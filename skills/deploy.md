# deploy.md — 部署任务（DEPLOY 阶段）

适用场景：`get_next_work()` 返回 `phase: "DEPLOY"`。

部署任务由 `complete-task.sh` 在当前 Sprint 到期时自动创建，无需人工触发。

## 前置条件检查（认领之前）

读取 `.sdlc/config.json` 中的 `deploy.method`，验证对应凭证：

| deploy.method    | 必须满足的条件                                           |
|----------------|------------------------------------------------------|
| github-actions | 已通过 `gh auth status` 验证，或 `GITHUB_TOKEN` 已设置 |
| script         | `DEPLOY_TOKEN` 或 `DEPLOY_SSH_KEY_PATH` 已设置         |
| manual         | 无（但会立即 return_task，不执行部署）                   |

**凭证缺失时**：

```
return_task(task_id, "缺少部署凭证：DEPLOY_TOKEN 或 DEPLOY_SSH_KEY_PATH 未设置")
```

## 部署流程

### method: "github-actions"

```bash
trigger=$(jq -r '.deploy.trigger' .sdlc/config.json)
gh workflow run "$trigger" --ref main
run_id=$(gh run list --workflow="$trigger" --limit=1 --json databaseId -q '.[0].databaseId')
gh run watch "$run_id"
conclusion=$(gh run view "$run_id" --json conclusion -q '.conclusion')
```

`conclusion == "success"` → `complete_task(..., "done", ...)`
`conclusion != "success"` → `complete_task(..., "failed", ...)`

### method: "script"

```bash
deploy_script=$(jq -r '.deploy.script' .sdlc/config.json)
bash "$deploy_script"
# 退出码 0 → done，非 0 → failed
```

### method: "manual"

```
return_task(task_id, "部署方式为 manual，需要人工操作后手动将任务标记完成")
```

## 完成任务

```
complete_task(task_id, "done",
  "【做了什么】触发 <method> 部署\n【结果如何】成功，run #<id>\n【遗留问题】无")

complete_task(task_id, "failed",
  "【做了什么】触发 <method> 部署\n【结果如何】失败，<错误信息>\n【遗留问题】<具体问题>")
```
