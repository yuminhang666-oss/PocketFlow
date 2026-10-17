# 环境检查与下一步

检查日期：2026-10-17。工作目录 `D:\Codex\记账` 初始为空、无 .git；已确认可写。

| 工具 | 当前检查结果 |
| --- | --- |
| Git | 系统可调用，已初始化本地目录；远程仓库由用户提供，GitHub连接有push权限；本机Git未找到可用GitHub凭据 |
| Node | 24.19.0；内置 SQLite 可用，用于数据表设计验证 |
| Flutter / Dart | 系统路径中未发现；常见 D:/C: 安装位置未发现 |
| Android SDK / adb / Android Studio | 系统路径与常见 SDK/Studio 位置未发现 |
| Java | 发现 Java 8 路径和 jre-1.8 目录；这不能作为现代 Android 构建所需 JDK 已就绪的证据 |

没有进行全盘搜索；若工具已安装在其他位置，可提供目录直接使用。未安装任何依赖、修改 PATH、接受 Android SDK 许可或改动全局配置。

## 建议的最小配置范围

工具限定放在本项目 D 盘下 `.tooling/`：Flutter stable（含 Dart）、JDK、Android 命令行 SDK 及必要 platform/build-tools。依赖缓存放 `.tooling/pub-cache` 与 `.tooling/gradle-cache`；只在当前进程设置环境变量。真实手机可先替代占用较大的模拟器。下载量依官方当时版本确定，完整环境通常需要数 GB；准备至少约 10 GB 可用空间。

这是需要用户授权的安装范围，尚未执行。安装前从官方发布清单确定 Flutter/Dart 配套版本及 Android/JDK要求，记录 SHA/版本；不得执行来历不明的一键脚本。

## 安装后生成平台工程

在项目内部一个全新临时目录使用 `flutter create --platforms=android --project-name=pocketflow`。先审阅生成内容，再合入 android/ 与必要元数据；不让生成器覆盖现有 lib/、test/、pubspec.yaml 和 docs/。

随后解析依赖、生成 Drift 文件、格式化、静态检查、运行测试；以上通过后再接入真实本地数据库、做 MVP 交互并构建 APK。依赖首次解析需要访问 pub.dev 等官方软件源。GitHub/Figma 账号连接不能代替工具安装、远程仓库创建或账单上传授权。
