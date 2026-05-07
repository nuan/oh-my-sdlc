# monitor.md — 监控检查（MONITOR 阶段）

适用场景：`get_next_work()` 返回 `phase: "MONITOR"`。

监控检查由 `get-next-work.sh` 根据 `.sdlc/config.json` 中 `monitor.interval_hours` 定时触发。

## 前置条件检查（认领之前）

验证基础网络可用（不是健康检查本身，是网络连通性）：

```bash
url=$(jq -r '.monitor.checks[] | select(.type=="http") | .url' .sdlc/config.json | head -1)
if [ -n "$url" ]; then
  status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" || echo "000")
  if [ "$status" = "000" ]; then
    return_task "$task_id" "网络不可达：无法连接到 $url（非健康问题，是本机网络问题）"
    exit 0
  fi
fi
```

**注意：HTTP 非 200 响应是监控发现的问题，不是前置条件失败——应继续执行，让 monitor-check.sh 记录该发现。**

## 执行监控

调用 `claim_task()` 认领后，执行：

```bash
bash scripts/monitor-check.sh
```

`monitor-check.sh` 会自动：
1. 执行所有配置的检查项（HTTP 健康检查、自定义脚本）
2. 将结构化 findings 写入 Notion 监控日志库
3. 对每个发现的问题，在需求库自动创建 Inbox 条目（来源：Monitor）

## 完成任务

脚本正常退出后：

```
complete_task(task_id, "done",
  "【做了什么】执行监控检查，共 <N> 个检查项\n【结果如何】完成，发现 <N> 个问题，已写入需求库\n【遗留问题】无")
```

脚本本身报错（非监控到问题，是脚本执行失败）：

```
complete_task(task_id, "failed",
  "【做了什么】执行监控检查\n【结果如何】失败，脚本报错：<error>\n【遗留问题】需排查 monitor-check.sh")
```
