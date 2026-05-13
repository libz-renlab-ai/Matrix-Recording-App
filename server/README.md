# Matrix Recording — server

Sprint 0 V0.0.2：接收手机 app 上传的会议录音 + 网页展示 + 播放。

## 部署到 192.168.22.88 (jushi 账号)

凭据搞定之后，本地一行 scp 推上去：

```bash
# 在本仓库 root 跑
scp -r server jushi@192.168.22.88:/home/jushi/matrix-recording/
ssh jushi@192.168.22.88 'cd /home/jushi/matrix-recording/server && bash install.sh'
```

如果服务器上有 sudo 权限，会自动装 systemd unit + 开机自启。如果没有 sudo，
fallback 到 `nohup` 启动（重启服务器需要手动 re-run install.sh）。

成功后访问：

```
http://192.168.22.88:8000/        # 录音列表网页
http://192.168.22.88:8000/api/health    # 健康检查
http://192.168.22.88:8000/api/recordings # JSON 列表
```

## 本地测试（不需要服务器）

```bash
cd server
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
python main.py
# open http://127.0.0.1:8000/
```

注意：本地跑会写到 `/home/jushi/matrix-recording/`（硬编码的服务器路径）。
本地测试想要别的路径就改 `main.py` 顶部 `DATA_DIR`。

## 文件结构

```
server/
├── main.py                          # FastAPI app 全部逻辑（≤200 行）
├── requirements.txt                 # 3 个 deps: fastapi + uvicorn + python-multipart
├── matrix-recording.service         # systemd unit（生产部署）
├── install.sh                       # 一键部署脚本
├── README.md                        # 本文件
└── static/
    ├── index.html                   # 前端列表 + 播放器 UI
    ├── style.css                    # 暗黑/明亮自适应
    └── app.js                       # 列表加载 / 搜索 / 删除 / 自动刷新
```

## API

| Method | Path | 功能 |
|--------|------|------|
| GET | `/` | 静态前端 |
| POST | `/api/upload` | multipart 上传（file + 可选 title/project/participants/device/timestamps） |
| GET | `/api/recordings` | JSON 列表 |
| GET | `/api/audio/<id>` | 音频流（带正确 content-type，可以浏览器直接播） |
| DELETE | `/api/audio/<id>` | 删除文件 + 删 metadata |
| GET | `/api/health` | health check（ok=true、count、disk_free） |

## 已知限制

- **无 auth**：内网 + 你说"不在乎隐私"。任何能 reach :8000 的人能上传 / 删除。
- **单机存储**：录音文件落在 `/home/jushi/matrix-recording/uploads/<date>/`。备份是你的事。
- **metadata 用 JSONL 文件**：不是 SQL。`/home/jushi/matrix-recording/metadata.jsonl`。
  并发上传场景下追加是原子的（POSIX 单 write），不会损坏，但删除是 rewrite 全文件 — 大规模并发删会有问题。
- **不做病毒扫描 / 不做内容审核 / 不限上传频率**：你说"不在乎隐私"
- **没有 HTTPS**：HTTP 明文。Flutter 端 Android manifest 已声明 cleartext。
- **Cap 单文件 100MB**：FastAPI 默认行为，对会议录音够用。要更大就改 `client_max_body_size`（如果走 nginx）或 `--limit-max-requests`。

## V0.0.3 / sprint 1 候选

- [ ] 接父项目分析管道：上传成功后 POST 到 `parent_project/api/ingest`
- [ ] 添加 token 鉴权（即使内网也建议）
- [ ] 上传前 chunk + 续传支持（断网恢复）
- [ ] metadata 表单：app 端录音前填会议主题 / 参会人
- [ ] 服务器端转写自动化（whisper.cpp / 外部 API）
- [ ] HTTPS（self-signed 证书或 caddy 反代）

## Troubleshooting

| 症状 | 排查 |
|------|------|
| `curl: connection refused` | 检查 systemd 服务状态 `sudo systemctl status matrix-recording`，看 `/home/jushi/matrix-recording/server.log` |
| 上传超时 | 看是不是文件太大；考虑 nginx 反代 + 升 client_max_body_size |
| 网页空白 | 看浏览器 console 报错；可能 CORS（不该出现，因为前端和后端同源） |
| `EACCES: permission denied` 写文件 | 服务在用谁的身份跑（whoami in systemd unit）+ `/home/jushi/matrix-recording/uploads/` 是否可写 |
