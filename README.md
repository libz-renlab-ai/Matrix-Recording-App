# Matrix Recording App

> 简单、易用、健壮的手机录音 App —— 录制后自动上传到服务器，配合分析管道（转写 / 总结 / 检索 / action item 提取）使用。

## Status — Sprint 0 (V0.0.2)

✅ **端到端能跑**：手机录音 → 自动上传 → Web UI 浏览 + 播放。

| 组件 | 状态 | 说明 |
|------|------|------|
| Android app (Flutter) | ✅ V0.0.2 | 录音、本地保存、自动上传、上传状态可视、失败重试、可配 endpoint |
| iOS app | ⏳ Sprint 1+ | 需要 Mac + Xcode + Apple Developer 账号 |
| Server (FastAPI) | ✅ V0.0.2 | POST `/api/upload`、GET `/api/recordings`、audio 流、Web UI |
| 前端 (静态 HTML+JS) | ✅ V0.0.2 | 列表 + 搜索 + 日期过滤 + 拖拽上传 + audio 播放器 + 暗色模式 |
| CI / APK 构建 | ✅ | GitHub Actions split-per-ABI release APK, ~17 MB per arch |
| 阿里云 OSS 迁移 | ⏳ Sprint 1 | 取代自建服务器以减少运维开销（详见 [ADR-0001](docs/adr/0001-adopt-fixedflow-lite.md) 后续 ADR） |

## 目标体验

- 一键开始录音，UI 不超过 3 个操作就能完成「录制 → 停止 → 自动上传」
- 弱网 / 断电 / 退到后台不会丢录音
- 后台续传：录制结束如果上传未完成，下次打开继续传
- 用户能看见每条录音的"已上传 / 上传中 / 失败"状态

## Quick start

### 装 app 到 Android 手机

