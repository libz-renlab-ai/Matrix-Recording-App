# BEFORE-MERGE — squash-merge 前的最后检查

`gh pr merge <N> --squash --delete-branch` 之前，driver / maintainer 必须确认以下全部为真。任何一条不满足都不准 merge。

## Pre-merge 检查表

### Code

- [ ] 每个文件改动是 atomic commit，commit message 符合 `<type>(<scope>): <subject>`
- [ ] PR 不是 draft
- [ ] PR description 写了 `Closes #<issue-N>`（让 issue 自动 close）
- [ ] PR 不引入未声明的依赖（package.json / pubspec.yaml / Podfile / build.gradle）
- [ ] 改动超过 200 行的文件已经在 grill 评论或 PR description 里 outline 过

### Review

- [ ] 本地 `/review` 跑过且 PASS（不是 GitHub UI 上点 approve）
- [ ] 如果 `/review` 找到 finding，已经写了 `docs/plans/<date>-pr-<N>-fix-plan.md` 并 push 修复
- [ ] CI 全绿（issue-conformance workflow 不阻塞 merge，但其他 CI 必须绿）

### Decision integrity

- [ ] 引入 / 改变了架构 / 框架 / 协议 → 已写 ADR 在 `docs/adr/`
- [ ] 改了 user-facing 行为（录音 UX / 上传流程）→ DESIGN.md 已同步
- [ ] 改了工作流（CLAUDE.md / FIXEDFLOW.md / hooks / workflows）→ CHANGELOG（如果存在）已写

### Cross-host hygiene

- [ ] issue 上已有 `grill-working` label 且持锁人是自己
- [ ] 没有别的 driver 在并行做这个 issue（`gh pr list --search "issue-<N>"` 只看到自己的 PR）

### Anti-pattern check

- [ ] **没有**用 follow-up issue 把当前 PR 的问题留到下一轮
- [ ] **没有**用 `--no-verify` 跳过 pre-commit hook
- [ ] **没有**force-push 到 main / 抹掉 commit history
- [ ] **没有**把测试 `xfail` / `.skip` 然后说"先 merge 再修"

## Merge command

```bash
gh pr merge <N> --squash --delete-branch
```

**禁** `--merge`、**禁** `--rebase`。理由见 [`COMMIT-FLOW.md`](COMMIT-FLOW.md) §5。

## Merge 失败处理

```bash
# 1. rebase 重试
git fetch origin
git rebase origin/main
git push --force-with-lease
gh pr merge <N> --squash --delete-branch

# 2. 还是失败？看是不是 branch protection / 缺 reviewer 批准
gh pr view <N> --json mergeStateStatus,mergeable
```

## After merge — POSTPR cleanup（强制三步）

1. `ExitWorktree action="remove"`（或手动 `git worktree remove --force <path>` + `git branch -D <branch>`）
2. 回父 checkout
3. `git pull --ff-only` 同步本地 main

漏第 3 步会让下一个 worktree 从旧 main 起分支，制造 rebase 噩梦。
