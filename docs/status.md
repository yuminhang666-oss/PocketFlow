# 项目状态

更新：2026-10-17（Asia/Shanghai）。公共合同v1.0.0；数据库schema v2。

- 公开仓库：https://github.com/yuminhang666-oss/PocketFlow。M0基线26d8e4b47eef5d17fe2ca8385da3ddb58adce95e；集成经PR #5交付。
- A/B/C/D原始提交保留。0.1.0经用户手机反馈发现Android原生插件漏打包，已用原APK在模拟器复现；不能将先前Windows通过项当成Android运行通过。
- 当前更新版0.1.1 / versionCode 2，补齐JNI插件及原生库、修复错误自动重试导致的持续加载；共享模型与数据库路径未改变。
- 实际通过：静态分析0问题、Flutter测试39/39；Android API36模拟器首启、预算设置、消费增删改、统计、重启持久化、Markdown系统保存、JSON保存与确认恢复、离线读取。
- 实际覆盖验证：安装原0.1.0→放入明确标记的虚构测试账本→adb install -r新0.1.1成功；firstInstallTime保持不变，1500预算/30消费/1470余额及备注保留。后续另从空账本实际保存，区分夹具与真实UI流程。
- APK 163,977,930字节，SHA256 9ead1e7b3d9bc0c20608d09e167419e962c02f850f177b3ceac4b87a56b08658。包名cn.pocketflow与最初签名一致，三种ABI的JNI/SQLite/Flutter库、16KiB对齐均核验。
- 用户真实手机/OEM差异、TalkBack与系统分享接收方仍待验收；正式Release签名未配置。主题选择仍只保留当前会话。
- 私钥固定在本机独立signing目录，不入库、不上传；构建校验证书与版本，不能静默重建另一把密钥。

完整修复与更新记录：[0.1.1报告](hotfix-0.1.1.md)。原0.1.0报告和证据保留为历史，不代表修复后的最终验收。