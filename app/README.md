# Matrix Recording App — Flutter source

V0.0.1 (sprint 0)：录音 + 本地保存 to internal app documents directory。**上传到分析管道 待 sprint 1**。

## 本地构建（等装好 Flutter + Android Studio 后）

```bash
# 1. 用 flutter create 生成完整脚手架到一个临时目录
cd $(mktemp -d)
flutter create --project-name matrix_recording --org com.libzrenlab.matrix --platforms=android scaffold

# 2. 把仓库里的源文件覆盖过去
cp $REPO/app/pubspec.yaml scaffold/pubspec.yaml
cp $REPO/app/lib/main.dart scaffold/lib/main.dart
# 把 android-manifest-overlay.xml 里的 permissions 合并到 scaffold/android/app/src/main/AndroidManifest.xml
# (CI 的 .github/workflows/android-build.yml 里有同样的 merge 逻辑可参考)

# 3. build + install
cd scaffold
flutter pub get
flutter run             # 连了手机的话直接装
# 或
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

## 云构建（不需要本地装 Flutter）

push 到 main 之后 GitHub Actions 会跑 `.github/workflows/android-build.yml`：

1. 在 CI 环境用 `flutter create` 生成脚手架
2. 覆盖 pubspec.yaml / lib/main.dart / AndroidManifest.xml 这三个我们关心的文件
3. `flutter build apk --release`
4. APK 作为 GHA artifact 上传

到 https://github.com/libz-renlab-ai/Matrix-Recording-App/actions 找最新的 run → 下载 artifact → 解压 → 拿到 APK → 手机装。

## V0.0.1 功能

- ✅ 一键开始 / 停止录音
- ✅ 录音保存为 m4a (AAC-LC, 128kbps) 到 app 内部 documents 目录
- ✅ 录音历史列表 (本进程内)
- ✅ 麦克风权限请求
- ❌ 后台录音（屏幕需亮着 — 这是 V0.0.1 已知限制，sprint 2 robustness 阶段解决）
- ❌ 上传服务器（sprint 1）
- ❌ Metadata（sprint 1）
- ❌ 录音持久化历史跨重启（sprint 1）

## V0.0.1 限制 / 已知问题

- **会议时屏幕必须保持亮着** — V0.0.1 没用 foreground service，锁屏 / 切到后台会被 Android 杀掉录音进程
- **录音文件存在 app 私有目录** — 只能本 app 内访问，卸载 app 就丢了
- **没有持久化历史** — 应用重启后 列表 清空（文件还在）
- **仅 Android** — iOS 需要 Mac + Xcode，sprint 0 之外

## 文件结构

```
app/
├── pubspec.yaml                      # Flutter deps
├── lib/
│   └── main.dart                     # 全部 UI + 录音逻辑
├── android-manifest-overlay.xml      # Android permissions overlay (CI 合并用)
└── README.md                         # 本文件
```

注意：`android/`、`ios/`、`linux/`、`macos/`、`windows/`、`web/` 这些平台目录**不进 git**，由 CI 用 `flutter create` 生成。这样仓库里只有"我们写的代码"，没有 Flutter 自动生成的脚手架噪音。
