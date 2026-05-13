# COMMIT-FLOW — 从改动到 main 的标准节奏

```text
        ┌───────────────────┐
        │ Write / Edit file │
        └─────────┬─────────┘
                  │
                  v
    ┌─────────────────────────────┐
    │ atomic commit (single       │
    │ concern per commit)         │
    └─────────────┬───────────────┘
                  │ N commits, single-concern each
                  v
        ┌─────────────────┐
        │  open normal PR │  (NOT draft)
        └────────┬────────┘
                 │
                 v
        ┌─────────────────┐
        │  /review loop   │  local skill is the gate
        └────────┬────────┘
                 │ PASS
                 v
        ┌─────────────────────────────────────┐
        │ gh pr merge <N> --squash            │  squash-only
        │ POSTPR cleanup (worktree + main)    │
        └─────────────────────────────────────┘
```

## 1. Atomic commit per file edit

每个 `Write` / `Edit` 之后**立即**做一次 commit，**一个 commit = 一个单一关注点**。不要：

- 等到 session 末尾才 "git add ."
- 把"加功能 + 改样式 + 顺手 rename"塞进一个 commit
- 复用上一个 commit 的 message 模糊 amend

为什么：`git revert` / `git blame` / `git bisect` 都靠原子 commit 才有粒度。PR review 看到一堆混合关注点的 commit 等于没法 review。

## 2. Commit message 格式

```
<type>(<scope>): <subject>
```

- `type` ∈ `feat / fix / refactor / docs / chore / test / perf / build / ci`
- `scope` 可省，建议用 milestone 编号或子模块名：`feat(m1): wire up Android record button`
- `subject` 小写、一行 ≤ 72 字、不要句号

例：

```
feat(record): start/stop button + audio capture stub
fix(upload): retry on 429 with exponential backoff
docs: pin FIXEDFLOW-lite as the only workflow
chore: bump android gradle plugin
```

## 3. PR 必须是普通 PR

**禁** `--draft`、禁 GitHub UI 的 draft 切换。理由：agent 容易把 draft PR 当"完成"声明出来；逼自己开 normal PR 是逼自己面对真实 review surface。

## 4. `/review` 是 review gate

本地 `/review` skill 是权威 review gate（不是 cloud Codex bot、不是"我自己读一遍觉得 OK"）。循环：`/review` → 修 → `/review` → 修 → ... 直到 PASS。

如果 `/review` 找到 finding：
- **严禁**开 follow-up issue 然后把当前 PR merge 掉
- 改成在 `docs/plans/<date>-pr-<N>-fix-plan.md` 写 PR-PLAN（三段：task / expected outputs / how-to-verify），push fix 到同一个 PR branch，重跑 `/review`
- 详见 [`PR-PLAN.md`](PR-PLAN.md)

## 5. Squash-merge only

```bash
gh pr merge <N> --squash --delete-branch
```

**禁** `--merge`、**禁** `--rebase`。理由：

- `--merge` 在 main 留 merge commit，`git log --oneline main` 杂乱
- `--rebase` 失去"这一坨改动属于哪个 PR"的语义边界

squash 之后 main 上每个 PR 就是一个 commit，PR title / body 写在 commit message 里，可读、可 revert、可 bisect。

## 6. POSTPR cleanup（三步）

merge 成功后**必须**：

1. `ExitWorktree action="remove"`（手动 worktree 用 `git worktree remove --force <path>` + `git branch -D <branch>`）
2. 回父 checkout
3. `git pull --ff-only` 同步本地 main

漏第 3 步会导致下一个 worktree 从一个旧 main 开分支，制造 rebase 噩梦。

## 7. Quick checklist

- [ ] 每个文件改动 atomic commit
- [ ] commit message 符合 `<type>(<scope>): <subject>` 格式
- [ ] `gh pr create` 不带 `--draft`
- [ ] 本地 `/review` 跑过且 PASS
- [ ] `gh pr merge --squash --delete-branch`
- [ ] worktree 已清理，本地 main 已 `git pull --ff-only`
