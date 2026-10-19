# 项目状态

## 当前执行状态（2026-10-19，S0 本地审查候选）

远程 main 仍为 8b224deabadf042ee901e2bfdf5deaa1d97e2c51（0.1.1）；PR #6/#7 均 open/draft，未合并。本次独立 codex/v030-s0-review 分支基于 #7 head f384ecfe7a2b4fec5bfcc3d77bbae73762a10145，完整包含 #6 head 081d6b4d0d872939ce48a8614784dad80533489d。候选版本 0.2.1+4 / 合同 2.0.0 / schema 3 / JSON 2 / recovery 2，尚未进入 0.3 功能开发。

S0 收口：恢复与模板收支相容校验、分类空白名拒绝、README 版本漂移和 CI 目标分支覆盖。实际验证及待授权动作见 deliverables/v0.3.0/qa-report.md。旧发布 tag/资产、已有工作树和真实账本未修改。以下各节保留为历史记录，不作为本轮测试结果。

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

## 0.2 集成候选

本分支基于 main 8b224de，更新版本 0.2.0+3，合同候选2.0.0、数据库3、JSON2。实现范围和验证口径见 [更新记录](v0.2-update.md)。合并前不替代已发布的0.1.1公共基线；本次最终APK、校验和和Android运行结果记录在交付说明。


## 0.2.1 手动更新候选（2026-10-18）

本分支integration/v0.2.1-updates叠加PR #6的081d6b4，公共main仍为8b224de。新增“我的→检查更新”，无自动检查和首页提醒。81项Flutter测试、完整静态检查、Android覆盖安装及逐字段保留验证通过。详见[v0.2.1记录](v0.2.1-update.md)。
