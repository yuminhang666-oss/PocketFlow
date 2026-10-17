# PocketFlow Android APK 交付

构建日期：2026-10-17（Asia/Shanghai）。集成分支：`integration/mvp-delivery`；合同 v1.0.0。

## 实际文件

| 项目 | 已核验结果 |
| --- | --- |
| 构建结果 | 成功，退出码 0，文件实际存在 |
| 模式 | Debug，个人试用；非 Release |
| 交付文件名 | PocketFlow-debug.apk |
| 可获取路径 | `D:\Codex\记账\deliverables\PocketFlow-debug.apk` |
| 原始构建路径 | `D:\Codex\PocketFlowIntegration\build\app\outputs\flutter-apk\app-debug.apk` |
| 实际大小 | 163,682,534 字节（156.10 MiB） |
| SHA256 | `1a1b371b3a9d6cccead65433b1957e1bf0337f58343a6a78c993d71c92bbda25` |
| 应用/包名 | PocketFlow / cn.pocketflow |
| 版本 | 0.1.0，versionCode 1 |
| Android 要求 | 最低 API 24（Android 7.0）；target/compile API 36 |
| ABI | armeabi-v7a、arm64-v8a、x86_64 |
| 签名核验 | apksigner 验证通过，APK Signature Scheme v2，Android Debug 证书 |
| 安装与启动 | 未执行：没有连接真机或模拟器 |

复制后的交付文件与原构建文件 SHA256 相同。校验文件位于同目录 `PocketFlow-debug.apk.sha256`。APK 内已检查各 ABI 的 Flutter 与 SQLite 动态库及 Dart kernel 资源，不以此替代设备启动测试。

## 构建与验证

```powershell
. ./tools/enter-android.ps1
flutter doctor -v
flutter pub get --enforce-lockfile
dart run build_runner build --force-jit
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter build apk --debug --no-pub
```

本轮依赖解析、Drift 生成、静态分析 0 问题及 38/38 测试通过，随后实际构建 APK。首次 Gradle 构建耗时约 837 秒。下载失败的 Gradle/NDK 压缩包保留，改用同一官方来源的完整分段下载，并与官方 SHA256/SHA1 核验后使用；未通过关闭证书校验来绕过完整性检查。

构建出现非致命 SDK XML v3/v4 解析提示，最终编译成功；原始输出保留在 `docs/evidence/integration/apk-build.log`。包信息、签名及自动测试记录也在该目录。

Debug 包使用本机生成的标准调试签名；私钥未进入仓库或交付源码。正式 Release 签名尚未准备，未构建或伪装交付 Release 包。以后更换签名的 APK 可能不能覆盖安装，卸载前应先导出 JSON 备份。

## 手机试用

把 APK 传到自己的手机，由文件管理器打开并按系统提示安装。完整步骤及验收在 [个人试用清单](android-trial-checklist.md)。安装/启动、强制停止后重开、真实图表触摸、Android 文件保存/选择/分享接收方尚未设备验证；APK 构建成功不代表这些项目已通过。

## 公开下载（2026-10-17）

用户明确授权仓库改为公开后，已核验以下页面与APK无需GitHub登录即可访问（HTTP200），APK响应大小与原始交付一致：

- [直接下载PocketFlow-debug.apk](https://github.com/yuminhang666-oss/PocketFlow/releases/download/mvp-v0.1.0-debug/PocketFlow-debug.apk)
- [测试版页面](https://github.com/yuminhang666-oss/PocketFlow/releases/tag/mvp-v0.1.0-debug)

测试标签对应原始已验证代码提交 `d8a37aea1ed71f2704539c45aa937836ec499b7d`；本次仅更改可见性和文档，没有重新构建或更换APK。
