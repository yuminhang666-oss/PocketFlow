# 模块接口 v2.0.0（0.2 集成候选）

唯一签名见 lib/contracts/；基线与兼容策略见 [数据合同](data-contracts.md) 和 [ADR 0005](decisions/0005-living-income-experience.md)。新增抽象方法影响旧实现者，所以提升主要合同版本；合并前不得当作 main 的已发布接口。

## B 提供的账本与规划接口

LedgerRepository：

- watchMonth(CalendarMonth) → Stream<LedgerMonthData>，初始及后续预算、交易、分类、profile 变化发出原子快照。
- saveBudget(CalendarMonth, Money) → Future<MonthlyBudget>。
- createExpense/createIncome(EntryDraft) → Future<LedgerEntry>，生成 ID/审计时间，检查分类类型、归档和未来日期。
- updateExpense/updateIncome(id, EntryDraft) → Future<LedgerEntry>，保留 ID、类型、创建时间，不能通过另一类型接口改变交易类型。
- deleteEntry(id) → Future<void>，不存在抛 notFound；UI 确认后调用。
- saveCategory(Category) → Future<void>；新增或改名称/归档/排序，已有类型和父类不可变，历史关联保留。
- reorderCategories(List<String>) → Future<void>，事务排序；重复或不存在 ID 失败回滚。
- addRecommendedCategories() → Future<void>，只添加缺项。
- savePreferences({String? theme, bool? feedback}) → Future<void>，theme 为 system/light/dark。
- saveGoal/deleteGoal、saveTemplate/deleteTemplate → Future<void>，profile 中原子更新；模板必须引用有效同类分类。
- markZeroExpenseDay(localDate, value) → Future<void>，主动确认零支出，拒绝未来日期和已有支出的日期。

BudgetCalculator.calculate 仍为纯同步计算，输入月份、today、budget、entries；收入、目标和模板均不参与支出扣减。

BackupStore：readAll() 原子全量读取；replaceAll(BackupDocument) 事务保存恢复点并替换；readRecovery(id) 读取私有旧/新恢复点。v1/v2 JSON 的语法预检由 C 负责，B 重做关系与事务验证。

## C 提供的查询、报表与文件接口

MonthlyReportService.build(LedgerMonthData,{required asOfLocalDate}) → MonthlyReport，支出/收入各自聚合；当前月默认今天，历史月末，未来实际报表拒绝。

LedgerQueryService.filter(LedgerMonthData,LedgerFilter,{required asOfLocalDate}) → LedgerView。对输入快照按备注/分类、类型、父类、日期和金额筛选，返回一致的明细、支出/收入/差额、按日合计。UI 不自行拼凑另一份总额。

MarkdownExporter.render(MonthlyReport) → String，不访问数据库/网络；包含预算、支出、收入、净收支、逐日/分类/全部明细，转义备注中的表格符号和 HTML。

BackupCodec.encode 写 v2；decode 读 v1/v2，拒绝未知更高版本和损坏数据。不得把解析错误变成空数组。

FileTransferPort 的 saveText/shareTextFile/pickJsonText 保持原接口。取消正常返回 false/null，真实失败抛 exportFailed/importFailed。系统文件保存与分享只在用户主动选择后调用。

## A 与主控装配

A 页面接收合同模型和回调，不导入 Drift 表、不直接 SQL。主控在 composition 中注入真实存储、查询与导出实现。编辑页独立于底栏；四个目的地与中间“记账”按钮共用一个新增入口。

保存忙碌期间禁用重复提交，失败保留表单；保存并继续仅清空已保存表单。主题持久化以存储成功后的快照为准；失败提示而非显示虚假成功。目标、模板和分类页面订阅真实 profile/类别变化。

## 错误与变更

PocketFlowException 错误码沿用 v1。I/O 失败不能返回空列表；错误提示不得包含 SQL、账单备注或凭据。写入不自动重试。数据模型仅有 core/domain 一份，模块 DTO 不得复制 Money/Entry/Report。
