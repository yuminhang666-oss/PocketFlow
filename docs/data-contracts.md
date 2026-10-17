# 数据合同 v1.0.0

唯一 Dart 定义在 `lib/core/domain/`。数据库实体、JSON、图表和 UI 均映射到这里；不得自行复制另一份 Money、Transaction、Budget 或 Report DTO。字段增加/改名须负责人更新本合同和接口版本。

## 金额与标识

`Money.fen` 是人民币整数分，允许负值用于计算结果。用户输入及持久化的单笔正金额上限 99,999,999,999 分；预算允许 0，交易必须 >0。解析十进制字符串时不能先转 double。每天建议额度向下取整到分，不足一分余额留存。图表坐标允许把已经汇总的分转换成 double，不能回写财务结果。

账单 ID：B 生成不重复 UUID v4 字符串；传输/备份层把它当不透明非空字符串（最长64），不依赖 ID 的排序含义。分类稳定 ID 为 food/drinks/shopping/transport/study/fun/health/other。默认餐饮；历史分类只归档，不硬删。

## 共享模型

| 模型 | 字段 | 语义 |
| --- | --- | --- |
| CalendarMonth | year, month, key, days | year 1900–9999；key 为 YYYY-MM；闰年按日历计算 |
| Category | id, name, sortOrder, isArchived | 全部分类（含历史归档），不靠颜色识别 |
| MonthlyBudget | month, amount, updatedAtUtcMs | 未设置用 null；0 是明确设置，收入不自动改变预算 |
| LedgerEntry | id, amount, localDate/date, categoryId, kind, note, occurredAtUtcMs, createdAtUtcMs, updatedAtUtcMs | kind 为 expense/income；金额始终为正；时间为 UTC 毫秒整数 |
| EntryDraft | amount, localDate, occurredAtUtcMs, categoryId, note | 首版只创建/修改支出；ID、kind、创建/修改时间由 B 管理 |
| LedgerMonthData | month, budget, entries, categories | 不可变列表；同一数据库快照；记录按消费时间降序、ID稳定排序 |
| BudgetSnapshot | month, period, budget, spent, remaining, remainingDays, dailyAllowance | 已有算法返回类型；见计算规则，未设置/历史额度用 null |
| MonthlyReport | month, asOfLocalDate, budget, totalExpense, remaining, daily, categoryTotals, entries | C 的图表与 Markdown 共用；日/分类合计等于总支出 |
| BackupDocument | appId, formatVersion, exportedAtUtcMs, currency, budgets, categories, entries | 全量 JSON 数据；不含设备私密路径、签名密钥或临时统计 |

`localDate` 固定 YYYY-MM-DD，表示用户选择的消费归属日；内部 DateTime.utc 只用来承载日历组件，不是实际消费瞬间。UTC 时间戳表示实际时间；录入回溯账单时根据选择的当地日期/时间生成并保存，不在导出时重新推算。预算、报表以 localDate 过滤，排序以 occurredAtUtcMs + id。支持年份范围外、无效日期、非整数时间戳均拒绝输入/恢复。

模型采用不可变值；列表防御性复制且不可修改。存储读出来的无效数据应报 dataCorrupted，不能悄悄修成另一个金额或日期。

## 预算口径

- 当前月：累计该月截至今天所有 expense，包含今天；剩余天数含今天。
- 过去月：统计整月，remainingDays=0，dailyAllowance=null。
- 未来月：spent=0，按整月天数显示“计划日均”，不声称已发生消费。
- 无预算：spent 正常显示；budget/remaining/dailyAllowance 为 null。
- 超支：remaining 可为负；dailyAllowance 为 0，并显示超支金额。
- 显式0预算：不计算进度百分比，不将无预算与0混为一谈。

原始预算使用率可超过100%，只有绘制条形时截断。删除/修改/跨月移动账单重新聚合；不保存累计支出字段。

## 月报口径

`MonthlyReport` 输入为 `LedgerMonthData` 加明确截止日期。当前月默认今天，过去月默认月末；未来月份拒绝生成“实际消费月报”。保留所有 expense 明细；income 暂不开放录入，但模型和备份须保留，月报支出合计不包含收入。逐日序列从1日至截止日补零，截止日后的实际图表值为空而不是0。分类列表保留金额及分母；零支出时百分比为null，图表空态。

理论预算线表示每日结束时均匀消费参考：预算分 − floor(预算分 × 当日序号 / 当月天数)。所有金额保持整数分；前后同一口径。金额格式始终两位小数，原始数值不得经过本地化带千位符格式再解析。

## JSON 备份合同

`appId="pocketflow"`，`formatVersion=1`，`currency="CNY"`。所有金额字段统一 `amountFen` 整数；绝不输出 amount 的浮点元值。所有时间字段明确 `...UtcMs`。模型中的 month/date 对应序列化的 YYYY-MM/ YYYY-MM-DD；EntryKind 序列化为 `expense` 或 `income`。

根对象必须包含 budgets/categories/entries 三个数组（允许空）；未知附加字段可忽略，未知更高版本拒绝；缺失必填字段、重复ID/月份、孤立分类、非法日期/金额/枚举/时间戳均拒绝。完整结构示例见 `docs/examples/backup-v1.json`，是虚构夹具，不可导入正式用户数据库作为默认账单。

恢复首版只支持全量替换，不实现隐式合并。先预检并显示条数，明确提示会替换手机现有记录；用户确认后，B 在同一写入锁/事务中先保留当前完整备份再替换，验证失败或取消不得改变原库。备份的恢复点标识由 B 返回，C 交给 UI 呈现；不能在错误处理里清空数据库。
