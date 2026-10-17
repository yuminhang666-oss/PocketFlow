# 模块接口 v1.0.0

接口源代码：`lib/contracts/`。共享模型：`lib/core/domain/`。此版本已固定协作口径，但尚未通过 Dart 编译；M0 工具链完成后第一项检查是静态分析与合同测试。任何不兼容变化由负责人统一修改。

## B 向 A/C 提供

`LedgerRepository`：

- `watchMonth(CalendarMonth)` → `Stream<LedgerMonthData>`，先发初始快照，之后在该月预算/记录/相关分类变化时发出一致快照。
- `saveBudget(CalendarMonth, Money)` → `Future<MonthlyBudget>`；预算不能为负；同月份 upsert。
- `createExpense(EntryDraft)` → `Future<LedgerEntry>`；B 分配ID与审计时间，拒绝未来日期；新增仅支出。
- `updateExpense(String id, EntryDraft)` → `Future<LedgerEntry>`；保留ID、kind和创建时间；移动日期后刷新两个相关月份。
- `deleteEntry(String id)` → `Future<void>`；不存在抛 notFound；UI 删除前确认，B 不显示对话框。

`BudgetCalculator.calculate` 输入 month、today、budget、entries → `BudgetSnapshot`；纯同步计算，不访问设备时钟/数据库。已有领域算法是启动版本，B 负责完善，D 负责验收。日期作为显式参数注入便于测试。

`BackupStore`：

- `readAll()` → `Future<BackupDocument>`；原子全量读取，包含所有月份。
- `replaceAll(BackupDocument)` → `Future<RestoreResult>`；在排他写入范围保留恢复前备份，验证并以事务全量替换；返回替换条数与本地恢复点标识。输入不是当前v1合法文档时，不得写库。

B 实现两个接口，构造时注入时钟。C 负责JSON语法/版本预检和确认流程，B 再负责最终关系与事务校验；两边职责互补。

## C 向 A 提供

`MonthlyReportService.build(LedgerMonthData, {required asOfLocalDate})` → `MonthlyReport`；同步、可单测。图表部件由 C 维护，金额合计不得在 widget 内重复实现。

`MarkdownExporter.render(MonthlyReport)` → `String`；不读数据库或写文件、不发网络请求。包含统计月份/截止日、预算、总支出/余额、逐日/分类及完整支出明细，备注转义为有效 Markdown。

`BackupCodec.encode(BackupDocument)` → JSON String；`decode(String)` → `BackupDocument`，严格预检，不修改数据库。C 实现序列化，禁止把JSON解析器强制转换异常吞成空数组。

`FileTransferPort`：`saveText({suggestedName, mimeType, content})`、`shareTextFile(...)`、`pickJsonText()`。这是平台适配端口；取消用 null/false 正常返回，真实失败抛 exportFailed/importFailed。C 实现文件选择与系统分享，A 调用；UI 不默认选择外部云盘。JSON 与 Markdown 的扩展名、MIME和用途必须区分。

## A 的状态与空态

A 可在自己的分支内用 `LedgerRepository`/`BackupStore` 的内存替身开发；替身必须标为演示环境、不得成为正式 composition 默认实现。A 不从其他聊天推测实际provider名字。负责人在 `lib/app/composition/` 创建并注入真实接口实现，A 不修改接线目录。

建议组件构造接收 `BudgetSnapshot`、`LedgerMonthData` 或接口；显示 loading/error/empty/success 四种状态。所有金额保存成功前保留表单；错误码由 A 映射为中文提示。

## 错误码与操作语义

`invalidAmount / invalidDate / invalidCategory / notFound / storageFailure / dataCorrupted / unsupportedBackupVersion / invalidBackup / backupFailed / restoreFailed / exportFailed / importFailed`。细节只进入本地可脱敏诊断，不能包含账单备注或凭据；public message 不提供 SQL 堆栈。原始异常可保留到 cause 用于测试/诊断，但不得自动上传。

跨模块不得以 bool 返回“未知原因失败”，不得以空集合代表I/O失败。用户取消文件选择/分享不算失败。对写入没有默认重试，防止重复账单；按钮保存期间禁用。

## 合同变更申请

PR 描述具体缺口、拟改字段/签名、受影响模块、迁移与兼容策略；在负责人更新合同前使用现有接口，不能把自己分支新增的接口当作主分支事实。破坏性变更先独立 contract PR，合并后模块 rebase/merge main，再开实现 PR。
