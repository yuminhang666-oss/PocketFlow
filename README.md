# PocketFlow · 离线收支与预算

Android 本地记账应用：月预算、收支、两级分类、账单筛选与日历、目标与模板、Markdown 月报和 JSON 完整备份。0.3 本地候选增加根分类预算、月度周期待办、周/月回顾、预算进度提醒、恢复点管理、条件撤销、反馈草稿和“关于 PocketFlow → 更新记录”。金额始终使用整数分；收入不会自动增加预算。

仓库：[yuminhang666-oss/PocketFlow](https://github.com/yuminhang666-oss/PocketFlow)。当前已发布个人测试版为 **0.2.1+4**，使用测试签名和 Debug 编译模式。

- [0.2.1 测试版与源码下载](https://github.com/yuminhang666-oss/PocketFlow/releases/tag/mvp-v0.2.1-debug)
- [0.2.1 行为与已有设备验证](docs/v0.2.1-update.md)
- [架构](docs/architecture.md)、[合同](docs/data-contracts.md)、[接口](docs/interfaces.md)、[所有权](docs/ownership.md)

## 分支与当前状态

2026-10-20 远程复核：main 为 `b4f7aa6edea3bcc90d563015252c4e1fcd900649`。经用户精确授权，[PR #8](https://github.com/yuminhang666-oss/PocketFlow/pull/8) 在两项新 CI 通过后合并，完整保留 #6/#7 提交链及 S0 安全补丁。旧 tag 与资产未改变。

本地 `codex/v030-control-implementation` 从上述真实 main 建立，版本 **0.3.0+5**，合同候选 3.0.0、schema 4、JSON 3、私有恢复编码 3；新更新元数据 v2 兼容 v1。0.3 为独立审阅分支，尚未合并或发布，不能将本候选接口视为 main 事实。用户2026-10-20已授权提交、推送并创建审阅PR，明确暂不合并。用户2026-10-20将反馈改为发送邮件至 **yuminhang666@gmail.com**，无需反馈服务器；预览后由邮件客户端发送，App不确认投递或生成回执。原私有GitHub服务仅保留历史备选，见 [ADR0009](docs/decisions/0009-feedback-email.md)。本地验收结果见 [0.3 说明](docs/v0.3.0-update.md) 与 `deliverables/v0.3.0/qa-report.md`。

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

0.3 Release 候选使用 `./tools/build-release-candidate.ps1`，要求本机已有原测试证书，不生成新密钥。通用 APK 与兼容旧客户端的 `-debug.apk` 为相同 Release 字节；文件名不表示编译模式。个人测试签名不等于正式生产签名。脚本拒绝覆盖已有候选，实际签名、ABI、对齐和覆盖升级以本轮证据为准。

## 数据与备份

财务数据保存在应用本地。JSON v3 完整恢复包括分类预算和全部周期版本，读旧 v1/v2 时明确预警这些新计划将替换为空。恢复前在同一事务保存恢复点，成功后只留最近 3 个、最长 30 天。设备提醒名额、反馈草稿/回执不随账本恢复回滚。内部恢复点随卸载或数据清除丢失，不能替代外部 JSON 备份；升级成功后不支持直接安装旧 APK 降级。

主题设置可跨重启保存。更新仅在手动检查时联网，下载由浏览器和 Android 系统处理。反馈预览后打开手机邮件客户端，仅带白名单表单与可选环境信息；不附加账本、日志或设备标识。没有邮件客户端时保留草稿并提供复制入口；邮件是否发送/送达由邮件客户端处理。无需购买服务器、域名或开通托管，不嵌入邮箱密码。核心记账/报告/备份离线可用，没有云账本同步。

保持包名 `cn.pocketflow`、原数据库位置与既有测试签名。不要提交真实账单、数据库、签名私钥、android/local.properties 或缓存。公开发布、部署及仓库操作分别按精确授权执行。项目开源许可证尚未确定，第三方依赖沿用各自许可证。
