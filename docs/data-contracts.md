# 数据合同 v2.0.0（0.2 集成候选）

唯一 Dart 定义位于 `lib/core/domain/`，接口位于 `lib/contracts/`。本分支基于远程 main 的 8b224de；合并前，main 的 v1.0.0 仍为其他对话的公共基线。候选变更见 [ADR 0005](decisions/0005-living-income-experience.md)。

## 金额、日期与标识

S0 安全校验修订（2026-10-19，本地候选）：分类名称 trim 后为空时拒绝，不自动改名；历史归档分类仍可读取。账目和模板必须与显式 category.kind 相容，旧 kind=null 分类继续接受原收入/支出。公共 JSON 预检、typed restore、私有恢复编码和持久化读取共用领域校验。未改变字段、金额、历史引用、schema 或编码版本。周期规则尚不存在，待 S1 合同定义后覆盖同一约束。

人民币金额使用整数分。单笔正金额上限 99,999,999,999 分；预算允许 0，交易必须大于 0。Money 可为负以表示余额或差额。十进制输入不能先转 double；聚合使用 BigInt 并检查整数边界，double 仅用于图表坐标、比例绘制。每日参考额度向下取整到分。

localDate 固定 YYYY-MM-DD，是用户选择的归属日；CalendarMonth 支持 1900–9999 年。用于承载日历的 UTC DateTime 不代表发生瞬间。实际时间和审计时间使用明确的 UTC 毫秒整数。新增和编辑拒绝未来日期，编辑保留 ID、kind、createdAtUtcMs。

ID 为最长 64 字符的不透明字符串。原始分类 food/drinks/shopping/transport/study/fun/health/other 的 ID 和旧关联保持不变。分类归档保留历史，不能硬删除后转移原账单。

## 共享模型

| 模型 | 关键字段与语义 |
| --- | --- |
| Category | id/name/sortOrder/isArchived/kind?/parentId?；最多两层；旧 kind=null 兼容历史收支 |
| LedgerEntry | id/amount/localDate/categoryId/kind/note/occurredAtUtcMs/createdAtUtcMs/updatedAtUtcMs；expense 和 income 金额均为正 |
| EntryDraft | amount/localDate/occurredAtUtcMs/categoryId/note；调用 createExpense 或 createIncome 决定类型 |
| LedgerMonthData | month/budget/entries/categories/profile；一次 SQLite 查询的一致快照 |
| MonthlyBudget / BudgetSnapshot | 原预算模型与算法保留；收入和目标不修改预算 |
| MonthlyReport | 原支出字段及 totalIncome/dailyIncome/incomeCategoryTotals；netFlow=收入−支出 |
| LedgerFilter / LedgerView / DayTotals | 备注或分类搜索、类型、父类及子类、日期与金额范围；筛选后总额及按日合计 |
| SavingsGoal | id/name/target/saved；进度手动登记，独立于生活费预算 |
| EntryTemplate | id/name/kind/amount/categoryId/note；使用时带入表单，仍需确认保存 |
| PersonalProfile | theme/feedback/lastExpenseCategoryId/lastIncomeCategoryId/goals/templates/zeroExpenseDays |
| BackupDocument | 全量 budgets/categories/entries/profile；不含密钥、设备私密路径、图表缓存和恢复点列表 |

所有集合防御性复制且不可修改。Category 的 kind 为 expense/income/null；父分类必须存在且为根分类，子类类型必须相容，拒绝循环与第三层。归档父类同时禁止新账单使用其子类；原账单可保留原归档分类继续修改金额/备注。类别颜色由稳定 ID 决定，不能按当月排行序号分配。

推荐目录有 16 个支出组、8 个收入组及细分类，见 category_catalog.dart。首次创建和升级只补缺项，不覆盖已改名称、顺序或归档状态。恢复备份是完整替换，不自动补分类；用户可明确选择“补全推荐分类”。

## 预算与收支口径

- 当前月统计截至今天（含今天）的 expense；剩余天数含今天。
- 历史月统计全月，remainingDays=0，dailyAllowance=null。
- 未来月只显示计划日均，不能声称实际消费或收入。
- 无预算用 null，显式零预算用 0；零预算不显示除零百分比。
- 超支余额可为负，每日参考为 0；预算使用率可以超过 100%，仅绘图时截断。
- income 不抵扣 expense、不自动增加月预算；netFlow 是期间收支差额，不能叫账户余额。
- 目标登记不扣预算、不自动认定为转账或支出。
- 修改、删除、跨月移动后重新聚合，不存累计金额。

收入、支出逐日序列均从 1 日补零到截止日；之后的实际值为空。日合计、分类合计、明细合计分别等于各自总额。无对应类型记录时显示空态。预算参考线为每日末预算 − floor(预算 × 日序号 / 当月天数)，不是预测。

没有账单的日历日期显示“尚未记录”，不自动判断零消费。zeroExpenseDays 只保存用户主动确认；当天存在支出时拒绝确认，新增支出或将支出移到该日期时清除标记。只有收入的日期仍可确认零支出。

本版本没有定义退款、报销、借贷、账户互转或自动重复交易，不能以普通收入冒充这些业务。

## 数据库升级

schemaVersion=3；从 2 增加 categories.category_kind、categories.parent_id 和 personal_state 表，不修改原账单或预算列。从 1 直接迁移到 3 时沿用严格表约束与事务回滚。原数据库路径、包名和签名保持一致。

快照仍由单条 UNION ALL SELECT 原子读取，新增 profile 属于同一快照。主题、反馈、模板、目标和最后所选分类写入本地；更新 profile 使用事务中的读改写，防止覆盖其他偏好。

## JSON 与恢复

新导出为 appId=pocketflow、formatVersion=2、currency=CNY。所有金额是整数 amountFen/targetFen/savedFen。时间明确标识 ...UtcMs。v2 增加分类 kind/parentId 与完整 profile；示例见 docs/examples/backup-v2.json（虚构夹具）。

读取 v1 保留原记录、金额、收入、预算及旧分类，并使用默认个人设置；v2 严格检查字段类型、引用、枚举、日期、金额、重复 ID 和分类图关系；未知更高版本拒绝。旧 v1 示例保留用于兼容验证。

完整恢复会替换账本、目标、模板及偏好。预检后显示数量和替换范围，经用户确认，在同一事务先保存原账本与 profile 的恢复点，再替换；任何失败必须回滚。私有 RecoveryCodec 新编码为 2，继续读取编码 1。恢复点不混入公开 JSON 备份。


## 更新元数据 v1（独立于财务备份）

每次测试发布附带PocketFlow-update.json：schemaVersion=1、applicationId=cn.pocketflow、versionName、正整数versionCode、certificateSha256、apkName、apkSha256、整数apkSizeBytes、字符串数组releaseNotes。DTO唯一来源core/domain/app_update.dart。候选必须匹配发布标签、原签名和实际服务器APK大小/摘要，下载URL仅来自指定GitHub仓库。更新信息不写入schema3/JSON2，不上传账本。
