# ISOLATED-WORKTREE — 每个 issue 一个 worktree

## 为什么

主 checkout（`C:\bzli\matrix-recording\`）永远干净 = 永远是 origin/main 的精确副本。每个 issue / PR 在自己的 worktree 干活，互不污染：

- 同时开三个 PR 不需要 stash / branch switch
- 主 checkout 永远能跑"latest main"的 build / 测试做基线对比
- driver 异常退出不会把主 checkout 留在脏状态
- POSTPR cleanup 删 worktree 即可，主 checkout 自动回到 origin/main

## 命名

```
<repo>/.codex/worktrees/issue-<N>/           # driver 创建
<repo>/.codex/worktrees/issue-<N>+pr-<i>/    # 同一 issue 多轮 fix（少见）
```

`.codex/worktrees/` 已在 [`.gitignore`](../.gitignore)，不会被 commit。

## 自动开（driver 内部）

`/fixed-flow-driver <N>` skill 内部会跑相当于：

```bash
git worktree add -b feat/issue-<N> .codex/worktrees/issue-<N>/ origin/main
cd .codex/worktrees/issue-<N>/
```

## 手动开（grill 阶段写 plan、或 driver 卡住后人手接）

```bash
git fetch origin
git worktree add -b feat/issue-<N> .codex/worktrees/issue-<N>/ origin/main
cd .codex/worktrees/issue-<N>/

# 干活、commit、push
git push -u origin feat/issue-<N>
```

## 关 worktree

```bash
# 优先：driver / skill 内部
ExitWorktree action="remove"

# Fallback：手动
git worktree remove --force .codex/worktrees/issue-<N>/
git branch -D feat/issue-<N>
# 如果远端 branch 还在（未 merge 不删）
git push origin --delete feat/issue-<N>
```

## 边界规则

- **禁** 在主 checkout 上直接开 `feat/issue-<N>` 分支干活
- **禁** 在 `.codex/worktrees/issue-<X>/` 里干 issue-`<Y>` 的事
- **禁** 把 worktree 路径 commit 到 git（path 是本地 layout，不是 repo content）

## 借鉴

骨架来自 [TeamBrain `docs/ISOLATED-WORKTREE.md`](https://github.com/libz-renlab-ai/TeamBrain/blob/main/docs/ISOLATED-WORKTREE.md)。
