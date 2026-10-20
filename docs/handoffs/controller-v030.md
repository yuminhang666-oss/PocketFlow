# 0.3 主控交接 · 邮箱版本地候选

2026-10-20（Asia/Shanghai）。独立目录D:/Codex/PocketFlow-v030-20261019，分支codex/v030-control-implementation；真实远程main b4f7aa6edea3bcc90d563015252c4e1fcd900649，0.3为待合并审阅候选，尚未发布；用户本轮已授权提交、推送并创建审阅PR，明确暂不合并。不得将本候选当main。

S0已按用户精确授权提交4ae3784并以PR #8在两项新CI成功后merge，完整保留#6/#7提交链。随后从真实main新建本分支。旧tag f384ecf和0.2.1资产未改，原D:/Codex/记账工作树与updates/v0.2.1/source未切分支/改写。

本地0.3.0+5，合同候选3/schema4/JSON3/recovery3，更新v2兼容v1。所有范围均保留，用户2026-10-20明确将原私有GitHub反馈服务改为邮箱yuminhang666@gmail.com（ADR0009）。生产FeedbackMailPort通过ACTION_SENDTO/mailto打开系统邮件编辑器，预览后由用户发送，App无法确认投递；无客户端时保留草稿/复制。无服务器/域名/云资源/SMTP密码，不再问托管问题；原server/feedback仅保留历史工作，不装配。未发真实邮件。

精确授权已覆盖：schema1/2/3→4安全目录事务代码与合成测试；JSON3/恢复3完整替换/恢复点最近3个30天/设备与反馈隔离的代码测试；本目录必要Flutter生成/分析/合成测试/本地构建。用户2026-10-20另行明确授权本候选提交、推送至公开仓库codex/v030-control-implementation并创建目标main的审阅PR，明确暂不合并。该授权不包含部署或公开Release。

最终独立干净快照.local/clean-email-v030-20261020排除生成文件后从baseline重新生成219输出、analyze0、139/139客户端与12/12 SQL协作通过。最终Release为68,316,420字节，SHA256 c057dcf57389184630a189527f09df2e237e331f89dfa9c4092ea69f2f180125，原测试签名/三ABI/AOT/非debuggable/16KiB通过。代码输入对照与完整本地补丁/源码ZIP/manifest见deliverables/v0.3.0/；不能复用previous-candidates或邮箱前135测试结果替代它。

最终原0.2.1→邮箱Release实际覆盖升级逐字段保留30笔虚构记录、3预算、完整profile、2旧恢复点、全部87旧分类ID，schema4/117合并分类、firstInstallTime不变、FK/完整性通过。固定邮箱的实际原生交接通过无网络的SYNTHETIC接收器验证，无附件、URI/Unicode正文一致；Gmail停用场景草稿保留，之后恢复其启用。原0.2.1解析器在受控本地feed接受真实最终v1清单，未发布新资产。

真实截图和页面矩阵已执行，实际小屏两行分类/周报大字曾复现并修复。TalkBack启用和基础焦点有证据，但完整手势/人工听读未完成，期间短暂device offline，不能把未证实激活计过。真实手机/OEM/其他API未验收。五年一万笔性能为Windows测试VM结果，不冒充手机。完整限制见docs/qa-v0.3.0.md和本地qa-report.md。

续接先读远程协作规则/main及当前Git/进程/日志，不假定被中断命令完成。仅对本任务emulator-5586只读overlay做合成验证；收尾已恢复无障碍/字体/显示设置，移除合成接收器并停止该临时模拟器，保留全部证据。不改主机全局环境或其他对话目录。源码归档不含真实数据、生成文件、密钥或缓存；打包审阅时保持原真实Git索引；后续提交按本轮精确授权执行。