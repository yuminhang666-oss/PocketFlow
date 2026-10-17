# 对话 C · 统计、Markdown 与 JSON

仓库：https://github.com/yuminhang666-oss/PocketFlow.git
基准：远程main M0；预留分支：feat/c-report-backup；合同：v1.0.0。

先读AGENTS、architecture/data-contracts/interfaces/ownership/milestones，使用独立检出目录。你拥有features/statistics、export、backup；不修改core/domain/contracts/数据库/根依赖，不复制交易结构，不默认上传账单。

现在可并行实现MonthlyReportService、MarkdownExporter、BackupCodec和图表组件，输入使用公共LedgerMonthData及明确截止日期；夹具结构见docs/examples/backup-v1.json。图表先用夹具，正式月快照等待B；真实恢复等待B的BackupStore。C维护统计页面及图表，A提供统一视觉约定，避免两边创建同名统计页。

支出分类、每日序列、余额参考线及Markdown共用MonthlyReport；总额/逐日/分类/明细严格相符。当前月截止今天，历史月整月；未来月拒绝实际月报；截止日后实际值留空。余额参考线不是预测。无数据不画误导性扇区，图例/数值/线型不能只靠颜色区分。

Markdown输出规范UTF-8、截止日和统计口径、逐日/分类/完整明细，特殊备注转义；JSON全量备份按v1字段输出整数分，严格校验版本/类型/金额/日期/重复/外键。预检后由用户确认全量替换，调用BackupStore，错误或取消不清库。系统文件选择/分享经FileTransferPort；需要新依赖向主控提具体版本与理由。

PR→main，先交纯报告/序列化，再图表/文件适配；测试场景与实际结果写docs/module-notes/C.md，D维护自动测试。没有设备/运行证据就明确写未验证；不合并main、不伪造导出或恢复成功。
