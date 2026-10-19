# PocketFlow · 离线收支与预算

Android 本地记账应用：月预算、支出与收入、两级分类、账单筛选与日历、统计、目标与模板、Markdown 月报和 JSON 完整备份。金额始终使用整数分；收入不会自动增加预算。

仓库：[yuminhang666-oss/PocketFlow](https://github.com/yuminhang666-oss/PocketFlow)。当前已发布个人测试版为 **0.2.1+4**，使用测试签名和 Debug 编译模式。

- [0.2.1 测试版与源码下载](https://github.com/yuminhang666-oss/PocketFlow/releases/tag/mvp-v0.2.1-debug)
- [0.2.1 行为与已有设备验证](docs/v0.2.1-update.md)
- [架构](docs/architecture.md)、[合同](docs/data-contracts.md)、[接口](docs/interfaces.md)、[所有权](docs/ownership.md)

## 分支与当前状态

2026-10-19 远程核查：main 为 `8b224deabadf042ee901e2bfdf5deaa1d97e2c51`（0.1.1）；[PR #6](https://github.com/yuminhang666-oss/PocketFlow/pull/6) 和 [PR #7](https://github.com/yuminhang666-oss/PocketFlow/pull/7) 均未合并。本地 S0 审查候选以 #7 head `f384ecfe7a2b4fec5bfcc3d77bbae73762a10145` 为起点，该提交完整包含 #6 head `081d6b4d0d872939ce48a8614784dad80533489d`。

候选财务合同 2.0.0、schema 3、公开 JSON 2、私有恢复编码 2；更新元数据独立为 v1。上述候选与已发布 tag 均不代表 main 已更新。旧 tag 与资产保持原 SHA 对应关系。0.3.0 尚未完成；本轮证据及待授权动作见 `deliverables/v0.3.0/`。

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
```

已有完整 pub cache 时可用 `flutter pub get --offline --enforce-lockfile`。Drift 生成文件不入库，应由上述命令生成；不能从发布 ZIP 补入文件后宣称全新检出生成成功。sqlite3 native asset hook 仍可能需要下载已锁定版本的原生构建产物；失败应记录为环境阻碍。

APK 构建使用 `./tools/build-test-apk.ps1`，实际签名、版本、原生插件与 ABI 还须由校验脚本核查。Release 变体及 0.3.0 覆盖安装验收尚待实施。已有报告记录的是过去执行；本轮结果以本轮日志为准。

## 数据与备份

财务数据保存在应用本地。JSON 用于完整替换恢复，Markdown 用于阅读；恢复前保留内部恢复点。内部恢复点随卸载或数据清除丢失，不能替代外部 JSON 备份。0.2.1 尚无恢复点管理页面，0.3.0 将按确认的合同补齐。

主题设置可跨重启保存。更新仅在用户手动检查时联网，下载由浏览器和 Android 系统处理。当前无线上反馈服务、账号或云账本同步，不上传账本。

保持包名 `cn.pocketflow`、原数据库位置与既有测试签名。不要提交真实账单、数据库、签名私钥、android/local.properties 或缓存。公开发布、部署及仓库操作分别按精确授权执行。项目开源许可证尚未确定，第三方依赖沿用各自许可证。
