# 开源调研与构建决策

检查时间：2026-10-17（Asia/Shanghai）。使用 GitHub 连接读取仓库元数据、默认分支提交、目录及选定源文件；没有运行这些应用，也没有执行其测试。维护时间指最新提交或推送，不把 star、仓库 updated_at 当成维护证据。固定提交见 research-snapshot.json。

## 推荐

**独立构建精简 Flutter 项目，主要参考 Lumina 的功能分目录与本地数据流，以及 Cashew 的每日预算口径。** PocketFlow 的核心比通用财务管理器窄：单币种、按自然月预算、支出记录、每天可花额度。直接 fork 会同时继承多账户、汇率、复杂预算和迁移负担。四个项目都不能直接替代我们的整数分金额模型与中文 Markdown 月报。

| 项目 | 已查技术与实现 | 需求匹配与取舍 | 许可证文件 | 最新默认分支提交（UTC） |
| --- | --- | --- | --- | --- |
| Cashew | Flutter、Drift、Provider、fl_chart；预算卡订阅统计流 | 每日预算最直接；多钱包、多币种、Firebase 等依赖使裁剪成本高 | GPL-3.0 | 2026-03-09 01:35:16 |
| Monekin | Flutter、Drift、fl_chart；app/core 分层、数据库迁移与本地备份 | 本地数据与图表参考价值高；账户、资产等范围偏大 | AGPL-3.0 | 2026-10-15 11:16:47 |
| Expense Manager | Kotlin、Compose、多 Gradle 模块、Room 数据实体；CSV/PDF 导出策略 | Android 原生参考；采用它会改变已选 Flutter 路线 | Apache-2.0 | 2026-10-14 16:59:24 |
| Lumina Expense | Flutter、Riverpod、Drift、fl_chart；features 分目录、版本化 JSON 与 CSV | 栈最接近；仍有档案、拆分交易、借贷等额外复杂度，不能视为已验证稳定的基础 | MIT | 2026-10-06 21:44:50 |

所有仓库检查时均未归档。Lumina 建于 2026-08-16，检查时仅 2 stars；这只说明公开使用与维护历史较少，不能据此认定代码质量好坏。

## Cashew：每日预算与数据流

