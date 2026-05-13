# Matrix Recording App — 工作约定

本文件给 Claude Code / Codex / Cursor / 任何 AI coding assistant 读 —— 在本仓库内工作时必须遵守以下约定。

> **借鉴自 [TeamBrain](https://github.com/libz-renlab-ai/TeamBrain) 的 FIXEDFLOW 工作流，做了"轻量化"裁剪：单 driver、单道 grill gate、单 issue template。**

## 1. 项目目标

简单、易用、健壮的手机录音 App。核心 user-facing 体验：

1. **一键录音**：不超过 3 次点击完成「开始录 → 停止 → 自动上传」。
2. **零数据丢失**：弱网 / 断电 / 退到后台 / 进程被杀 都不能丢已录好的录音。
3. **可见上传状态**：每条录音都有"已上传 / 上传中 / 失败"明确标记。

任何 issue / PR 不能让上面 3 件事退步。设计决策有冲突时，**鲁棒性 > 简洁 > 性能**。

## 2. 工作流（FIXEDFLOW-lite）

仓库唯一允许的 issue → PR → merge 路径：

| Step | 谁做 | 怎么做 |
|------|------|--------|
| 1 | 任何人 | 用 `[fixedflow]` issue 模板提 **≤50 字** issue |
| 2 | 任何人 | 跑 `/grill-me` 或 `/grill-via-web` 把 issue 烤透；把整段输出贴到 issue 评论；评论末尾以 `--- end grill ---` 结束；最后给 issue 加 `grill-ready` label |
| 3 | maintainer | 看到 `grill-ready` 后**手动**在 Claude Code 里跑 `/fixed-flow-driver <issue-N>` |
| 4 | driver 内部 | 开 `.codex/worktrees/issue-<N>/` worktree、`feat/issue-<N>` 分支；按 grill 评论实现；每个文件改动单独 commit |
| 5 | driver 内部 | 跑 `/review` skill 循环 fix 至 PASS；然后 `gh pr create`（普通 PR，**禁 draft**）+ `gh pr merge --squash --delete-branch` |
| 6 | driver 内部 | `ExitWorktree action="remove"` + `git pull --ff-only` 同步父 checkout |

完整规则：[`docs/FIXEDFLOW.md`](docs/FIXEDFLOW.md)。
24 小时内未加 `grill-ready` 的 issue 会被 [issue-conformance workflow](.github/workflows/issue-conformance.yml) 自动 close。

## 3. Commit / PR / merge 节奏

**铁律**：每个 `Write` / `Edit` 之后**立即**做一次 atomic commit，**一个 commit = 一个单一关注点**。不要等到 session 结束才批量 commit。

完整顺序：

1. **Atomic commits**：每改一个文件做一次 commit，message 用 `feat: / fix: / refactor: / docs: / chore: / test:` 前缀
2. **普通 PR**：`gh pr create`，**不要** `--draft`
3. **`/review` 循环**：本地 `/review` skill 是 review gate，**禁止**靠"我自己觉得没问题"或 cloud Codex bot 直接 merge
4. **Squash-merge only**：`gh pr merge <N> --squash --delete-branch`，**禁止** `--merge` 和 `--rebase`
5. **POSTPR cleanup**：merge 完 `ExitWorktree action="remove"`（或手动 `git worktree remove --force`），回父 checkout 跑 `git pull --ff-only`

完整 playbook：[`docs/COMMIT-FLOW.md`](docs/COMMIT-FLOW.md)。

## 4. PR 已开后发现问题怎么办

**严禁**开 follow-up issue 然后 merge 当前 PR 把问题留到下一轮。

正确做法：
1. 在 `docs/plans/<date>-pr-<N>-fix-plan.md` 写一份 PR-PLAN（三段：task / expected outputs / how-to-verify）
2. 在同一个 PR branch 上 push fix commits
3. 重新跑 `/review` 至 PASS
4. 再 squash-merge

完整规则：[`docs/PR-PLAN.md`](docs/PR-PLAN.md)。

## 5. ADR — 架构决策记录

任何会影响后续多人 / 多 PR 的决策都必须写到 `docs/adr/<seq>-<slug>.md`。前 3 个 ADR 候选见 [`README.md`](README.md) 的"待决定"表。

ADR 写法：[`docs/adr/README.md`](docs/adr/README.md)。

## 6. 隔离 worktree — 跨 PR 不撞车

每个 issue / PR 都在自己的 worktree 里干活，主 checkout 永远干净：

- driver 自动开 `.codex/worktrees/issue-<N>/`
- 手动开发可用 `git worktree add -b feat/issue-<N> .codex/worktrees/issue-<N>/`
- 完成后用 `ExitWorktree action="remove"`

完整规则：[`docs/ISOLATED-WORKTREE.md`](docs/ISOLATED-WORKTREE.md)。

## 7. 跨主机 / 跨 driver 互斥

防两台机器、两个 driver 同时认领同一个 issue：

- **Grill 阶段**：动手前 `gh issue edit <N> --add-label grilling`；看到已有 `grilling` 就礼让退出
- **Implement 阶段**：driver 在写 worktree 前必须先 `gh issue edit <N> --add-label grill-working` + 贴 claim 评论
- 看到 `grill-working` label 已存在 → **不抢、不强删**，立即退出

## 8. 安全 / Secrets

- **绝不**把 token / API key / 服务账号 commit 到仓库。GitHub 已开启 secret_scanning_push_protection。
- 配置走环境变量或 `.env`（已在 `.gitignore`），不进 git。
- 录音上传 endpoint / bucket name 这种敏感配置走构建期注入，不写死。

## 9. 关于 AI agent 的额外约束

- 不准创建非必要的文档（`*.md` / README）。本仓库的 doc 集是有意挑选的，新增 doc 必须先在 PR 里说明加这条的理由。
- 不准在没有 ADR 的前提下引入新的依赖、新框架、新协议。
- 改动一个文件超过 200 行，必须先在 issue / PR 评论里 outline 一次再动键盘。

## 10. 相关全局 skill（你的 Claude Code 应该已经装好）

- `/grill-me` — 一题一题问透一个 plan / issue
- `/grill-via-web` — 把 grill 推到 ChatGPT / Claude.ai 跑
- `/fixed-flow-driver <N>` — step 3-6 的自动驾驶
- `/claim-to-merge` — 手动补救入口（driver 卡住时人手接上）
- `/review` — pre-landing PR review，本地权威 gate
- `/office-hours` — 早期 brainstorm，用于"该不该做这个 feature"
- `/ship` — 走 commit / PR / push 标准流程

如果某个 skill 你不熟，跑 `/help` 或读它的 description。
