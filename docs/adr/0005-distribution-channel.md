# ADR-0005: Enterprise distribution channel for V1

- **Date**: 2026-05-13
- **Status**: Proposed (PENDING — Sprint 0 第一周必须落地)
- **Deciders**: libz-renlab-ai + IT team (待对接)

## Context

Matrix Recording App 是 mandate 项目：父项目 stakeholder 已要求公司**全员**安装。这意味着：

- 起步覆盖 1000+ 员工手机（具体数字待用户确认）
- iOS + Android 双端都需要可靠分发路径
- Sprint 0 之内必须锁定分发方案，否则会 cascading 影响：
  - 是否需要 iOS 企业开发者证书？App Store distribution？TestFlight Internal？
  - Android 是否走应用宝 / 厂商商店 / 还是仅企业内部？
  - mandate 强制装的实施机制（IT push vs 工作台推送 vs 邮件链接）

用户在 /office-hours D12 中表示"公司已经有路子"，但未在 notes 里说明具体路径。本 ADR 是这件事的占位 + 决策框架，sprint 0 第一周必须 finalize。

## Decision

**PENDING**。Sprint 0 第一周必须确认。

**Default working hypothesis**（直到证伪前用这条作设计假设）：

> V1 走 **企业微信 / 钉钉 / 飞书 工作台** 作为分发渠道。用户在工作台点击 → 跳转到内部应用安装。

如果该 working hypothesis 被证伪（IT 团队说我们没有 / 不可用），V1 时间线 + 技术栈需重新评估，**不要假装这件事能在 sprint 1 happy-path 阶段才解决**。

## Alternatives considered

| Option | Pros | Cons | Sprint 0 验证动作 |
|--------|------|------|-----------------|
| **A. 企业 IM 工作台（企微 / 钉钉 / 飞书）** | mandate 触达自然；用户已经天天用 IM；零 app store 审核 | 工作台对独立 native app 类型 vs 小程序型 vs H5 wrapper 的支持差异需要确认；可能不能上 native binary | 与 IT 确认公司主用 IM + 工作台开发者中心权限 |
| **B. MDM 强推** | 100% 触达；IT 直接 push 装；mandate 实施最干净 | 需要 IT 团队有现成 MDM 部署；BYOD 设备可能不受 MDM 管 | 与 IT 确认 MDM 部署状态 + 是否覆盖 BYOD |
| **C. TestFlight Internal + Android 签名 APK 邮件分发** | 不依赖第三方平台；最大自由度 | iOS 企业证书每年续费 + Apple 政策风险；Android 各厂商安装提示烦；用户分发链路松散 | 申请 iOS 企业开发者账号 + 生成 keystore |
| **D. App Store / Google Play 公开发布** | 最规范的分发 | 公司内部敏感 app 上公开商店有信息安全顾虑；iOS 审核可能因"功能受限于企业用户"被拒 | （需要法务 / 合规事先评估） |

## Consequences

无论最终选 A/B/C，sprint 0 落地的事：

- 与 IT 团队 1 次正式 sync（不要靠"听说"），确认：
  - 现行 MDM 部署状态（产品名、覆盖率）
  - 主用 IM 工作台（企微 / 钉钉 / 飞书）+ 是否有开发者中心权限
  - iOS 企业开发者账号是否已申请
  - Android 内部分发链路（如果已有内网应用市场）
- 与法务 / 合规 sync 1 次（mandate 项目通常已经评审过录音上传相关，但确认一次）：
  - 录音内部上传是否需要全员告知 / 同意流程
  - 是否需要在 app 内提供录音被记录提示
- 决定 iOS 端：
  - 走 App Store → 需要 Apple Developer Program $99/yr 账号
  - 走企业证书 → 需要 Apple Enterprise Developer $299/yr 账号
  - 走 TestFlight Internal → 100 个 internal tester 上限是否够
- 决定 Android 端：
  - 走 Play Store → 一般不适用国内企业
  - 走内网分发 → keystore 签名 + 厂商市场对未知来源安装的拦截策略测试

锁定后这些 cascading 影响会写到对应的 sub-ADR（如 ADR-0006 iOS-distribution-cert、ADR-0007 Android-distribution-keystore）。

## Status timeline

| Date | Status | Notes |
|------|--------|-------|
| 2026-05-13 | Proposed | /office-hours 发现 P4 缺失明确决策，占位 ADR 立项 |
| 待定 | Accepted | Sprint 0 第一周与 IT/法务 sync 后填实 |

## References

- [`/office-hours` design doc (2026-05-13)](../../../.gstack/projects/libz-renlab-ai-Matrix-Recording-App/libz-renlab-ai-main-design-20260513-134117.md) — Premise P4
- [ADR-0001](0001-adopt-fixedflow-lite.md) — Source mandate for ADR-0005
- [ADR-0003](0003-mobile-framework-flutter.md) — Flutter 选型，影响打包 / 签名实施
