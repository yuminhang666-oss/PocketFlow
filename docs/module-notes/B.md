# B · 核心记账、预算与数据库

日期：2026-10-17。基线：`26d8e4b47eef5d17fe2ca8385da3ddb58adce95e`。分支：`feat/b-ledger-budget`。公共合同：v1.0.0。状态：实现待 Dart/Drift 编译及 D 的正式测试，不能视为 MVP 已验收。

## 交付范围

- `DriftLedgerRepository`：月预算 upsert、支出新增/修改、交易删除、按月一致数据流；构造注入 Clock 和可选测试 ID 生成器。
- `LedgerReader`：用单条 UNION ALL 查询读取预算、交易、分类；同一 SQLite 语句提供同一读取快照，空月份仍返回分类上下文。
- `BudgetCalculator`：保留 M0 的当前/历史/未来月与整数分规则，增加 BigInt 累计和 native int 溢出保护。
- `BudgetService`：无 UI 依赖的预算流；午夜自动刷新；显式前台/时区刷新；可跟随当前月份或固定历史月份；取消订阅和 dispose 释放 Timer 与数据库订阅。
- `DriftBackupStore`：实现已发布的 BackupStore；同一事务先保存旧数据恢复点，再替换业务数据，失败整体回滚。
- schema v2：加强 ID、真实日期、金额类型、审计时间等约束；新增私有 recovery_snapshots；提供 v1→v2 非破坏迁移。

只修改 B 所有权目录及本文。没有修改共享模型、contracts、依赖、UI、图表、test/、integration_test/ 或工作流。数据模型唯一来源仍是 `docs/data-contracts.md` 和 `lib/core/domain/`；本文说明实现，不另建一套数据合同。原任务提到的 `docs/data-contract.md` 以主控后来确定的文档边界为准，本分支不新增该公共合同文件。

## 主控装配

实现入口：

| 类型 | 路径 | 用途 |
| --- | --- | --- |
| AppDatabase | lib/core/database/app_database.dart | 生产本地连接或注入测试 QueryExecutor |
| DriftLedgerRepository | lib/features/transactions/data/drift_ledger_repository.dart | LedgerRepository 实现 |
| DriftBackupStore | lib/features/transactions/data/drift_backup_store.dart | BackupStore 实现 |
| BudgetService | lib/features/budget/application/budget_service.dart | 午夜与生命周期预算刷新 |

```dart
final database = AppDatabase.local();
final ledger = DriftLedgerRepository(database, clock: clock);
final backup = DriftBackupStore(database, clock: clock);
final budgets = BudgetService(repository: ledger, clock: clock);

// null 跟随当前月份；传入 month 则固定月份。
final currentBudget = budgets.watch();
final selectedBudget = budgets.watch(month: selectedMonth);
// 主控在前台恢复、系统日期或时区变化时调用：
budgets.refreshDate();

// 先取消页面订阅；退出装配时按顺序释放：
await budgets.dispose();
await database.close();
```

这些是 B 具体实现的装配示例；正式 Riverpod Provider 与 Flutter 生命周期接线由主控完成，本分支没有默认注入演示仓库。每次 watch 返回冷的单订阅流并触发初始读取；不要把同一个单订阅流同时交给多个独立 listen，主控可通过状态管理共享其结果。

## 业务与字段语义

持久化交易沿用 id、amount_fen、kind、occurred_local、occurred_at_utc_ms、category_id、note、created_at_utc_ms、updated_at_utc_ms。全部金额为人民币整数分，不通过 double。单笔上限 99,999,999,999 分，支出必须 >0；预算允许0，缺少预算行代表未设置。

occurred_local 为不随设备时区迁移的归属日；occurred_at_utc_ms 为发生瞬间，创建和修改时间由 Clock 写入。修改保留 ID/kind/createdAtUtcMs；设备时间回拨时 updatedAtUtcMs 不低于旧值。时间戳保存完整整数毫秒，按 Dart DateTime 可表示范围校验；1900–9999 的日历限制用于月份和归属日，不把本地归属日与 UTC 日期强行设为相同。

