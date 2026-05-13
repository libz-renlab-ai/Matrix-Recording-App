# docs/

工作流文档索引。所有文件按"该回答哪个问题"组织。

## 工作流主线（按 issue → merge 时序）

| 文档 | 回答什么 |
|------|----------|
| [`FIXEDFLOW.md`](FIXEDFLOW.md) | 整体工作流：issue → grill → driver → /review → squash-merge |
| [`ISSUE-LIFECYCLE.md`](ISSUE-LIFECYCLE.md) | issue 经过哪些 label 阶段、各阶段什么意思 |
| [`COMMIT-FLOW.md`](COMMIT-FLOW.md) | 改完代码到合并到 main 的标准节奏 |
| [`PR-PLAN.md`](PR-PLAN.md) | PR 开了之后 `/review` 找出问题怎么修（不准 follow-up issue） |
| [`BEFORE-MERGE.md`](BEFORE-MERGE.md) | merge 前的最后检查清单 |
| [`ISOLATED-WORKTREE.md`](ISOLATED-WORKTREE.md) | 每个 issue 一个 worktree、避免主 checkout 污染 |

## 决策记录

| 目录 | 用途 |
|------|------|
| [`adr/`](adr/) | Architecture Decision Records — 每个影响多 PR 的决策 |
| [`plans/`](plans/) | PR-PLAN 文档（每个 PR 一份） |

## 写新 doc 的门槛

新增 `docs/*.md` 必须在 PR 描述里说明：

1. **为什么 README / CLAUDE.md / 现有 doc 装不下**
2. **哪条 trigger 触发后读它**（具体问题或具体工作流阶段）

只为了"看起来比较全"的 doc 不收。这条规则借鉴自 TeamBrain 的反 doc-bloat 实践。
