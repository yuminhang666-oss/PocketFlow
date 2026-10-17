# PocketFlow · 大学生生活费管理

Android离线生活费管理：设置月预算、快速记账、实时查看每天还能花多少；支持明细增删改、分类/每日/预算图表、Markdown月报和JSON完整备份恢复。

统一公开仓库：[yuminhang666-oss/PocketFlow](https://github.com/yuminhang666-oss/PocketFlow)。本轮交付分支：`integration/mvp-delivery`；共享合同：v1.0.0。A/B/C/D原始提交保留在集成历史中，main通过PR审阅后集成。

## 当前验证

依赖解析、Drift生成、静态分析通过；38项Flutter测试通过，另有9项SQL设计检查。真实SQLite CRUD、持久化重开、v1→v2迁移、恢复失败回滚和正式界面接线已有验证。APK的最终构建、大小和SHA256见 `docs/apk-delivery.md`。

没有连接Android真机或模拟器，安装、启动和系统文件选择/分享尚未进行设备验收。Release签名未配置；个人试用使用Debug APK。

- [集成核查与测试报告](docs/integration-report.md)
- [Android安装与个人试用清单](docs/android-trial-checklist.md)
- [架构](docs/architecture.md)、[数据合同](docs/data-contracts.md)、[接口](docs/interfaces.md)
- [模块边界](docs/ownership.md)、[PR流程](docs/workflow.md)

## 开发运行

固定Flutter3.47.7 / Dart3.13.5。Android构建使用JDK17、API36、NDK28.2.13676358、Gradle9.3.1。Windows请使用全英文独立检出目录，当前工具链在中文路径有已复现的生成/分析问题。

```powershell
# 本机已有获准工具安装时，可先执行：. ./tools/enter-android.ps1
flutter pub get --enforce-lockfile
dart run build_runner build --force-jit
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

Android SDK/JDK可通过当前进程的JAVA_HOME、ANDROID_HOME和PATH设置；不需要修改全局配置。不要提交android/local.properties、签名密钥、工具链、构建缓存或真实账单。

APK默认输出：`build/app/outputs/flutter-apk/app-debug.apk`。实际安装、启动和SAF分享功能须按试用清单在手机验收。

## 数据与限制

全部财务金额按整数分运算。当前月剩余天数包含今天，每天建议金额向下取整；超支保留负余额并显示0元建议额度；历史月显示结余。

无需账号、没有后端或自动上传。Markdown用于分析，JSON用于完整恢复；恢复是替换现有账本，需明确确认，恢复前保留本地快照。当前没有一键撤销恢复入口，试用前请保存JSON备份。主题选择暂不跨应用重启保存。

项目开源许可证尚未确定；参考项目业务代码没有复制，研究来源见docs/01-research.md。第三方依赖沿用各自许可证。