新增和修改支出拒绝未来归属日；无法仅凭 localDate 推断 occurredAtUtcMs 是否一致，接口约定由调用者从选择的日期/时间生成正确瞬间，本模块不按设备当前时区重写历史时间戳。旧归档分类允许保留在已有交易上，新增或改选分类必须存在且未归档。updateExpense 不修改 income，查不到相应 expense 抛 notFound；deleteEntry 可删除任意已有交易。

账单排序：occurredAtUtcMs 降序，再按 id 升序；分类按 sortOrder、id 升序。月查询包含当月全部已保存记录，预算按截止日期过滤 expense，income 不抵扣预算。跨月编辑对 ledger_entries 的表通知使原月和新月查询都重新执行；其他月份可能收到值相同的快照，这属于 Drift 表级失效机制。

读取金额、时间和分类标志时先检查 QueryRow 的原始值必须为 int，避免 Drift 数值映射把损坏的 REAL 静默截断。无效存量字段/枚举/关系报 dataCorrupted；I/O错误保留为 storageFailure；流错误不伪装为空集合。业务不默认重试写入。

## 预算口径

剩余预算 B−S；当前月 S 包含今天、剩余天数含今天。无预留的每日建议为 floor(max(B−S,0)/D)，不足一分保留在余额。历史月 D=0、dailyAllowance=null；未来月 S=0、D=整月天数，显示为计划日均；无预算时余额/额度为 null；零预算与未设置严格区分。

示例：2026-10-17，预算150000分，消费60000分，余额90000分，D=15，每日6000分；再消费1800分，余额88200分，每日5880分。消费60001分时，余额89999分，每日5999分。超支保留负余额、每日额度0。

原始使用率为 S/B，可超过100%，B=0或无预算时为 null。超支金额为 max(S−B,0)，无预算时未知。v1 BudgetSnapshot 没有新增百分比或超支金额字段，调用方已有 budget/spent/remaining 可显示这些派生值；若要提供统一命名字段，由主控更新共享模型，B 不加相似 DTO。百分比显示舍入不得反向影响金额。

累计使用 BigInt，中间结果超过 native int 最大值时明确抛 RangeError，不回绕为负金额；Android 是本次支持目标，不能把该保护解释为已验证 Dart Web 精度。

## 数据库与迁移

v1 是 M0 的三表原型；v2 保持原字段与外键，增加约束及私有恢复表。schemaVersion 与公共合同版本相互独立，v2 没有扩展外部备份 v1 或 LedgerMonthData。

初次创建在事务内建立表、索引与八个分类；不写入演示预算/交易。每次打开启用并核验 foreign_keys，并执行 foreign_key_check。索引为 `ledger_entries(occurred_local, occurred_at_utc_ms, id)`。月查询用首日到末日的包含范围，支持9999-12，不构造范围外的 CalendarMonth(10000,1)。

v1→v2：事务外关闭外键；事务内用 Drift TableMigration 复制并重建三张表，按新 CHECK 校验原值，不进行类型转换或数据修补；创建恢复表与新索引；事务内检查外键；最后重新开启外键。非法旧记录导致升级失败并回滚，旧库保留。未知升级路径拒绝打开，不清库降级。

尚未生成或运行 Drift 的正式 schema 导出/迁移测试。D 需要分别从 M0 和本PR生成 schema，验证实际 TableMigration、索引、种子数据与 schema.sql 的一致性。当前 schema.sql 是可执行设计，不声称已经与生成产物逐项验证。

## 原子备份与恢复

readAll 使用同一条全量 UNION 查询读取所有月预算、所有分类（含归档）、所有交易（含收入），不导出恢复表。replaceAll 先验证类型化文档的日期、金额、重复 ID/月、外键、审计字段；合法的空数组允许全量清空。不会在恢复后悄悄重新插入默认分类；是否确认空备份由 A/C 负责。

