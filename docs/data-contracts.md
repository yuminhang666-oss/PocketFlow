# 数据合同 v3.1.0（0.3.1 集成候选）

2026-10-20：0.3.0 已经 PR #9 合入 main cce2a22。0.3.1 在其上增加两个可选呈现偏好：`PersonalProfile.surfaceStyle` 为 classic/glass，缺省 classic；`locale` 为 zh_Hans/zh_Hant/en，缺省 zh_Hans。默认值不额外写入 JSON。`theme` 仍为 system/light/dark，glass 独立且固定浅色；语言只改变界面，用户原文、人民币金额和日期归属不变。旧客户端忽略新增字段，新客户端读取旧档案回退默认值；普通 profile 编辑须保留新增字段。数据库schema4、JSON3、recovery3及财务模型不变。接口和唯一类型以 lib/core/domain、lib/contracts 为准。以下0.3合同细节保留，旧候选的基线描述仅作历史。

唯一 Dart 定义位于 `lib/core/domain/`，接口位于 `lib/contracts/`。本候选基于已合并 PR #8 的真实 main b4f7aa6，main 公共合同为 v2.0.0。0.3 未合并，不将候选接口当作公共事实。变更见 [ADR 0008](decisions/0008-planning-reviews-contract.md)。

## 金额、日期与标识

S0 安全修订已通过 PR #8 合入：分类名称 trim 后为空时拒绝，不自动改名；历史归档分类仍可读取。账目、模板和本候选周期版本必须与显式 category.kind 相容，旧 kind=null 继续接受原收入/支出。JSON、typed restore、私有恢复编码和持久化读取共用领域校验。

人民币金额使用整数分。单笔正金额上限 99,999,999,999 分；预算允许 0，交易必须大于 0。Money 可为负以表示余额或差额。十进制输入不能先转 double；聚合使用 BigInt 并检查整数边界，double 仅用于图表坐标、比例绘制。每日参考额度向下取整到分。

localDate 固定 YYYY-MM-DD，是用户选择的归属日；CalendarMonth 支持 1900–9999 年。用于承载日历的 UTC DateTime 不代表发生瞬间。实际时间和审计时间使用明确的 UTC 毫秒整数。新增和编辑拒绝未来日期，编辑保留 ID、kind、createdAtUtcMs。

ID 为最长 64 字符的不透明字符串。原始分类 food/drinks/shopping/transport/study/fun/health/other 的 ID 和旧关联保持不变。分类归档保留历史，不能硬删除后转移原账单。

## 共享模型

| 模型 | 关键字段与语义 |
| --- | --- |
| Category | id/name/sortOrder/isArchived/kind?/parentId?；最多两层；旧 kind=null 兼容历史收支 |
| LedgerEntry | id/amount/localDate/categoryId/kind/note/occurredAtUtcMs/createdAtUtcMs/updatedAtUtcMs；expense 和 income 金额均为正 |
| EntryDraft | amount/localDate/occurredAtUtcMs/categoryId/note；调用 createExpense 或 createIncome 决定类型 |
| LedgerMonthData | month/budget/entries/categories/profile/categoryBudgets；同一 SQLite 读事务的一致快照 |
| MonthlyBudget / BudgetSnapshot | 原预算模型与算法保留；收入和目标不修改预算 |
| MonthlyReport | 原支出字段及 totalIncome/dailyIncome/incomeCategoryTotals；netFlow=收入−支出 |
| LedgerFilter / LedgerView / DayTotals | 备注或分类搜索、类型、父类及子类、日期与金额范围；筛选后总额及按日合计 |
| SavingsGoal | id/name/target/saved；进度手动登记，独立于生活费预算 |
| EntryTemplate | id/name/kind/amount/categoryId/note；使用时带入表单，仍需确认保存 |
| PersonalProfile | theme/feedback/lastExpenseCategoryId/lastIncomeCategoryId/goals/templates/zeroExpenseDays |
| BackupDocument | 全量 budgets/categories/entries/profile/plans；sourceFormatVersion 保留预检来源；不含密钥、设备运行状态、反馈或恢复点列表 |
| CategoryBudget | month/categoryId/amount；合法支出根类计划，不参与总余额再次扣减 |
| RecurringRule / RecurringVersion | 稳定规则 ID；不可变版本保存 effectiveMonth/startMonth/endMonth/kind/categoryId/amount/day/leadDays/note/enabled/archived 全字段 |
| RecurringOccurrence | ruleId/period/versionId/status/entryId；(ruleId,period)唯一，settled 必有唯一关联账单，skipped 无账单 |
| PlanningData / ReminderSettings | 完整分类预算/规则/版本/处理期，budget/weekly 开关及 catalogVersion |
| LedgerRangeData | start/end 闭区间、entries/categories/zeroExpenseDays/revision；同一范围快照 |
| DailyTotals / CategoryBreakdown / WeeklyReport | 日收支、根直接/子类金额、期间收支/最高支出/并列数量；空数据不推断零消费 |
| FeedbackDraft / FeedbackMailPort | UUIDv4反馈编号、白名单表单/可选环境、draft/mailOpened；后者仅表示邮件编辑器打开，投递状态未知，与财务备份分离 |

