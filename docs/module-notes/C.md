# C · 消费统计、Markdown、JSON 与文件适配

2026-10-17（Asia/Shanghai）。合同 v1.0.0；基线 `26d8e4b47eef5d17fe2ca8385da3ddb58adce95e`；主控预留分支 `feat/c-report-backup`。本轮是可审阅源码与独立参考验证交付，**不是 Flutter、图表、系统分享或真实数据库恢复已验收**。

## 前置检查与隔离

- 已从 GitHub main 读取 AGENTS、architecture、data-contracts、interfaces、ownership、milestones、status 和 C 交接；实际合同文件为复数 `docs/data-contracts.md`，没有另造单数版本。
- GitHub 连接器能够读取；本机 Git 因 credential helper/MSYS 子进程失败无法认证。远程 A/B/C 初始均指向上述 M0 基线，B 本地提交不是已合并公共实现。
- 找到 B 的独立目录 `D:\Codex\记账\.local\B`，提交 `3312266b1a8743d21fbba880b73c59885ed8c01a`。已读取 B 交接、LedgerRepository/BackupStore 实现、校验器与 SQL；对照该提交与 M0，共享 core/domain、contracts 和接口文档无差异。C 依赖公共端口，不导入 B 私有表、恢复 codec 或 provider。
- 在 `D:\Codex\记账\.worktrees\C` 建立独立 Git 对象库和工作树。复制已有基线对象后核对 Git tree 为远程相同的 `5537a8c888ef85fd68c65a4aafa3035968d46d76`；没有切换、修改或合并 A/B/主控工作树。
- Flutter/Dart 不在 PATH，项目 .tooling 及常见 Flutter 目录未发现工具；未安装工具、依赖、修改根配置或全局设置。

## 实现与指标口径

| 入口 | 作用 |
| --- | --- |
| `DefaultMonthlyReportService` | 输入 LedgerMonthData 和截止日；重建 MonthlyReport，无累计缓存 |
| `MonthlyReportInsights` extension | 支出/收入笔数、自然日日均、单日最高及全部并列日期、分类占比、预算使用率 |
| `monthlyChartData` | 全月每日坐标投影；截止日后 actual 为 null；余额与均匀消耗参考线 |
| `DefaultMarkdownExporter` | 同一报告生成规范 Markdown，不访问数据库、平台或网络 |
| `JsonBackupCodec` | 完整 v1 JSON 编解码及严格预检，不写库 |
| `ReportExportService` / `BackupTransferService` | 经 FileTransferPort 保存／分享；恢复先选文件、预检、逐次明确确认，再调用 B 的 replaceAll |
| `AndroidFileTransferPort` | Flutter MethodChannel 适配半边，**须等待 D 的 Android host，不能直接当作已可用功能** |

金额始终整数分；累计与乘除中间值使用 BigInt，转换 native int 时检查溢出。只有待启用图表源码将已汇总金额转换 double 画坐标。报告中的百分比使用整数有理数四舍五入至两位小数，使用率可超过100%；无预算与显式零预算的使用率均不适用，但余额状态不同。

日均为总支出／月初至截止日的自然日数，包括零消费日，四舍五入至分；不是 B 的每日建议额度。最高日期保留全部并列；零支出没有“最高消费日期”。当前月默认今天，历史月默认月末，显式截止日可缩短统计范围；未来实际月报拒绝。月份切换、删除、编辑、跨月移动通过新快照重新聚合。

所有截止日内的交易保留在逐笔表，包括兼容的 income，并标明类型；日／分类／支出合计只计算 expense。JSON 保留所有月份、归档分类、收入、未来合法存量记录、ID、备注与所有审计时间，独立于月报截止日。

余额趋势 = **当前预算** − 累计实际支出；参考线 = 预算 − floor(预算 × 日序／当月天数)，到月末为0。v1 没有预算修改事件，因此无法重建实际历史调额轨迹，也不将参考线称为预测。若要“预算金额修改趋势”，请主控先增合同与备份版本／迁移设计。

## Markdown 格式与示例

