# 项目状态

更新：2026-10-17（Asia/Shanghai）。公共合同 v1.0.0。

- 公开仓库：https://github.com/yuminhang666-oss/PocketFlow；主分支 `main`。
- M0：`26d8e4b47eef5d17fe2ca8385da3ddb58adce95e`。本轮集成分支 `integration/mvp-delivery`，通过 PR 交付，不直推 main。
- 已保留并集成 B `3312266`、A `34b4276`、C `bcae0f4`、D `6035028` 的原始历史。核查时 A/B 为尚未推送的本地提交，C/D 已有远程分支和 Draft PR；原工作树未覆盖。现 A/B 已分别快进推送，并保留 Draft PR #3/#4，C/D 对应 #1/#2。
- 正式入口已接入真实 Drift 数据库、预算、记账增删改、统计图表、Markdown 和 JSON 备份恢复；已补齐 Android 文件通道。
- 已实际通过：锁定依赖解析、Drift 生成、静态分析（0 问题）、Flutter 测试 38/38（无跳过）；独立 SQL 设计检查 9/9。
- Flutter 3.47.7 / Dart 3.13.5；JDK 17、Android API 36/build-tools 36.0.0、NDK 28.2.13676358 已在 D 盘安装并核验。只设置任务进程环境。
- Debug APK 已实际构建成功并通过包信息、调试签名及复制后 SHA256 核验；163,682,534 字节（156.10 MiB）。文件路径与哈希见 [交付记录](apk-delivery.md)。
- 无连接的 Android 真机/模拟器：安装、启动、系统文件选择及分享接收方尚未设备验收。不能将自动测试或构建成功记为 M5 全部完成。
- Release 签名未配置，个人试用交付 Debug 包；Debug测试版已按用户授权公开下载；没有账单上传。

测试范围、限制及原始交付核查见 [集成报告](integration-report.md)。旧 QA 与数字编号验证文档保留历史记录，当前状态以本文件和集成报告为准。CI 配置不等于已配置平台级分支保护。

用户于2026-10-17明确授权仓库改为公开；已核验未登录访问仓库、测试版页面与APK均返回HTTP200。公开下载网址与检查范围见 [ADR 0003](decisions/0003-public-test-download.md)。