所有集合防御性复制且不可修改。Category 的 kind 为 expense/income/null；父分类必须存在且为根分类，子类类型必须相容，拒绝循环与第三层。归档父类同时禁止新账单使用其子类；原账单可保留原归档分类继续修改金额/备注。类别颜色由稳定 ID 决定，不能按当月排行序号分配。

新安装目录为 15 支出根类、7 收入根类，共 83 项，见 catalog_upgrade.dart。原 category_catalog.dart 的 87 项保持为可追溯旧定义。schema 升级只对完整匹配旧元数据的名称/顺序更新；科研、家教成本、家教收入分支仅在整棵完全匹配时归档，保留旧 ID/账单/模板引用。用户更改或自定义后代保留。kind/父级冲突不强塞新子类。恢复按备份目录读取，不每次启动补种；显式补充新版目录幂等且记录目录版本。

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

schemaVersion=4；保留从 1/2 到原严格表约束与 category_kind/parent_id/personal_state 的路径，再创建 plan_budgets、plan_rules、plan_versions、plan_occurrences、plan_settings、device_states、feedback_draft_rows。plan_versions 的 JSON 完整版本必须与索引列身份/生效月/引用一致。迁移与目录变更在同一事务，失败保持旧 schema 与原数据；不删库重建。原数据库路径、包名和签名保持一致。

账目/分类/预算/profile 使用 UNION ALL SELECT，计划表在同一读事务读取。范围报告使用同一事务，revision 为每次快照的新标识，不存在跨恢复沿用的报告缓存。主题、触觉反馈、模板、目标和最近分类仍在原 profile；分类预算/周期计划与设备状态不塞入 profile。更新 profile 使用事务读改写。

## JSON 与恢复

新导出 appId=pocketflow、formatVersion=3、currency=CNY。金额为整数 amountFen/targetFen/savedFen，时间明确 ...UtcMs。v3 增加必填 planning 对象，其中 categoryBudgets/rules/versions/occurrences 数组、reminderSettings、catalogVersion 必填。示例见 docs/examples/backup-v3.json（虚构夹具）。

读取 v1/v2/v3。v1 用默认个人设置，v1/v2 的 planning 使用明确的空计划、默认开关、catalogVersion=0。预检显示旧格式不含新计划，确认完整替换后清空当前新计划。严格检查字段类型、引用、枚举、日期、金额、重复 ID、分类图、版本生效、期唯一及关联账单类型/分类/日期；未知更高版本拒绝。不得通过改账单 kind 或金额修复损坏。