包含统计月份／截止日／本地导出日／UTC导出时刻、预算、分类与占比、逐日补零汇总、完整逐笔记录、关键指标、可选 AI 提示词。每项金额两位小数；交易归属日保持稳定，发生瞬间明确显示 UTC。备注、分类名、ID 转义 Markdown、HTML、管道及换行，避免破表或插入 HTML。提示词明确将备注视为数据；应用不发起 AI 网络调用。

- 月报参考：`lib/features/export/examples/fixture-report-2026-10.md`
- 备份夹具：`lib/features/backup/examples/fixture-backup-v1.json`

两者均是**虚构验证夹具与预期输出**，不是用户真实账单，也不是未运行的 Dart 导出器生成结果。夹具专门含收入、截止日后记录、归档分类和特殊备注。预期：预算1500元，截止10月17日支出618元，余额882元，使用率41.20%，日均36.35元，最高600元；10月17日参考余额677.42元。没有提供可使用的个人真实账单，本轮没有接触或上传真实财务数据。

## JSON 与恢复边界

v1 必填 appId/formatVersion/exportedAtUtcMs/currency 及三个数组；只接受原生整数金额／时间，不接收浮点、数字字符串或自动类型转换。缺字段、未知版本／币种／枚举、无效金额／日期／时间、重复类别／交易ID／预算月、孤立分类、审计倒序均拒绝。未知附加字段可忽略。合法空备份允许，但同样必须确认全量替换。

一次 restore 从选文件开始加服务级互斥；取消／预检失败／拒绝确认不调用 replaceAll，失败不重试、不合并；重复确认导入同一备份执行全量替换，不累加交易。返回 B 的恢复点 ID。**真正的数据库排他锁、恢复前快照、事务和回滚在 B 中，本轮参考验证不覆盖这些运行行为。** A 必须展示条数、全量覆盖警告、空备份影响及成功后的恢复点标识；主控须保证单例服务注入和全局写入协调。

## 主控与 A/D 的集成依赖

