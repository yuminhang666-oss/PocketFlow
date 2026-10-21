# 0.3.3 验证方法与证据

基线 `de37dc008091fad265fb3f525923a0037b092eb7`（0.3.2+8），候选 0.3.3+9，合同 v3.1.0。沿用 Flutter 3.47.7 / Dart 3.13.5 与已锁定依赖、原包名和签名。

本轮新增 14 项布局回归实际通过；连同既有 10 项 UI 检查共 24 项相关回归通过。旧版失败记录验证了金额被拆为两行，原英文等高回归曾发现自适应后的标题高度差；修复后保留全部断言，不用删除测试掩盖变化。

模拟器实际旧包复现：Android16 / API36 / x86_64，360dp，font_scale1.15，三卡的负金额末位换行；相同设备 font_scale1.0 不复现。使用一笔合成 158.88 元支出及 1600 元预算，未读取/上传用户真实账本或原截图。

## 发布门禁

- 独立 ASCII clone 执行 `tools/verify.ps1` 完整生成、静态分析与全部 Flutter/SQL/历史反馈测试，另跑协作检查；最终结果按本轮日志填写，不沿用旧版数量。
- 原证书 Release 构建，执行 `tools/assert-android-apk.ps1` 与 `tools/inspect-release-candidate.ps1`，核对 0.3.3+9、cn.pocketflow、非 debuggable、三 ABI / 16KiB 对齐及敏感模式检查。
- 相同设备/虚构夹具覆盖 0.3.2+8，核对所有表、schema4、首次安装时间、主题/语言和账目；检查账单、统计及相邻入口、三主题/三语言、小屏与大字体。
- 所有发布文件先在草稿核对大小/摘要，再将完整 v1/v2 更新资产设为 latest。PR 最新 head 两项 CI 成功后才由主控合并。

本地完整证据在本轮 `deliverables/v0.3.3/`。发布后的最终摘要及包校验在 [本轮验证报告](https://github.com/yuminhang666-oss/PocketFlow/releases/download/v0.3.3/PocketFlow-0.3.3-validation.md)，安装包、前后对比和 SHA256 见 [0.3.3 Release](https://github.com/yuminhang666-oss/PocketFlow/releases/tag/v0.3.3)。链接仅在实际发布完成后有效；未完成门禁时保持 Draft，不以规划替代通过。

物理手机、其他 Android 版本/OEM 与用户网络仍未验收；不宣称真机性能改善。已有更新器行为不在此 UI 补丁中变更，下载仍依赖 GitHub 可达性与 Android 系统安装确认。
