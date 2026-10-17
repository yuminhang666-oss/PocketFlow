# ADR 0002：MVP 装配、依赖锁及 Android 文件通道

日期：2026-10-17。主控在 `integration/mvp-delivery` 执行；公共合同保持 v1.0.0。

## 背景与决定

四个模块基于同一 M0，但独立源码没有形成可运行应用。主控保留各模块原始提交，依次合并 B、A、C、D，再处理入口装配和跨模块兼容问题。

1. `lib/app/composition/pocketflow_root.dart` 注入 LedgerRepository、BackupStore、Clock、FileTransferPort。首页预算和统计共用一个 `LedgerMonthData` 订阅，不分别拼接不同时间的预算与交易。正式入口使用真实 SQLite，无演示数据。
2. build_runner 固定 2.16.2：2.17.1 的 build 5 与 drift_dev 2.35.1 的 build <5 冲突。启用 fl_chart 1.2.0；提交实际解析出的 pubspec.lock；CI 依据锁生成 Drift 后验证。共享 DTO 与接口无需破坏性更改。
3. B 的 schema v2 在 v1 基础增加本地恢复点；真实 SQLite 迁移、替换失败回滚及恢复前快照均由自动测试验证。JSON 恢复仍为合同规定的原子全量替换。
4. Android 原生端实现既有 `pocketflow/file_transfer/v1` 协议：SAF 保存/选择文件，FileProvider 分享应用私有临时文件。取消正常返回，文件上限 50 MiB，无广泛存储权限。分享成功仅表示系统选择器已发起，不等于接收应用读取成功。
5. Android 平台采用当前固定 Flutter 生成的工程：API 36、最低 API 24、NDK 28.2.13676358、AGP 9.1.0、Gradle 9.3.1。Gradle 使用官方 bin 包和 SHA256；Release 不沿用模板的调试签名，等待单独准备正式签名。

## 验证与影响

依赖解析、真实代码生成、静态分析及 38 项 Flutter 测试通过。Android 编译结果见 `docs/apk-delivery.md`；系统文件界面与手机安装启动等待设备验收。没有新增产品功能或另建数据合同。

根装配、锁文件及本 ADR 由主控维护。Android 端与测试后续仍由 D 负责，业务数据与恢复存储仍由 B 负责，界面由 A、统计及文件协议 Dart 端由 C 负责。