[预算卡源文件](https://github.com/jameskokoska/Cashew/blob/9cfbe50c16d95429891d44faf5f2c77a3abdb93b/budget/lib/widgets/budgetContainer.dart#L433) 在 433–436 行计算预算结束日距离今天的天数，再加 1，因而包含当天。468–510 行的 getAmountPerDayString 将预算与累计金额之差除以剩余天数，并根据收入/支出预算极性处理正负与超支。预算卡上层使用 StreamBuilder 监听数据库统计。

[数据库模型及查询](https://github.com/jameskokoska/Cashew/blob/9cfbe50c16d95429891d44faf5f2c77a3abdb93b/budget/lib/database/tables.dart) 中 Transactions（274 行附近）用 RealColumn 储存 amount，Budgets（423 行附近）也用 RealColumn；6465 行附近 watchTotalOfBudget 组合时间、分类、钱包等过滤条件。其多币种通用设计不能直接满足本项目“财务运算避免浮点误差”的要求。

借鉴：当天计入剩余天数、记账变更实时刷新、预算进度与超支状态的清楚表达。独立实现：整数金额、自然月历史/未来状态、未设置预算、跨日刷新与月报统计口径。不能仅照搬卡片公式而忽略其过滤和极性前提。

[预算历史图](https://github.com/jameskokoska/Cashew/blob/9cfbe50c16d95429891d44faf5f2c77a3abdb93b/budget/lib/widgets/budgetHistoryLineGraph.dart) 用 fl_chart 的 FlSpot 与专门 lineGraph 组件处理系列、空区间和触摸回调。该图并不直接等价于 PocketFlow 的“剩余预算与理论消费进度比较”。README 涉及 Drive 备份/同步；本次未审计完整导出链路，不据此声称已验证其导出正确性。

## Lumina：最接近的架构，但不要整库裁剪

[依赖](https://github.com/PrabinCode/lumina-expense/blob/531bc6a75d5d9ee4d7689657712f6949909b85a0/pubspec.yaml) 明确包含 flutter_riverpod、drift、fl_chart。[表结构](https://github.com/PrabinCode/lumina-expense/blob/531bc6a75d5d9ee4d7689657712f6949909b85a0/lib/core/database/tables.dart) 中交易 amount、预算 amountLimit 使用 RealColumn，同时包含多类财务实体。

[预算仓库](https://github.com/PrabinCode/lumina-expense/blob/531bc6a75d5d9ee4d7689657712f6949909b85a0/lib/features/budgets/data/budget_repository.dart) 汇总分类支出及拆分交易，计算 percentage、remaining、80% 提醒，并监听预算/交易/拆分表变化；所查文件未实现本项目的每日剩余额度。多条流各自触发重新读取的方式也不宜原样搬用，应使用单一一致的统计快照或 Drift 聚合查询。

[备份服务](https://github.com/PrabinCode/lumina-expense/blob/531bc6a75d5d9ee4d7689657712f6949909b85a0/lib/features/backup/services/backup_restore_service.dart) 是较大的综合服务，覆盖本地位置、版本化快照、恢复/导入等。借鉴版本字段与恢复预检，把我们的月报导出和备份恢复拆成小服务；不沿用它的手机硬编码 Downloads 路径。[现金流图](https://github.com/PrabinCode/lumina-expense/blob/531bc6a75d5d9ee4d7689657712f6949909b85a0/lib/features/analytics/presentation/widgets/cash_flow_bar_chart.dart) 将图表封装成独立部件，适合借鉴这一职责划分。

## 另外两个项目

[Monekin 数据库](https://github.com/enrique-lozano/Monekin/blob/c4050637fe85944f156593971e70ee56702c0329/lib/core/database/app_db.dart) 包含迁移前备份及失败保护；[备份服务](https://github.com/enrique-lozano/Monekin/blob/c4050637fe85944f156593971e70ee56702c0329/lib/core/database/backup/backup_database_service.dart) 导出数据库及 CSV。其[预算模型](https://github.com/enrique-lozano/Monekin/blob/c4050637fe85944f156593971e70ee56702c0329/lib/core/models/budget/budget.dart) 包含目标金额和时间进度；没有依据认定其已满足 PocketFlow 每日额度规则。

[Expense Manager 交易实体](https://github.com/nkuppan/expensemanager/blob/24ef7e89941d794157e65ece5ebf943e2f2ce924/core/database/src/main/kotlin/com/naveenapps/expensemanager/core/database/entity/TransactionEntity.kt) 的 amount 为 Double；[导出仓库](https://github.com/nkuppan/expensemanager/blob/24ef7e89941d794157e65ece5ebf943e2f2ce924/core/data/src/main/kotlin/com/naveenapps/expensemanager/core/data/repository/ExportRepositoryImpl.kt) 按 CSV/PDF 策略分发。README 对 PDF 是否完成有前后不一致描述，因此以已读取源码存在对应入口为限，不声称 PDF 功能运行通过。模块化与按日期分组的账单交互可参考，代码语言与目标栈不匹配。

## 许可证处理

已读取四个仓库根 LICENSE，并与 GitHub 元数据交叉检查。标识见表。GPL/AGPL 属于 copyleft；MIT/Apache-2.0 也有保留声明等条件，不能把开源理解为任意抹去来源。当前采用独立实现，没有复制参考项目源代码/图片，不引入其衍生代码许可证决策。未来具体复用时逐文件登记原路径、提交、许可证与必要声明；发布前检查直接及传递依赖。

原文件：[Cashew LICENSE](https://github.com/jameskokoska/Cashew/blob/9cfbe50c16d95429891d44faf5f2c77a3abdb93b/LICENSE)、[Monekin LICENSE](https://github.com/enrique-lozano/Monekin/blob/c4050637fe85944f156593971e70ee56702c0329/LICENSE)、[Expense Manager LICENSE](https://github.com/nkuppan/expensemanager/blob/24ef7e89941d794157e65ece5ebf943e2f2ce924/LICENSE)、[Lumina LICENSE](https://github.com/PrabinCode/lumina-expense/blob/531bc6a75d5d9ee4d7689657712f6949909b85a0/LICENSE)。
