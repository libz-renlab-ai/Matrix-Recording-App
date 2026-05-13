# DESIGN — Matrix Recording App

> 视觉 / 交互 / UX 决策的 single source of truth。技术栈选定后填充。

## Design principles

1. **零摩擦录音**：从打开 app 到开始录音 ≤ 1 次点击。已经在录的话，开 app 立即看到录音状态。
2. **状态显式可见**：每条录音有"已录 / 上传中 / 已上传 / 失败"4 态明确视觉区分。无歧义中间态。
3. **错误不沉默**：上传失败要可见、可解释、可手动重试。不允许 "悄悄失败"。
4. **小屏优先**：所有核心 UI 在 4.7" 屏幕上单手可操作。

## TBD（前期）

- [ ] 色板（一个主色 + 录音红 + 状态色）
- [ ] 字体（系统字体 vs 自带）
- [ ] 录音按钮交互（长按 vs 单击 vs 滑动）
- [ ] 列表卡片设计

## 占位 — 待 ADR-0003 定移动端框架后补全

技术栈选定后这份文档分裂为：

```
DESIGN.md                           # 这份（principles + 抽象）
docs/design-system/colors.md
docs/design-system/typography.md
docs/design-system/components.md
```
