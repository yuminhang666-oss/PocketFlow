# PocketFlow · 离线收支与预算

**0.4.2+13 源码审阅候选**：修正报告重复点击重置期间和月初日期筛选的时区边界；改善备注、细分类和保存反馈。[更新说明](docs/v0.4.2-update.md) · [本轮验证](docs/qa-v0.4.2.md) · [上传复核](docs/source-upload-v0.4.2.md)。本分支经PR交付，尚未合并或发布安装包更新；线上版本仍以 Releases 为准。

**0.4.1+12**：按两份设计复查报告完善账单、日历、分类入口、首页目标与报告，并统一三主题选中状态和分类颜色。[更新说明](docs/v0.4.1-update.md) · [实际验证](docs/qa-v0.4.1.md)。安装包、完整源码及校验和见 Releases。

Android 本地记账应用：月预算、收支、两级分类、账单筛选与日历、小目标、模板、周期计划、周报月报、Markdown 分析及 JSON 完整备份。金额使用整数分；收入和目标进度不自动改变生活费预算。

**0.4.0+11**：总览突出日均参考，提供紧凑四宫格；仅设置小目标后显示首页目标区。账单默认列表，可主动切换日历；查询月份与新增发生日期分别管理。报告中心提供趋势与分类排行，分类颜色跨页一致。

- [下载安卓安装包](https://github.com/yuminhang666-oss/PocketFlow/releases/latest)
- [0.4.0 更新与数据兼容](docs/v0.4.0-update.md) · [验收范围](docs/qa-v0.4.0.md)
- [架构](docs/architecture.md)、[合同](docs/data-contracts.md)、[接口](docs/interfaces.md)、[所有权](docs/ownership.md)

## 分支与发布

0.4.0 由主控从 main `171194f30b3873f93edf090f29773e9a099e16ad`（0.3.4）在独立分支实现，经 [PR #16](https://github.com/yuminhang666-oss/PocketFlow/pull/16) 和 CI 集成。数据库 schema4、JSON3/recovery3、依赖锁和原升级签名保持；可选分类颜色与周期实际日期见更新说明。正式附件采用 Release 编译；兼容旧更新器的 `-debug.apk` 与 Release 安装包为相同字节。

## 从干净检出验证

固定 Flutter 3.47.7 / Dart 3.13.5。Android 使用 JDK17、API36、NDK28.2.13676358、Gradle9.3.1。Windows 使用独立英文路径；不移动或覆盖其他对话的工作树。

```powershell
# 仅在工具已安装且获准时，为当前进程配置环境：
. ./tools/enter-android.ps1
flutter pub get --enforce-lockfile
dart run build_runner build --force-jit
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
node --test tools/schema.test.mjs tools/coordination.test.mjs
node --test server/feedback/server.test.mjs
```

已有完整 pub cache 时可用 `flutter pub get --offline --enforce-lockfile`。Drift 生成文件不入库，应由上述命令生成；不能从发布 ZIP 补入文件后宣称全新检出生成成功。sqlite3 native asset hook 仍可能需要下载已锁定版本的原生构建产物；失败应记录为环境阻碍。

Release 构建使用 `flutter build apk --release --no-pub`，要求本机通过 `POCKETFLOW_TEST_KEYSTORE` 指向已有原测试证书，不生成新密钥。通用 APK 与兼容旧客户端的 `-debug.apk` 为相同 Release 字节；文件名不表示编译模式。个人测试签名不等于正式生产签名。脚本拒绝覆盖已有候选，实际签名、ABI、对齐和覆盖升级以本轮证据为准。

## 数据与备份

财务数据保存在应用本地。JSON v3 完整恢复包括分类预算和全部周期版本，读旧 v1/v2 时明确预警这些新计划将替换为空。恢复前在同一事务保存恢复点，成功后只留最近 3 个、最长 30 天。设备提醒名额、反馈草稿/回执不随账本恢复回滚。内部恢复点随卸载或数据清除丢失，不能替代外部 JSON 备份；升级成功后不支持直接安装旧 APK 降级。

主题设置可跨重启保存。更新仅在手动检查时联网，应用内下载会校验大小、摘要和证书，再交给 Android 系统安装。反馈预览后打开手机邮件客户端，仅带白名单表单与可选环境信息；不附加账本、日志或设备标识。没有邮件客户端时保留草稿并提供复制入口；邮件是否发送/送达由邮件客户端处理。无需购买服务器、域名或开通托管，不嵌入邮箱密码。核心记账/报告/备份离线可用，没有云账本同步。

保持包名 `cn.pocketflow`、原数据库位置与既有测试签名。不要提交真实账单、数据库、签名私钥、android/local.properties 或缓存。公开发布、部署及仓库操作分别按精确授权执行。项目开源许可证尚未确定，第三方依赖沿用各自许可证。
