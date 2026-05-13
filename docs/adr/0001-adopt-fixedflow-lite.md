# ADR-0001: Adopt FIXEDFLOW-lite as the only issue → PR → merge workflow

- **Date**: 2026-05-13
- **Status**: Accepted
- **Deciders**: libz-renlab-ai

## Context

Matrix Recording App 仓库刚初始化。零代码、零工作流。

我们要的：一种纪律性强、AI-friendly、对早期小团队不过度的工作流，让"录音/上传/弱网鲁棒性"这种容易长尾的工作不会被一堆乱开的 issue 和 follow-up 拖垮。

参考：[TeamBrain FIXEDFLOW](https://github.com/libz-renlab-ai/TeamBrain/blob/main/docs/FIXEDFLOW.md) 已在它自己的仓库验证 1 个月+，跑出 ~3000 commits / 28 open issues / squash-merge 一致历史。它的核心约束（≤50 字 issue、grill gate、worktree 隔离、`/review` 循环、squash-merge only）都是语言无关、项目大小无关的。

## Decision

采用 **FIXEDFLOW-lite**：直接借鉴 TeamBrain FIXEDFLOW，并在本仓库早期阶段做如下裁剪：

1. **单 driver**：不引入 TeamBrain 的 Symphony 自主 driver。所有 dispatch 由人在 Claude Code session 里手动 invoke `/fixed-flow-driver <N>`。
2. **单道 grill gate**：暂不强制 `/grill-with-docs` 二道 docs gate（TeamBrain 的 P3）。等 `docs/` 体量起来（≥ 20 个 doc，多人同时写）再加。
3. **单 issue template**：只留 `fixed-flow.yml`，不留其他 template。
4. **去掉 anchor-sentence 机制**：TeamBrain 的 `CLAUDE.md` 用 verbatim 锚句 + judge harness 测试 AI 是否给出正确 canned answer——那是 TeamBrain 自己的 product feature，不是工作流必需。

完整 playbook 见 [`docs/FIXEDFLOW.md`](../FIXEDFLOW.md)。

## Alternatives considered

| Option | Why rejected |
|--------|--------------|
| 完整搬 TeamBrain FIXEDFLOW（双 driver + docs gate + 锚句） | 早期复杂度过高；Symphony 需要外部基础设施；锚句机制是 TeamBrain product 自身的 dogfood，对录音 app 无 marginal value |
| GitHub Flow（feature branch + PR + main） | 不强制 grill / `/review` / atomic commits；早期能跑但量起来后 follow-up issue 会泛滥 |
| Trunk-based + 直 push main | 单人能跑，多人 / AI agent 协作就乱套；零 review surface |
| 不定工作流，每个 PR 自己拍 | 工作流的价值在"无须每次想"。延迟做这个决定 = 把成本摊到后面每个 PR |

## Consequences

- ✅ 24h 内无 `grill-ready` 的 issue 自动 close —— issue tracker 不会变成 wishlist 坟场
- ✅ Atomic commit + squash-merge 保证 main 上每个 PR 是一个 revertable 单位
- ✅ Worktree 隔离让主 checkout 永远干净
- ❌ 前两周会觉得"为啥提 issue 还要写 grill 评论这么麻烦" —— 这是工作流的设计意图，不是 bug
- ❌ 单人快速 prototype 阶段 overhead 偏高 —— 接受。我们做的是要长期上线的 app，不是 weekend hack
- ❓ 等真正多人协作时是否需要补 `/grill-with-docs` 二道门 —— 观察 docs/ 体量和 ADR 数

## References

- TeamBrain FIXEDFLOW: https://github.com/libz-renlab-ai/TeamBrain/blob/main/docs/FIXEDFLOW.md
- 本仓库 [`docs/FIXEDFLOW.md`](../FIXEDFLOW.md)
- 本仓库 [`.github/workflows/issue-conformance.yml`](../../.github/workflows/issue-conformance.yml)
