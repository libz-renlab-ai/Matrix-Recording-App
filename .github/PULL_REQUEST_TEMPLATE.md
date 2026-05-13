<!-- PR 模板 — 详见 docs/PR-PLAN.md 与 docs/COMMIT-FLOW.md -->

Closes #<!-- issue 编号 -->

## What

<!-- 一句话说本 PR 做了什么。直接说"加了什么"或"修了什么"，不要 paraphrase issue。 -->

## Why

<!-- 为什么要这样做。引用 issue 里的 grill 评论或对应 ADR。 -->

## How to verify (judge harness)

<!-- 三段 PR-PLAN 的"how-to-verify"段 — 具体可运行的检查清单。-->

- [ ] <!-- 例：录音功能在飞行模式下不丢数据（断网录 30s → 关飞行 → 自动续传 → 服务端校验 hash） -->
- [ ] <!-- 例：3 次连续录音/上传循环都成功 -->

## Risk / Rollback

<!-- 如果合并后出问题怎么回滚？影响哪些用户？是否需要 feature flag？-->

## Checklist

- [ ] 每个文件改动是 atomic commit（一个 commit 一个关注点）
- [ ] 本地跑过 `/review` 至 PASS
- [ ] 影响 ADR-level 决策的改动已在 `docs/adr/` 写了 ADR
- [ ] PR 不是 draft
- [ ] 准备用 `gh pr merge <N> --squash --delete-branch` 落地

<!-- 发现问题需要修？严禁开 follow-up issue 然后 merge。
     按 docs/PR-PLAN.md：在 docs/plans/<date>-pr-<N>-fix-plan.md 写 PR-PLAN，
     push fix commits 到同一个 branch，重跑 /review 至 PASS。 -->
