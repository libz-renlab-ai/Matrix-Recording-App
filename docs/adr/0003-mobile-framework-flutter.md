# ADR-0003: Adopt Flutter for mobile cross-platform development

- **Date**: 2026-05-13
- **Status**: Accepted
- **Deciders**: libz-renlab-ai

## Context

Matrix Recording App 要求：

- 同时在 Android 和 iPhone 上以**独立 native 安装包**形式存在（用户在 office hours D14 中明确否决了 PWA / Web 路径）
- 录音 + 上传链路在**会议进行中的 30-60 分钟**保持稳定 —— 后台录音、锁屏录音、应用切到后台后继续录与续传不能丢
- V1 在 ~8-12 周内 ship 给 stakeholder 拿到第一组使用率数据
- 团队规模假设：起步 1 个 mobile 开发，未来扩到 2 人

候选框架在 [`/office-hours` design doc (2026-05-13)](../../../.gstack/projects/libz-renlab-ai-Matrix-Recording-App/) Phase 4 中详细对比过。

## Decision

采用 **Flutter** 作为 Matrix Recording App 的跨平台 mobile 框架。

Stack 细节：
- Flutter SDK（最新稳定版）+ Dart 语言
- 音频录制：`record` plugin（或 `flutter_sound`，sprint 0 期间评估二者并锁定）
- 后台录音：iOS 通过原生 channel 调 `AVAudioRecorder` + Background Audio capability；Android 通过原生 channel 调 `MediaRecorder` + Foreground Service
- 后台上传：iOS `URLSession` BackgroundSession（原生 channel）；Android `WorkManager`（原生 channel）
- UI：Material 3 + Cupertino widget 双轨

## Alternatives considered

| Option | Why rejected |
|--------|--------------|
| **React Native** | iOS 长时间后台录音 RN 生态不如 Flutter 成熟；Expo bare workflow 复杂；JS bridge 在长时间上传中可能有内存压力；热重载不覆盖原生部分使调试更慢 |
| **原生双端 Swift + Kotlin** | 2 份代码 = 2x 维护；MVP 需要 2 个 mobile 开发并行启动，1 人单干 24+ 周不实际；V1 阶段资本/人手不可承受 |
| **PWA / Web app** | 用户明确要求独立 native 安装包；iOS Safari 后台录音受限严重（页面切到后台 ~15s 被 kill），不能在会议 30-60 分钟内可靠后台录音 |
| **Kotlin Multiplatform Mobile (KMM)** | 业内成熟度低于 Flutter；UI 仍需各平台单写；社区音频 / 后台上传 sample 少 |

## Consequences

✅ **好的**：
- 1 份代码两平台 → 单人能同时演进两端，迭代速度最快
- 音频 plugin 生态近 1-2 年成熟（`record_platform_interface` + `audio_session`）
- Hot reload 让 UI 调优速度 5x
- 未来若需要切到原生双端（V3+ 性能极致 / SDK 嵌入需求），从 Flutter 迁移成本低于 RN
- Material 3 + Cupertino widget 自带 → UI 不被框架卡住

❌ **不好的（已知 trade-off）**：
- Flutter 学习曲线约 4 周（如果团队此前未接触 Dart）
- 长时间后台录音的关键路径仍需写 1-2 周原生 channel（不能纯 Dart 解决）
- 二进制包体 15-25MB（mandate 项目可接受，但比纯 native 大）
- 在某些 Android 厂商（华为 / 小米 / OPPO / vivo）的后台被杀策略需逐个适配测试

❓ **需后续观察**：
- iOS 长会议（≥ 90 分钟）后台录音是否在所有 iPhone 机型稳定，sprint 2 robustness 阶段验证
- Flutter audio_session 与系统电话 / 微信语音抢占音频通道的边界

## References

- [`/office-hours` design doc (2026-05-13)](../../../.gstack/projects/libz-renlab-ai-Matrix-Recording-App/libz-renlab-ai-main-design-20260513-134117.md) — Phase 4 alternatives 对比
- [ADR-0001](0001-adopt-fixedflow-lite.md) § 待决定 候选 — 本 ADR 完成"移动端框架"那一项
- 未来 [`ADR-0004` upload-protocol](0004-upload-protocol.md) 会基于 Flutter 的网络 stack 选型
