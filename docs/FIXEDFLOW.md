# FIXEDFLOW-lite — 本仓库唯一允许的 issue → PR → merge 工作流

```
 step 1 (任何人)    step 2 (任何人)            steps 3-6 (maintainer 跑 skill)
 ──────────────     ─────────────────────      ──────────────────────────────
 ≤50 字 issue ──▶  /grill-me 或 /grill-via-web ──▶ /fixed-flow-driver <N>
  via 唯一           把整段 grill 输出贴            │
  issue template     到 issue 评论                  ├─ 开 worktree
                     末尾 --- end grill ---         ├─ 按 grill 评论实现
                     + 加 grill-ready label         ├─ /review loop 至 PASS
                                                    ├─ 普通 PR（禁 draft）
                                                    └─ gh pr merge --squash

 refusal layer：非此模板 / 超 50 字 / 24h 内无 grill-ready 一律 close
 禁止任何 watcher / cron / 后台轮询 / 自动 dispatch
 step 3-6 必须由人手动 invoke
```

> **借鉴自 [TeamBrain FIXEDFLOW](https://github.com/libz-renlab-ai/TeamBrain/blob/main/docs/FIXEDFLOW.md)，做了以下裁剪以适应本仓库的早期阶段：**
> - 单 driver（去掉 Symphony 双 driver）
> - 单道 grill gate（暂不强制 `/grill-with-docs` 二次 docs gate，等 docs 体量起来再加）
> - 单 issue template

## TL;DR — 5 步铁律

1. **写 issue（≤50 字）** — 用本仓库唯一的 `[fixedflow]` template 提交。body 限 50 字。
2. **跑 grill** — `/grill-me`（Claude Code CLI）或 `/grill-via-web`（ChatGPT / Claude.ai）。**动手前**先 `gh issue edit <N> --add-label grilling` 加锁；看到 `grilling` 已存在 → 礼让退出。跑完把整段输出贴回 issue 评论，末尾以 `--- end grill ---` 结束，然后 `gh issue edit <N> --remove-label grilling --add-label grill-ready` 换 label。
3. **手动起 driver** — maintainer 看到 `grill-ready` 后在 Claude Code 里跑 `/fixed-flow-driver <N>`。driver 起来后**先**校验：(a) 有 grill 评论 + `grill-ready` label。任一缺失 → 立即退出、贴评论说明缺哪一道。
4. **/review 循环（driver 内部自动 — never ends）** — driver 跑 `/review`，发现 finding 更新 `docs/plans/<date>-pr-<N>-fix-plan.md` 并修；**只有 PASS 能终止 driver**。
5. **开 PR + squash-merge** — `gh pr create`（**普通 PR，非 draft**）→ `gh pr merge <N> --squash --delete-branch`。失败 → rebase 重试。merge 成功后 `ExitWorktree action="remove"` + `git pull --ff-only`。

## Dispatch 策略 — 只 driver 已 grilled 的 issue

driver 仅在 issue 同时具备 (a) 有效 grill 评论 + (b) `grill-ready` label 时才能动手。所有 dispatch 都是**手动**，由人在 Claude Code session 里 invoke。

- ✅ grilled issue + `grill-ready` 在 → 人 `/fixed-flow-driver <N>`
- ❌ blank / 非 fixed-flow template
- ❌ 24h 内无 `grill-ready`（→ issue-conformance workflow 自动 close）
- ❌ 任何 watcher / cron / daemon / 后台轮询 / 自动 dispatch
- ❌ retroactive label（后补的 `grill-ready` 必须确实有 grill 评论支撑）

## Claim an issue — 2-outcome contract

「Claim」= maintainer 决定要不要跑 `/fixed-flow-driver`。结局只有两种：

1. **Gate missing → driver 起来即退** — 没有 grill 评论 / 没有 `grill-ready` → 不开 worktree、不动代码、不开 PR；回评说明缺哪一道，立即退出。
2. **Gate set → driver 一路跑到 squash-merge** — 满足条件后 driver 全程：建 `.codex/worktrees/issue-<N>/` → 按 grill 评论实现 → `/review` fix loop 至 PASS → **普通** PR（`--draft` 严禁）→ `gh pr merge --squash --delete-branch` → POSTPR cleanup。

## Preempted by an existing PR — 2-outcome contract

发现别人已经开了 PR 实现这个 issue：

1. **Review and give up** — 本地跑 `/review` 那个 PR 的 diff；无 P1/P2 finding → 放弃自己的 PR，让那条 PR 去 squash-merge。**不开重复 PR**。
2. **Append fix + /review loop** — `/review` 找到 P1/P2 finding → **严禁**另开 follow-up PR。在 `docs/plans/<date>-pr-<n>-fix-plan.md` 写 PR-PLAN，push fix commits 到**那个 PR 的同一 branch**，基于那个 PR 循环 `/review` 至 PASS，再 squash-merge 那个 PR。

简记：**一个 issue → 一个 squash-merged PR**。永远不并行两条线。

## 跨主机互斥（PRE-IMPLEMENT-CLAIM）

driver 进 worktree / 写代码 / push 之前**必须**：

1. `gh issue comment <N>` 写一条 claim 评论（含 hostname / branch / ISO timestamp）
2. `gh issue edit <N> --add-label grill-working`

第二个 driver 看到 `grill-working` 已存在 → **立即礼让退出，不抢、不强删**。merge 成功后 driver 自己 `--remove-label grill-working`。`grill-working` ≥ 24h 无 progress 才算 stale，由 maintainer 手动 evict。

## Issue body 字数（含 CJK）

issue-conformance workflow 用 `re.findall(r"[一-鿿㐀-䶿]", body)` 数 CJK 字符 + ASCII 词。任一种 > 50 都触发 warn / close。详情见 [`.github/workflows/issue-conformance.yml`](../.github/workflows/issue-conformance.yml)。

启用模式：仓库变量 `FIXEDFLOW_ENFORCEMENT`：

- `warn`（默认）— 仅评论提醒，不 close
- `enforce` — 评论 + close

前 7 天建议 `warn` 跑跑看再切 `enforce`。

## 紧急绕过

`bypass-fixed-flow` label（仅 admin 权限可加）会跳过所有 conformance 检查。followup workflow 会校验 actor 权限；非 admin 加了立即被剥。

## 为什么这套工作流

- **Issue 限 50 字** —— 强制把工作拆到 PR 级颗粒度，反"巨型 ticket"
- **Grill 前置** —— 把"我想做 X" 翻译成"我具体要哪些 expected outputs、怎么验证"，在写代码前就找到决策点
- **/review 循环** —— 人工评审会偷懒；本地 skill 不会
- **Squash-merge only** —— `git log --oneline main` 一行一个 PR，可读、可 revert、可 bisect
- **Worktree 隔离** —— 永远不在主 checkout 上动键盘，并发 PR 互不污染

## 不在本仓库做的（vs TeamBrain）

- ❌ Symphony 自主 driver（autonomous 模式不适合早期 app）
- ❌ `docs-grill-ready` 二道 docs gate（docs 体量起来再加）
- ❌ 复杂的 epic / triage label 分支（本仓库小，到了拆 issue 才补）
- ❌ TeamBrain anchor-sentence 机制（那是 TeamBrain 自己的 product feature）
