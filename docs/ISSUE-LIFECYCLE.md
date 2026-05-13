# Issue lifecycle — label 状态机

issue 在 GitHub 上从 open 到 close 经过的 label 阶段。每一阶段都有明确的入口动作和退出条件。

```
   P0 needs-grill-comment     ←─── issue opened (issue template auto-adds)
        │ 
        │ /grill-me 或 /grill-via-web 开始之前：
        │   gh issue edit <N> --add-label grilling
        v 
   P1 grilling                ←─── grill 进行中（PRE-GRILL-CLAIM mutex）
        │ 
        │ grill 完贴评论 + 末尾 --- end grill ---
        │   gh issue edit <N> --remove-label grilling --add-label grill-ready
        v 
   P2 grill-ready             ←─── 可被 driver 认领
        │ 
        │ maintainer 跑 /fixed-flow-driver <N>，driver 先：
        │   gh issue comment <N> --body "claim..."
        │   gh issue edit <N> --add-label grill-working
        v 
   P3 grill-working +         ←─── 实现中（PRE-IMPLEMENT-CLAIM mutex）
      grill-ready
        │ 
        │ driver 跑完 /review loop + PR squash-merge
        │   issue 被 PR "Closes #<N>" 自动 close
        │   driver §last step: gh issue edit <N> --remove-label grill-working
        v 
   P4 CLOSED
```

## 主线 4 个 phase

| Phase | Label 组合 | 谁能动 | 退出条件 |
|-------|-----------|--------|----------|
| **P0** | `needs-grill-comment` + `fixedflow` | 任何人 | grill 完成 |
| **P1** | `grilling` | 已加锁的那个人 | grill 评论贴完 + label swap |
| **P2** | `grill-ready` | maintainer 启动 driver | driver 加 `grill-working` |
| **P3** | `grill-working` + `grill-ready` | 持锁的 driver | PR squash-merge |
| **P4** | （closed） | — | — |

## 旁路 label

| Label | 用途 | 何时贴 | 谁贴 |
|-------|------|--------|------|
| `bypass-fixed-flow` | 跳过 issue-conformance 检查 | 紧急情况 / 大体量讨论 issue | 只 admin 可以 |
| `needs-info` | 等 reporter 补信息 | grill 时发现 issue 描述歧义 | 任何人 |
| `epic` | 跨多 PR 的大块 | issue 拆分时 | maintainer |
| `non-conformant` | 24h 无 `grill-ready` | issue-conformance workflow 自动加 | bot |

## 跨主机互斥

`grilling` 和 `grill-working` 都是**真锁**（GitHub label 是原子查询）。

- 看到 `grilling` 已存在 → 不进入 P1
- 看到 `grill-working` 已存在 → 不进入 P3

**不强删别人的 label**。礼让退出。≥ 24h 无 progress 才视为 stale，由 maintainer 手动 evict。

## 24h 自动 close

`issue-conformance` workflow 每天 09:17 UTC 扫描：

- issue open > 24h
- 没有 `grill-ready` label
- 没有 `bypass-fixed-flow` label
- 没有 `needs-info` label（reporter 还在补信息）

满足以上四条 → 评论提醒 + (enforce 模式下) auto-close。

借鉴自 [TeamBrain `docs/ISSUE-LIFECYCLE.md`](https://github.com/libz-renlab-ai/TeamBrain/blob/main/docs/ISSUE-LIFECYCLE.md)，简化为单 grill gate（去掉 docs-grill-ready P3a/P3b 二道门）。
