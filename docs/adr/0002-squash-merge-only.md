# ADR-0002: Squash-merge only on main

- **Date**: 2026-05-13
- **Status**: Accepted
- **Deciders**: libz-renlab-ai

## Context

GitHub 允许仓库设置三种 merge：merge commit、rebase merge、squash merge。本仓库刚 init，需要在第一个 PR 之前定下来。

我们的工作流（[ADR-0001](0001-adopt-fixedflow-lite.md)）要求：
- 一个 issue → 一个 PR → main 上一段独立可回滚的改动
- `git log --oneline main` 应能一行一个 PR
- 出问题能用 `git revert` 单条逆转

## Decision

**只允许 squash-merge**。GitHub 仓库设置：

- ✅ `allow_squash_merge: true`
- ❌ `allow_merge_commit: false`
- ❌ `allow_rebase_merge: false`
- ✅ `delete_branch_on_merge: true`
- ✅ `squash_merge_commit_message: COMMIT_MESSAGES`
- ✅ `squash_merge_commit_title: COMMIT_OR_PR_TITLE`

Merge 命令固定为：

```bash
gh pr merge <N> --squash --delete-branch
```

**禁** `--merge`、**禁** `--rebase`、**禁** GitHub UI 上的非 squash 选项。

## Alternatives considered

| Option | Why rejected |
|--------|--------------|
| Merge commit | main 上充满 "Merge pull request #N" 噪音；`git log --first-parent main` 才看得清 |
| Rebase merge | 失去 "这一坨改动属于哪个 PR" 的语义边界；多 commit PR rebase 后 commit message 散落 |
| 允许三种由 author 选 | 历史会变成混合 style，未来 grep / bisect / blame 时心智成本累加 |

## Consequences

- ✅ `git log --oneline main` 一行一个 PR，可读
- ✅ `git revert <sha>` 单条逆转一个完整 feature / fix
- ✅ `git bisect` 精度到 PR 级
- ❌ PR 内的 atomic commit history 丢在 main（但保留在 PR / GitHub 的 Files Changed history 里）
- ❌ 长生命周期 branch 需要主动 `git rebase origin/main` 跟上（merge 不会自动给你 fast-forward 路径）

## Note on the trade-off

PR 内的 atomic commit history（一个文件改动一个 commit）在**审 PR 时**很有用 —— reviewer 能一个 commit 一个 commit 读。但 squash 后这个 history 不进 main。这是我们故意的选择：

- atomic commit 的价值在 PR review 阶段，不是 main 历史阶段
- main 历史的价值是"一行一个 PR"的可读性，不是"一行一个 file edit"

PR squash 时 GitHub 自动把所有 commit message 拼到 squash body，所以 atomic history 不会丢失，只是从 main 的 first-parent 上消失。需要时可以 `gh pr view <N> --json commits` 拿回。

## References

- TeamBrain `feedback_squash_only_merge.md` user-level memory（同一思路）
- 本仓库 [`docs/COMMIT-FLOW.md`](../COMMIT-FLOW.md) §5
- 本仓库 [`docs/BEFORE-MERGE.md`](../BEFORE-MERGE.md)
