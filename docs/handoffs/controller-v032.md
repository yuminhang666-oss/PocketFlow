# 0.3.2 主控交接

2026-10-21 续接：用户明确要求“提交到 GitHub 上，并进行推送”，并希望手机应用内检查更新后直接更新。此次授权覆盖独立分支提交/推送、经 PR 和 CI 的主控集成、tag 与 Release，以及应用内更新所需的兼容清单与安装包发布。原本地修复阶段未获发布授权的限制由此次要求更新。远程 main/tag 再次实查为 4eb9be53bc5b2c9088a4ce16cea2949176983dba，版本 0.3.1+7。

本次源目录：`D:/Codex/记账/updates/v0.3.2/source`，独立分支 `integration/v032-control-polish`。最终独立英文路径验证 clone：`D:/Codex/PocketFlow-v032-verify-20261021`，分支 `integration/v032-local-verification`。原根目录及其他工作树没有切换、reset、stash 或覆盖。较早的 `D:/Codex/PocketFlow-v032-20261020` 仅为本轮预备构建副本，不作为最终验收基线。

修复及影响边界见 ../v0.3.2-update.md。合同、数据库、业务与依赖均不变；本地版本为 0.3.2+8。实际源文件与最终构建 clone 共 134 个 lib/android/pubspec 输入（含新增路由），按文本规范化换行/PNG 原字节比对一致。

项目规定的生成、静态检查、181 项 Flutter / 20 项 Node 与 Release 构建及包检查已实际执行。设备基准为隔离模拟器的虚构 1600 元预算和 24.80 元食堂消费，不含用户账单。覆盖前后 12 表逐行相同，schema4、外键和完整性通过；英文/玻璃偏好保留。后续矩阵改变的是同一测试设备的呈现偏好，不是升级比较基准。

交付：`D:/Codex/记账/deliverables/v0.3.2/`；最终 APK、SHA256、完整 QA、实际录像、真实 Android 模拟器桌面裁图和独立标注的遮罩模拟。以最终报告为准，不能引用前版本测试数或预备会话作为新证据。尚未在物理手机、其他 Android API 或全部 OEM 桌面验证；性能无真机承诺。

继续交付前应读取最终 QA。沿用独立分支 PR；主控核对最新 head 的远程检查后集成，不能直接推 main、force push，或伪装独立身份自我批准。Release 先在草稿中完整上传并检查，再作为 latest 公开。v1 的 debug 文件名兼容资产必须与正式 Release APK 字节相同；不得上传模拟器数据库、私钥或本地缓存。发布记录以真实 PR/Release 和本轮交付目录的 publication-report.md 为准。
