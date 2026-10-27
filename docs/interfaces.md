# 模块接口 v3.1.0（0.3.1 集成候选）

2026-10-20：基于已经合并的0.3.0 main cce2a22。`savePreferences` 新增可选 surfaceStyle、locale 参数，兼容策略见 data-contracts.md。更新能力新增独立可选 `AppPackageUpdatePort`：流式下载、进度、取消及系统安装交接；旧 AppUpdatePort 与浏览器发布页入口保留。下载/安装只在用户主动点击后执行，不读写账目。接口保持业务与平台分离；UI 改造不增加其他业务合同。以下0.3候选基线描述为历史记录。

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
- savePreferences({String? theme, String? surfaceStyle, String? locale, bool? feedback}) → Future<void>；theme 为 system/light/dark，surfaceStyle 为 classic/glass，locale 为 zh_Hans/zh_Hant/en。
- saveGoal/deleteGoal、saveTemplate/deleteTemplate → Future<void>，profile 中原子更新；模板必须引用有效同类分类。
- markZeroExpenseDay(localDate, value) → Future<void>，主动确认零支出，拒绝未来日期和已有支出的日期。

BudgetCalculator.calculate 仍为纯同步计算，输入月份、today、budget、entries；收入、目标和模板均不参与支出扣减。

BackupStore：readAll() 原子全量读取；replaceAll(BackupDocument) 事务保存恢复点并替换。v1/v2/v3 JSON 的语法预检由 C 负责，B 重做关系与事务验证。内部 readRecovery 由 PlanningPort.readRecoveryPoint 适配，不允许页面直接读表。

## C 提供的查询、报表与文件接口

MonthlyReportService.build(LedgerMonthData,{required asOfLocalDate}) → MonthlyReport，支出/收入各自聚合；当前月默认今天，历史月末，未来实际报表拒绝。

LedgerQueryService.filter(LedgerMonthData,LedgerFilter,{required asOfLocalDate}) → LedgerView。对输入快照按备注/分类、类型、父类、日期和金额筛选，返回一致的明细、支出/收入/差额、按日合计。UI 不自行拼凑另一份总额。

MarkdownExporter.render(MonthlyReport) → String，不访问数据库/网络；包含预算、支出、收入、净收支、逐日/分类/全部明细，转义备注中的表格符号和 HTML。

BackupCodec.encode 写 v3；decode 读 v1/v2/v3，拒绝未知更高版本和损坏数据。不得把解析错误变成空数组。旧格式没有的分类预算/周期计划在确认替换后为空；设备状态和反馈不参与替换。

FileTransferPort 的 saveText/shareTextFile/pickJsonText 保持原接口。取消正常返回 false/null，真实失败抛 exportFailed/importFailed。系统文件保存与分享只在用户主动选择后调用。

## A 与主控装配

A 页面接收合同模型和回调，不导入 Drift 表、不直接 SQL。主控在 composition 中注入真实存储、查询与导出实现。编辑页独立于底栏；四个目的地与中间“记账”按钮共用一个新增入口。

保存忙碌期间禁用重复提交，失败保留表单；保存并继续仅清空已保存表单。主题持久化以存储成功后的快照为准；失败提示而非显示虚假成功。目标、模板和分类页面订阅真实 profile/类别变化。

## 错误与变更

PocketFlowException 保留旧错误码并新增 conflict、feedbackUnavailable。I/O 失败不能返回空列表；错误提示不得包含 SQL、账单备注或凭据。财务写入不自动重试。数据模型仅有 core/domain 一份，模块 DTO 不得复制 Money/Entry/Report。

## 0.3 新增端口与一致性

唯一签名为 lib/contracts/planning_ports.dart；基于 main b4f7aa6 的本地候选，不代表远程已发布接口。

- PlanningPort.watchPlans/watchRange：计划完整快照与同一读事务内的范围账目、分类和零支出标记。watchMonth 同事务附带本月分类预算。
- clearBudget 与分类预算 save/clear/copy：null 与 0 区分；仅合法支出根类，可超分配但不改变总额度；复制前由页面确认。
- saveRuleVersion：所有生成字段不可变；新版本不能覆盖同生效月或已处理期。confirm 在同一事务再次核对版本/状态并写账与 settled 期；重复确认不重复记账。skip/reopen 为显式期操作。删除关联账目原子改 skipped 并解除引用。
- undoCreate(LedgerEntry expected)：条件删除同时检查 ID、创建/修改时间及无周期关联；修改时间强制单调递增，防同毫秒误删；0 行匹配抛 conflict。
- clearRecentCategory/saveReminderSettings：偏好与提醒开关；取消/失败不改变最近分类，编辑不影响下次新增默认。
- reserveBudgetNotice/muteBudgetMonth/reserveReport：持久设备运行状态，事务预留；恢复账本不清零，不导出。总预算各提醒共用每月两次名额，周报优先、每次前台最多一个主动提示由 Root 协调。
- recoveryPoints/readRecoveryPoint/deleteRecoveryPoints：元数据坏点单独标错；恢复仍通过 BackupStore.replaceAll 原子替换，页面预检确认；删除/清空另行确认。lastExportUtcMs/recordSuccessfulExport 仅在实际文件保存成功后登记。
- FeedbackDraftStore：独立持久草稿。按用户最新ADR0009，生产使用FeedbackMailPort.openComposer(FeedbackDraft)→Future<bool>，只表示已打开邮件编辑器，不表示发送/投递；固定收件人、预览确认、无客户端时保留草稿/复制内容。状态mailOpened不是回执，用户在外部邮件客户端发送。原FeedbackPort/Receipt仅保留早期候选兼容定义，生产不调用。

反馈页面不读数据库，邮件端口不读财务表；本地草稿实现因需要 Drift 位于反馈 data/，这是主控登记的跨范围适配。原生邮件桥仅ACTION_SENDTO/mailto与固定收件人，新增查询声明而非邮箱/联系人权限；无需后端。早期Node备选保留但不装配，无新增npm/Flutter依赖。


## 手动更新端口 v1（0.2.1候选）

独立接口lib/contracts/app_update_port.dart：AppUpdatePort只读取本机安装信息和打开固定下载链接；AppReleaseSource读取公开版本清单。启动不调用版本源，只有用户点击“检查更新”才请求网络。AppUpdateController负责单次检查、失败和下载状态，不访问LedgerRepository或BackupStore。财务接口候选2.0.0保持不变。

## 0.4.0 合同增量 v3.2.0

可选 PersonalProfile.categoryColors、Category.colorValue、RecurringOccurrence.actualLocalDate 及 confirm(actualLocalDate:) 见 [0.4.0说明](v0.4.0-update.md)。旧字段缺省兼容；颜色复用profile，实际日期复用plan_settings，同一事务保存；不增加依赖或财务表迁移。旧备份期次缺省按dueDate核对，新期次按明确实际日期核对。源定义仍只在core/domain与contracts。
