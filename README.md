# Matrix Recording App

> 简单、易用、健壮的手机录音 App —— 录制后自动上传到服务器。

## Status

🚧 **早期阶段** —— 仓库刚初始化，技术栈待定。工作流脚手架已就位（FIXEDFLOW-lite，详见 [`docs/FIXEDFLOW.md`](docs/FIXEDFLOW.md)）。

## 目标体验

- 一键开始录音，UI 不超过 3 个操作就能完成「录制 → 停止 → 自动上传」
- 弱网 / 断电 / 退到后台不会丢录音
- 后台续传：录制结束如果上传未完成，下次打开继续传
- 用户能看见每条录音的"已上传 / 上传中 / 失败"状态

## 待决定（前 3 个 ADR 候选）

| Decision | Options | Owner |
|----------|---------|-------|
| 移动端框架 | Flutter / React Native / 原生（iOS Swift + Android Kotlin） | TBD |
| 上传服务器协议 | HTTP(S) 直传 / 对象存储预签名 URL / 自建协议 | TBD |
| 后端形态 | Serverless / 长驻服务 / 复用现有 | TBD |

技术栈选定后写到 `docs/adr/0003-mobile-framework.md`、`0004-upload-protocol.md`。

## How we work

本项目用 **FIXEDFLOW-lite** 工作流：

1. 提交 **≤50 字** issue（用 `[fixedflow]` 模板）
2. 跑 `/grill-me` 把 issue 烤透，把结果作为评论贴回 issue + 加 `grill-ready` label
3. maintainer 在 Claude Code 里跑 `/fixed-flow-driver <N>`：开 worktree → 实现 → `/review` 循环 → 普通 PR → squash-merge

完整规则见 [`docs/FIXEDFLOW.md`](docs/FIXEDFLOW.md)。24 小时内未加 `grill-ready` 的 issue 会被 [issue-conformance workflow](.github/workflows/issue-conformance.yml) 自动 close。

## Repository layout

```
.
├── CLAUDE.md            # Claude Code / Codex 在本仓库里的工作约定
├── AGENTS.md            # 同上的指针
├── DESIGN.md            # 视觉 / 交互设计（占位）
├── .github/
│   ├── ISSUE_TEMPLATE/  # FIXEDFLOW issue 模板（仓库唯一）
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── workflows/       # CI（issue-conformance 等）
├── .githooks/           # git hooks（用 scripts/install-hooks.sh 启用）
├── docs/
│   ├── FIXEDFLOW.md     # 工作流入口
│   ├── COMMIT-FLOW.md   # 改动 → commit → PR → merge
│   ├── PR-PLAN.md       # PR 开了之后发现问题怎么修
│   ├── ISSUE-LIFECYCLE.md
│   ├── BEFORE-MERGE.md
│   ├── ISOLATED-WORKTREE.md
│   ├── adr/             # Architecture Decision Records
│   └── plans/           # PR-PLAN 文档（每个 PR 一份）
└── (源代码 / app 子目录待技术栈选定后加)
```

## 启用 git hooks

```bash
git config core.hooksPath .githooks
```

## License

TBD