外部 JSON 版本和语法由 C 的 BackupCodec 检查，B 再检查字段与关系。BackupDocument 的格式版本是静态常量，实例中没有原始文件版本；B 无法在文件版本被解析层丢弃后再次识别它。C 必须先拒绝未知版本，不能先构造 v1 文档再交给 B。

恢复事务中先完整读取旧数据，写入 recovery_snapshots，再按外键顺序替换业务表。保存恢复点失败为 backupFailed，尚未开始删除；后续存储或提交失败为 restoreFailed，整个事务（含本次恢复点）回滚。成功才返回条数与 recoveryBackupId。收入、备注、ID和时间字段完整保留。

恢复点编码为私有版本化数据库格式，不是 C 维护的外部 JSON 备份，不依赖 C 的 codec。具体存储类提供 readRecovery(id) 供主控集成/诊断，返回原有 BackupDocument；A/C 不能把它当已发布的跨模块接口。公共恢复入口与保留/清理策略仍由主控确定，本PR不自动删除旧恢复点，不提供恢复UI。

恢复保留已验证的原始记录，包括有效未来日期的存量记录；普通支出入口仍拒绝未来日期，预算按已发生消费过滤。恢复不依赖设备当前日期改变原备份内容。

## 固定支出及用户设置建议（未实施）

固定支出预留须与已支付支出分开。建议主控新增按月 FixedExpenseReservation：id/month/name/amount/categoryId/settledEntryId?/isCancelled/审计时间；首版可只支持整笔结算，不实现自动周期生成或部分支付。

未取消且未结算的预留总分 R；remaining 保持 B−S，availableAfterReservations=(B−S)−R，dailyAllowance=floor(max(availableAfterReservations,0)/D)。历史月不保留将来现金预留。预留造成的资金缺口不是已发生超支。

结算时原子创建 expense 并关联预留，释放整笔预留；实际支出与计划额不同也以实际支出计 S。关联交易必须为同月支出且不能重复关联；删除支付交易应解除关联并恢复预留；跨月移动需显式解除或拒绝；取消预留不能删除已经支付的交易。

例：150000预算、60000支出、30000未付预留，10月17日每日4000分；实际支付28000后 S=88000、R=0，每日4133分，不能再扣30000。

待主控同时确定模型、LedgerMonthData/BudgetSnapshot 扩展、结算端口、备份版本/迁移、测试归属后实施。用户设置同样没有 v1 合同；建议类型化单行设置（固定CNY、默认分类及更新时间），默认分类必须有效，归档时切换策略由主控/A确定。不自行建立未约定的 key/value 表。

## 已执行验证

环境：Node v24.19.0；Git 2.53.0.windows.3；未发现 Flutter/Dart，没有安装依赖、修改全局设置、生成锁文件或生成Drift代码。

1. `node --test tools/schema.test.mjs`：9/9通过，运行对象为本分支加强约束后的 SQL 设计。包括整数分、金额校验、预算、修改/删除/跨月、收入排除、聚合一致、事务回滚、分类外键、关闭重开。
2. 本地诊断 `node --test .local/verify-core-sql.mjs`：13/13通过。脚本保留在独立 clone 的 .local/，未提交到 D 的测试目录；诊断从实际 Dart 源码提取 SQL 查询/写入字符串。验证有效/无效日历日期、月份、时间戳/ID/备注约束、月/全量快照行映射、预算upsert、CRUD SQL、索引使用、恢复事务提交/回滚，以及 v1→v2 SQL复制演练和约束字面量对照。
3. `git diff --check`：通过。提交前使用仓库 checkOwnership 检查全部12个改动/新增文件，路径全部在B范围内；另检查UTF-8与本地import路径，通过。这些静态结构检查不等于Dart分析。