1. 去 GitHub Actions [最近的 build](https://github.com/libz-renlab-ai/Matrix-Recording-App/actions/workflows/android-build.yml) 找绿色 ✓
2. 点进去 → 最底下 **Artifacts** 区下载 zip
3. 解压，挑 **`app-arm64-v8a-release.apk`**（17 MB，99% 现代 Android 手机用这个）
4. 传到手机 → 装 → 桌面出现 "matrix_recording" 图标

### 跑 server（本机开发 / demo）

```bash
cd server
python -m venv .venv-local
source .venv-local/Scripts/activate     # Windows; Linux/Mac 用 .venv-local/bin/activate
pip install -r requirements.txt
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

浏览器打开 [http://localhost:8000/](http://localhost:8000/) 看 Web UI。

### App 连 server

打开 app → 右上角 **☁️ 云上传 icon** → 输入 endpoint URL（如 `http://192.168.x.x:8000/api/upload`）→ 保存。

确认：手机和 server 同一 WiFi，server 防火墙放行 8000 端口。

### 部署 server 到 Linux box

```bash
scp -r server <user>@<server>:/home/<user>/matrix-recording/
ssh <user>@<server> 'cd /home/<user>/matrix-recording/server && bash install.sh'
```

`install.sh` 创建 venv、装 deps、跑 smoke test、配 systemd unit（有 sudo）或 nohup（无 sudo）。

## Architecture

### V0.0.2（当前）

```
┌─────────────┐    HTTP POST       ┌───────────────────┐
│ Flutter app │ ─ multipart ─────▶ │ FastAPI server    │
│ (Android)   │     m4a + meta     │ - /api/upload     │
└─────────────┘                    │ - /api/recordings │
                                   │ - /api/audio/<id> │
                                   │ - 静态前端 (/)     │
                                   └────────┬──────────┘
                                            │ 写
                                            ▼
                              ┌─────────────────────────────┐
                              │ <DATA_DIR>/                 │
                              │ ├── uploads/YYYY-MM-DD/...  │
                              │ └── metadata.jsonl          │
                              └─────────────────────────────┘
```

### Sprint 1 目标（已决方向，未实现）

```
┌─────────────┐                    ┌──────────────────┐
│ Flutter app │  (1) GET STS token │ 阿里云 函数计算 FC │
│             │ ─────────────────▶ │ (mint 预签名 URL)│
│             │                    └──────────────────┘
│             │  (2) PUT m4a
│             │ ───────────────────────────────────▶ ┌─────────────────┐
└─────────────┘                                      │ 阿里云 OSS Bucket │
                                                     └─────────────────┘
                              静态前端托管在 OSS 上，0 服务器运维。
```

## How we work — FIXEDFLOW-lite

本项目用 **FIXEDFLOW-lite** 工作流：

1. 提交 **≤50 字** issue（用 `[fixedflow]` 模板）
2. 跑 `/grill-me` 把 issue 烤透 → grill 评论 + `grill-ready` label
3. maintainer 在 Claude Code 里跑 `/fixed-flow-driver <N>`：worktree → 实现 → `/review` 循环 → 普通 PR → squash-merge

完整规则见 [`docs/FIXEDFLOW.md`](docs/FIXEDFLOW.md)。24 小时内未加 `grill-ready` 的 issue 会被 [issue-conformance workflow](.github/workflows/issue-conformance.yml) 自动 close。

## Repository layout

```
.
├── app/                              # Flutter mobile app
│   ├── pubspec.yaml                  # Flutter deps (record, http, etc.)
│   ├── lib/main.dart                 # 全部 UI + 录音 + 上传逻辑
│   ├── android-manifest-overlay.xml  # Android permissions (CI 合并用)
│   └── README.md                     # 本地构建 / 云构建说明
│
├── server/                           # FastAPI upload server + Web UI
│   ├── main.py                       # FastAPI app (~200 行)
│   ├── requirements.txt              # 3 个 deps
│   ├── install.sh                    # 一键部署到 Linux
│   ├── matrix-recording.service      # systemd unit
│   ├── static/                       # 前端
│   │   ├── index.html                # 列表 + 上传 widget
│   │   ├── style.css                 # 暗/亮自适应
│   │   └── app.js                    # 状态管理 + 拖拽上传
│   └── README.md                     # server 详细说明
│
├── docs/                             # 文档
│   ├── FIXEDFLOW.md                  # 工作流入口
│   ├── COMMIT-FLOW.md                # 改动 → commit → PR → merge
│   ├── PR-PLAN.md                    # PR 开后发现问题怎么修
│   ├── ISSUE-LIFECYCLE.md            # issue label 状态机
│   ├── BEFORE-MERGE.md               # squash-merge 前的检查表
│   ├── ISOLATED-WORKTREE.md          # 每个 issue 一个 worktree
│   ├── adr/                          # Architecture Decision Records
│   │   ├── 0001-adopt-fixedflow-lite.md
│   │   ├── 0002-squash-merge-only.md
│   │   ├── 0003-mobile-framework-flutter.md
│   │   └── 0005-distribution-channel.md
│   └── plans/                        # 每个 PR 的 fix-plan 文档
│
├── .github/
│   ├── ISSUE_TEMPLATE/               # FIXEDFLOW issue 模板
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── workflows/
│       ├── android-build.yml         # Flutter APK CI (split-per-ABI)
│       └── issue-conformance.yml     # 24h 无 grill-ready 自动 close
│
├── .githooks/                        # git hooks (pre-commit secret scan)
├── CLAUDE.md                         # AI agent 工作约定
├── AGENTS.md                         # → CLAUDE.md
├── DESIGN.md                         # 视觉 / 交互设计原则
└── README.md                         # 本文件
```

## 启用 git hooks

```bash
git config core.hooksPath .githooks
```

## V0.0.2 已知限制（明确不解决，留给 Sprint 1+）

- **后台录音受限**：屏幕需保持亮着（没用 Android foreground service + iOS background audio capability）
- **App 重启列表会清空**：录音文件还在磁盘但 UI 列表不持久化（用 SQLite / Hive）
- **没有 metadata 表单**：会议主题 / 参会人 / 项目名 没法在录音前填
- **没有真实鉴权**：server 任何能 reach :8000 的人都能上传 / 删除
- **HTTP 明文**：cleartext-only，没 HTTPS
- **iOS 不可用**：需要 Mac + Xcode + Apple Developer 账号
- **server 单点**：一台 Linux box / 一个本地进程，挂了就停（**这是为何 Sprint 1 走 OSS**）
- **fat APK 浪费**：之前 144 MB → 现在 17 MB (split-per-ABI)；理论原生最小 3-5 MB

## ADR 索引

| ADR | 决定 | Status |
|-----|------|--------|
| [0001](docs/adr/0001-adopt-fixedflow-lite.md) | 用 FIXEDFLOW-lite 工作流 | Accepted |
| [0002](docs/adr/0002-squash-merge-only.md) | main 只允许 squash-merge | Accepted |
| [0003](docs/adr/0003-mobile-framework-flutter.md) | 移动端用 Flutter | Accepted |
| 0004 | 上传协议 | TBD（等 OSS 方案落地） |
| [0005](docs/adr/0005-distribution-channel.md) | 企业分发渠道 | Proposed (pending IT) |

## License

TBD