1. **fl_chart 依赖申请**：建议主控单独审核固定 `fl_chart: 1.2.0`，MIT，Dart ≥3.6.2、Flutter ≥3.27.4。包未声明独立 Android minSdk，不能把 Flutter 最低版本换算成已验证的 Android 最低API；D按最终工具链／生成平台验证。来源：[官方包页](https://pub.dev/packages/fl_chart)、[固定版本 pubspec](https://github.com/imaNNeo/fl_chart/blob/1.2.0/pubspec.yaml)。未解析／安装任何依赖。
2. 三个可复用组件源码已准备在 `lib/features/statistics/presentation/pending/fl_chart_widgets.dart.txt`。主控依赖 PR 合并后，在**原目录**改名为 `.dart`，由 D 编译与 widget 测试再启用。当前使用 `.txt` 防止给基线引入未批准的包导入，**不能宣称图表已运行**。提供 CategoryExpenseDonut、DailyExpenseBars、RemainingBudgetLines；使用主题色、环图外部金额／百分比图例、可滚动日期轴、精确触摸金额、实／虚线区分和可展开文本明细；没有重构 A 的页面。
3. Flutter→Android 协议通道 `pocketflow/file_transfer/v1`：`saveText` 和 `shareTextFile` 参数 `{suggestedName: String, mimeType: String, bytes: Uint8List}`；返回 bool（成功true，取消false）。`pickJsonText` 无参数，取消null，否则 `{name: String, bytes: Uint8List}`。Flutter端严格解 UTF-8，仅移除一个 BOM；非法字节拒绝。错误／未实现 channel 映射 exportFailed/importFailed。
4. **D host 请求，未实施**：save 用 ACTION_CREATE_DOCUMENT，通过 ContentResolver 完整写入 UTF-8 bytes，关闭成功才true；pick 用 ACTION_OPEN_DOCUMENT 并读取原始字节；share 用私有临时文件+FileProvider+ACTION_SEND+只读 URI 授权。限制文件名路径段，避免外部任意路径，兼容重复文件名与多次调用；临时文件延迟清理，不在接收方读完前删掉。取消按协议返回，不吞 I/O 错误。分享 true 只能表示系统接受分享派发，不能声称接收方保存完成；能够识别的取消返回false。应用不得预选云盘、后台上传或请求广泛存储权限。本分支没修改 android/、manifest 或插件依赖。
5. A 使用公开服务接入自己的按钮／确认框；主控 composition 注入真实 LedgerRepository、BackupStore、Clock、FileTransferPort。页面按 B 的新快照构建报告；午夜与前台恢复由主控日期状态刷新，不能只等数据库有写入才更新截止日。

```dart
final reports = DefaultMonthlyReportService(clock: clock);
final report = reports.build(snapshot,
  asOfLocalDate: reports.defaultCutoff(snapshot.month));
final markdown = DefaultMarkdownExporter(clock: clock, includeAiPrompt: true);
final exports = ReportExportService(files: files, markdown: markdown);
final backups = BackupTransferService(store: backupStore, files: files,
  codec: const JsonBackupCodec(), clock: clock);
// A: await exports.share(report);
// A: await backups.restore(confirm: showExplicitReplacementConfirmation);
```

## 实际验证与未验证项

工具：Node v24.19.0（已有运行器），Git 2.53.0.windows.3。未配置全局 PATH。

`git diff --cached --check` 通过；仓库 `checkOwnership` 对15个新增路径检查通过，全部在C范围。它们属于静态检查，不等于 Dart analyze。

实际运行 `node --test lib/features/export/verification/reference_checks.mjs`：**9/9通过**。默认加载本分支 M0 SQL 设计，在内存 SQLite 装入明确虚构的 JSON 夹具，以独立 SQL 聚合核对参考 Markdown；覆盖总支出／收入排除／截止日、分类占比、日补零／平均／峰值、修改删除跨月、整数参考线、表格转义结构、UTF-8与相对导入、纯域层不依赖平台／网络。

设置当前进程 `POCKETFLOW_VALIDATION_SCHEMA=D:\Codex\记账\.local\B\lib\core\database\schema.sql` 再运行同一命令：B 最新本地 SQL 设计上同样 **9/9通过**。这是同一组参考检查在两个 schema 上的兼容性核对，**不是18项 Dart单测**，未执行 Drift 生成实体／Repository／Stream／事务恢复实现。

独立 C 检查入口 `lib/features/export/verification/c_contract_checks.dart` 已编写，直接调用实际 Dart 实现，覆盖统计边界、溢出、闰年、空态、零预算／超支、稳定排序、备注转义、Golden输出、JSON全字段往返与坏文件、取消／确认／并发恢复／不自动重试。工具链就绪后执行：

```text
dart lib/features/export/verification/c_contract_checks.dart
```

**上述 Dart 检查未运行**。`dart format`、`dart/flutter analyze`、`flutter test`、fl_chart widget 渲染、系统文件选择／分享、真实数据库替换／恢复点、Android启动与APK均未执行，不能据参考输出或源码断言通过。D仍负责 test/ 中的正式合同／集成测试；C没有修改 D 的 test/、tools/ 或 CI。

## D 的正式验收重点

- 使用真实 Dart 调用对照两个预期文件；补足1分钱／大累计／native溢出、28/29/30/31天及9999-12、月份切换与删除后重新构建。
- 检查 JSON 缺失字段、null、浮点整数形态、数字字符串、越界时间、非法日期、未知版本、重复分类／ID／月份、孤立引用、收入与归档保留、空备份；验证两个方向不能静默丢字段。
- MethodChannel mock 验证中文 bytes、MIME／扩展名、BOM、无效UTF-8、取消、错误返回类型与MissingPlugin；真实Android验证SAF/FileProvider权限及接收应用可读。
- 真实 B store 验证取消／坏文件不写库、恢复前快照保存失败、写入或提交失败回滚、重复恢复无重复行；恢复点可找回旧库。
- 依赖获批后启用图表，验证320/360/412dp、字体1.0/1.3/2.0、浅深色、0／无预算、无消费、收入-only、超支负余额、截止日后无实际值、文字读数与TalkBack，不把颜色当唯一识别。

## 交付与后续

仅提交 C 所有权目录及本文。远程交付走预留分支→main 的独立**草稿 PR**，主控审查合并。即使网络不可用，本目录的源码、参考验证脚本、Dart检查、预期示例与 Git 记录都保留；不因缺少编译证据宣称 M3/M4 完成。
