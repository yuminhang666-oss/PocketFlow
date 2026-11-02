# PocketFlow 开发前速查

> 公开版速查。仓库和设备状态核对时间：2026-11-02。开始工作时应重新核对远程分支、设备和项目规则。

## 项目和代码

- PocketFlow 是面向 Android 的离线记账与预算应用，应用包名为 `cn.pocketflow`；财务金额使用整数分。
- 仓库：<https://github.com/yuminhang666-oss/PocketFlow>；克隆地址：`https://github.com/yuminhang666-oss/PocketFlow.git`。仓库公开，不要提交真实账本、数据库、签名私钥或访问凭据。
- 默认开发基线为远程 `main`。本次核对为 `dd71ccbe00bb9377a02658ee8114d7bdcb86ccc4`，版本 `0.4.1+12`；这个提交号是检查时的快照，不代表未来不会更新。
- [0.4.2 测试版](https://github.com/yuminhang666-oss/PocketFlow/releases/tag/v0.4.2)提供安装包和源码；其 [PR #18](https://github.com/yuminhang666-oss/PocketFlow/pull/18) 本次检查时尚未合并。未合并分支不自动成为 `main` 的公共接口。
- 应用入口是 `lib/main.dart`；共享模型在 `lib/core/domain/`，共享接口在 `lib/contracts/`；页面和功能主要在 `lib/app/`、`lib/features/`，Android 平台工程在 `android/`。

## 开始新任务

先从远程读取项目根目录 `AGENTS.md`，以及 `docs/architecture.md`、`docs/data-contracts.md`、`docs/interfaces.md`、`docs/ownership.md`、`docs/milestones.md`、`docs/status.md` 和对应任务的 `docs/handoffs/`。注意文档中可能保留历史阶段的状态。

每个对话使用自己的独立检出或 worktree；不要切换、重置或覆盖其他任务的目录。实际分支及修改范围以 `docs/ownership.md` 为准，通过 PR 交付，未经授权不合并或发布。Windows 上建议使用获准写入的英文目录，避免当前构建工具的中文路径限制。

## Flutter 与安卓环境

项目基线使用 Flutter 3.47.7、Dart 3.13.5、JDK 17、Android API 36 和 NDK 28.2.13676358。现有 Windows 机器的工具根目录为 `D:\Codex\PocketFlowTools`；不同机器或后续迁移应以实际检查结果为准。

项目脚本 `tools/enter-android.ps1` 只配置当前 PowerShell 进程，默认从工具根目录查找 Flutter、JDK、Android SDK、Pub 和 Gradle 缓存。不要为了新任务重复安装已有工具或修改全局 PATH。

```powershell
. .\tools\enter-android.ps1
$env:ANDROID_AVD_HOME = 'D:\Codex\PocketFlowTools\cache\avd'
& 'D:\Codex\PocketFlowTools\android-sdk\emulator\emulator.exe' -list-avds
```

本次本机识别到的 AVD 名称是 `PocketFlow_Hotfix_API36_20261017`，使用 API 36、Google APIs、x86_64。启动和设备测试前确认目标及隔离状态，测试只使用合成账本；不要清除真实手机或模拟器数据。模拟器位置和名称可能变化。

## 验证与数据保护

缓存完整且依赖获取已在授权范围内时，可先在独立检出中尝试锁定的离线解析，然后按改动范围选择代码生成、分析和测试：

```powershell
flutter pub get --offline --enforce-lockfile
dart run build_runner build --force-jit
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
```

sqlite3 原生构建产物即使已有 Pub 缓存也可能需要额外获取；遇到缺失时记录环境限制，并按授权决定是否联网。记录实际命令、版本与结果，不把历史测试结果当作本次结果。

Release 更新必须沿用既有应用包名和对应签名；不擅自创建替代密钥。真实账本、备份、签名材料和模拟器数据不应上传到公开仓库。
