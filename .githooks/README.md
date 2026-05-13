# Git hooks

## 启用

```bash
git config core.hooksPath .githooks
```

一次性，对当前 clone 生效。

## 内容

- **`pre-commit`** — staged diff 里发现 token / 私钥模式 / >5MB 大文件 / 本地状态文件就阻断。Escape: `MATRIX_PRECOMMIT_SKIP=1 git commit ...`

## 跳过

```bash
# 跳过一次
MATRIX_PRECOMMIT_SKIP=1 git commit -m "..."

# 但 --no-verify 是绕过整个 hook，慎用，且不允许在 CI / 共享分支上用
```

## 借鉴

骨架借鉴自 [TeamBrain `.githooks/pre-commit`](https://github.com/libz-renlab-ai/TeamBrain/blob/main/.githooks/pre-commit)，但去掉了 TeamAgent CLI 依赖。