完整恢复替换账本、分类、预算、目标、模板、主题、零支出标记和全部计划。在同一事务先写当前完整恢复点，按依赖顺序替换，最后清理到最近 3 个且不超过 30 天；失败包括恢复点与清理全部回滚。私有 RecoveryCodec 写 3，读 1/2/3。元数据损坏的恢复点在管理页单独标错。设备提醒名额/月静默/周报已展示期、反馈草稿/回执和外部导出时间不替换、不公开备份。内部恢复点不代替外部文件。

## 周期、提醒与回顾

月度规则遇短月用月末，下一月回原日；未处理期由对应完整版本推导。修改默认下月生效，可选当前或未来合法月；同生效月不可覆盖，已处理期不可重写。暂停/归档是从所选生效月开始的新版本，不抹掉旧处理历史。确认时核对有效版本、分类与期状态，未来到期日拒绝实际入账；确认与账单在同一事务。删除关联账单变 skipped，主动恢复待处理另行操作。

普通新增撤销原子匹配 ID/创建/修改时间且无周期引用；修改时间严格递增，覆盖同毫秒更新；已改变/已删/已关联则 conflict。成功保存后才反馈，连续记账页内反馈。

预算使用率规则为整数比较，第5天起至少35%且进度为时间1.3倍；超预算绕过下限，0/null单独处理。每自然月共两次、相隔7本地日、第二次增量至少max(ceil10%B,1000分)，设备事务预留并持久化；恢复与时钟回拨不重置。分类预算仅行内标记。默认开关可关闭，当月可静默。

周一08:00后只提示最新完整周、每期一次、空周不弹；30自然日内可重算周报，已结束月次月1日08:00后归档。排名按根汇总且不重扣子类，最大支出按金额降序/时间降序/ID升序稳定选一并标并列。无支出/无记录不除零，不推断零消费；当前周比较同等已过天数。Root统一协调路由/文件/生命周期，首页空闲且每前台会话至多一个主动提示，周报优先。


## 更新元数据 v1/v2（独立于财务备份）

每次测试发布附带PocketFlow-update.json：schemaVersion=1、applicationId=cn.pocketflow、versionName、正整数versionCode、certificateSha256、apkName、apkSha256、整数apkSizeBytes、字符串数组releaseNotes。DTO唯一来源core/domain/app_update.dart。候选必须匹配发布标签、原签名和实际服务器APK大小/摘要，下载URL仅来自指定GitHub仓库。更新信息不写入schema3/JSON2，不上传账本。

0.3另提供 PocketFlow-update-v2.json，schemaVersion=2、buildKind=release、assetName 指向受控 Release 文件名；优先v2、必要时回退v1。旧客户端v1保持兼容debug资产名，内容是同字节Release副本。坏Release不遮蔽其他有效版本；检查失败清空旧可下载候选。手动检查仍不在启动自动联网。

## 当前反馈合同（用户覆盖原方案）

按ADR0009固定邮箱 yuminhang666@gmail.com，预览后由用户在邮件客户端完成发送。FeedbackMailPort.openComposer返回bool，只表示已打开；取消/缺少邮件客户端/异常不伪称送达，本地草稿和复制入口继续可用。反馈状态mailOpened不等于submitted或receipt；保留早期候选FeedbackPort/Receipt的兼容定义及已有本地数据，但生产不调用HTTPS服务，不生成邮件回执。无需服务器、域名、SMTP凭据或云资源。草稿和可能存在的历史回执仍不参与财务替换删除。

## 0.4.0 合同增量 v3.2.0

可选 PersonalProfile.categoryColors、Category.colorValue、RecurringOccurrence.actualLocalDate 及 confirm(actualLocalDate:) 见 [0.4.0说明](v0.4.0-update.md)。旧字段缺省兼容；颜色复用profile，实际日期复用plan_settings，同一事务保存；不增加依赖或财务表迁移。旧备份期次缺省按dueDate核对，新期次按明确实际日期核对。源定义仍只在core/domain与contracts。
