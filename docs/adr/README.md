# Architecture Decision Records

每个会影响**多个 PR** 的决策都要写一份 ADR。ADR = "我为什么这么决定，当时有哪些 alternatives，权衡是什么"。

## 何时写

写 ADR 的触发：

- 引入 / 替换框架（如选 Flutter vs React Native）
- 引入 / 替换协议（如上传走 HTTP vs S3 预签名）
- 引入 / 替换核心依赖
- 改变工作流（如本仓库 ADR-0001 / ADR-0002）
- 重大数据模型 / 数据库 schema 决策

**不**写 ADR 的：单个 bug fix、文档调整、UI 微调。

## 命名

```
docs/adr/<4-digit-seq>-<kebab-slug>.md
```

例：

```
docs/adr/0001-adopt-fixedflow-lite.md
docs/adr/0002-squash-merge-only.md
docs/adr/0003-mobile-framework.md
```

## 模板

```markdown
# ADR-<NNNN>: <一句话决定>

- **Date**: YYYY-MM-DD
- **Status**: Proposed / Accepted / Superseded by ADR-NNNN / Deprecated
- **Deciders**: <github-username[, ...]>

## Context

<2-4 段，描述决策面临的约束、问题、强制因素。>

## Decision

<一段，明确我们决定做什么。陈述句，不犹豫。>

## Alternatives considered

| Option | Why rejected |
|--------|--------------|
| A | ... |
| B | ... |

## Consequences

- ✅ 好的后果
- ❌ 不好的后果（已知 trade-off）
- ❓ 未知 / 后续观察项

## References

- 相关 issue / PR
- 相关外部文献
```

## Status 流转

- `Proposed`: 还在讨论
- `Accepted`: 已采纳，是当下事实
- `Superseded by ADR-NNNN`: 被新 ADR 取代（旧的不删，留作 history）
- `Deprecated`: 不再适用，但没有显式取代它的新 ADR

**永远不删除 ADR**。即使被超越，旧 ADR 也是 history 的一部分。

## 检索

```bash
# 列所有 Accepted ADR
grep -l "Status.*Accepted" docs/adr/*.md

# 找某个关键词
grep -ri "upload" docs/adr/
```
