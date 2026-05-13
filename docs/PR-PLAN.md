# PR-PLAN — PR 开了之后发现问题怎么修

> **Hard rule**：严禁开 follow-up issue 然后 merge 当前 PR 把问题留到下一轮。
> 找到的问题必须在**同一个 PR** 里修完，再 squash-merge。

## 触发场景

- `/review` 在 PR 上找到 P1 / P2 finding
- CI 失败 / 测试 flake
- 自测发现 regression
- Reviewer（人或 codex）提出实质性意见

任何一种触发 → 写一份 PR-PLAN，**不要**关 PR、不要开 follow-up issue。

## PR-PLAN 文档位置

```
docs/plans/<YYYY-MM-DD>-pr-<N>-<slug>.md
```

例：`docs/plans/2026-05-13-pr-12-upload-retry-fix.md`

## PR-PLAN 三段铁律

每份 PR-PLAN 必须包含且**只**包含以下三段：

### 1. Task

具体要修什么？引用 `/review` 评论行号 / CI 失败截图 / 自测复现命令。一段 ≤ 5 行。

### 2. Expected outputs

修完后**可观察**的指标 / 行为：

- 文件 X 多了函数 Y，处理 Z case
- 命令 `pnpm test` / `flutter test` / `xcodebuild test` 输出 0 fail
- 复现命令 `<cmd>` 输出从"上传失败"变成"成功"

不要写"代码质量更好"这种无法验证的话。

### 3. How to verify (judge harness)

一段**可运行的**检查清单：

```bash
# 例：
$ flutter test test/upload_retry_test.dart
$ adb shell input keyevent 4   # 后台 app
$ ./scripts/verify-no-data-loss.sh
```

如果某条 verify 还没有自动化脚本，**先写 verify 脚本，再写 fix 代码**。

## 修完之后

1. **Push fix commits 到同一个 PR branch**（atomic commits，单一关注点）
2. **重跑 `/review`**
3. PASS → `gh pr merge <N> --squash --delete-branch`
4. POSTPR cleanup（[`COMMIT-FLOW.md`](COMMIT-FLOW.md) §6）

## Anti-patterns

| 反模式 | 为什么不行 |
|--------|------------|
| 开 follow-up issue 然后 merge | 留 tech debt；review 漏掉的东西永远没修 |
| 在 PR 评论里写 "will fix in follow-up" | 同上；GitHub history 一年后没人记得 |
| 覆盖性 `git push --force` 抹掉 fix history | 失去"先写错→修对"的学习信号；reviewer 重读时丢失上下文 |
| 把 fix 塞进一个 mega commit `--amend` | 失去 atomic commit 粒度 |

## 为什么不能开 follow-up

- 单 PR 应能 squash 成 main 上"一段独立的、可回滚的改动"。fix 留在下一个 PR = 下一个 PR 既要做新事情又要扫旧账，永远在打补丁
- "follow-up" 通常永远不会发生。看 GitHub 上任何项目 `is:issue label:follow-up` 的 stale 比例

## 为什么是 PR-PLAN 文档而不是 PR 评论

- PR 评论会被新 commit / 旧 review iteration 淹掉
- `docs/plans/` 是 git-tracked artifact，跟 PR 一起 merge 进 main，事后可被 grep 出来