SQL复制演练没有调用 Drift TableMigration；13项诊断也没有执行 Dart 业务代码、Stream或Timer。两组结果不能合并宣称为“22项核心业务单测通过”。正式 Dart/Drift 编译、单测、迁移测试、Android重启与APK验证均待 D/M1。

## 交给 D 的正式测试场景

| 场景 | 操作与必要断言 |
| --- | --- |
| 正常消费 | 固定2026-10-17，保存150000预算、创建60000支出：余额90000/D15/日均6000；再创建1800：日均5880 |
| 修改/删除 | 通过真实Repository改60000→61000：余额89000；删除后150000；保留ID/created、updated非递减；第二次删除notFound |
| 跨月 | 移动交易至9月，原月与新月都收到完整快照；历史补记不影响10月；固定历史视图在午夜不被切换 |
| 日期边界 | 28/29/30/31天、1900非闰/2000闰/2028闰、月底D1、跨年、9999-12；DB与Repository均拒绝无效日期 |
| 金额与状态 | 一分钱精度、89999/15=5999、零/负/超上限拒绝；无预算null、显式0额度0、超支负余额/额度0；income不减少预算 |
| 分类 | 八个初始分类且无演示账单；新增归档/缺失分类拒绝；旧归档分类可保留；不得硬删被引用分类 |
| 审计/排序 | 相同occurred时间按ID排序；回拨Clock后updated不倒退；编辑保留发生瞬间和创建字段；时区变化不迁移localDate |
| 并发一致性 | 一个事务同时改预算与交易，watchMonth只发完整前态/后态；初始空月发分类；查询失败走onError |
| 跨日应用层 | 注入Clock并调用refreshDate：分母变化；null月参数跟随新月；固定月不切换；旧月迟到事件不覆盖新月；dispose/取消无悬挂Timer |
| 流失败恢复 | Repository报错后不再用旧数据伪装成功；显式refresh触发重新订阅；错误转稳定异常；上游结束释放资源 |
| 文件持久化 | NativeDatabase临时文件写入、close/reopen后所有字段一致，不以内存库替代重启验收 |
| 实际迁移 | 从M0生成v1库，放合法及坏日期夹具；执行真实v1→v2，检查全字段/外键/索引/版本/回滚；生成schema与SQL对照 |
| 全量备份 | 多月份、归档类别、income、特殊备注与审计字段无损；读取具有一致快照，恢复点不嵌套导出 |
| 恢复校验 | 重复ID/月、孤立分类、坏时间拒绝，旧库不变；空备份合法；文件未知版本在C层拒绝 |
| 恢复原子性 | 注入恢复点写失败/替换中途失败/提交失败，旧数据不变；成功的recoveryBackupId可读回旧数据；重复恢复ID失败不清库 |

建议 D 使用注入 Clock/ID、NativeDatabase.memory、临时文件库与受控失败执行器；不使用真实账单。D 持有 test/ 与 integration_test/，B 不在模块目录伪装提交正式测试。

## 来源与限制

参考思路而非复制代码：[Cashew固定提交预算卡](https://github.com/jameskokoska/Cashew/blob/9cfbe50c16d95429891d44faf5f2c77a3abdb93b/budget/lib/widgets/budgetContainer.dart#L423)，已读取423–516行：剩余天数包含今天，日均考虑预算/累计金额差及预算极性；原版浮点金额未沿用。

已核对 [Drift查询流](https://drift.simonbinder.eu/dart_api/streams/)、[事务](https://drift.simonbinder.eu/dart_api/transactions/) 与 [迁移API](https://drift.simonbinder.eu/migrations/api/)。旁路原生写入不会自动通知Drift，本模块所有写入均声明更新表；迁移外键PRAGMA位于事务外，完整性检查在事务内。

PR应保持Draft，待D完成真实生成、format/analyze、业务/迁移测试以及主控composition审查再决定合并。固定支出、设置、恢复UI及Android验收均不在本次已实现或已验证清单内。
