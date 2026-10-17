# A · UI 首个 PR 交付

2026-10-17（Asia/Shanghai）。基线 `26d8e4b47eef5d17fe2ca8385da3ddb58adce95e`；合同 v1.0.0；分支 `feat/a-ui-mvp`。当前为等待 Flutter 运行验证与 composition 接线的实现稿，不是可安装 MVP。

## 已实现的源码

- 森林绿 Material 3 主题：浅色、深色、跟随系统；系统字体、等宽金额数字、完整精度及千位分隔。
- 首页：日额度、月预算/支出/余额、进度、最近五笔、快速记账回调、月份选择控件。未设置/零预算/超支/历史月/未来月/加载/错误/旧数据刷新失败的显示分支。
- 快速记账：九位整数与两位小数字符串编辑、可用分类、日期、备注弹层、保存等待及失败保留、防重复提交、草稿放弃确认。
- 全月列表和详情：列表惰性构建，完整金额，详情中备注可选取和完整读取；本次不实现编辑/删除业务。
- 三项导航壳、设置回调入口、预算编辑弹层；未接入动作禁用，不模拟导出或恢复成功。
- 10 种明确隔离的 Mock 场景与本地静态视觉样稿，不写入正式账本。

未改数据库、算法、共享模型、contracts、依赖、main.dart、composition 或 D 的 test/。C 的图表本体与文件实现保持其所有权。

## 主控接线方式

`PocketFlowApp(home: ..., themeMode: ...)` 接收实际页面和主题状态。默认不注入 Mock；若仍使用 M0 的无参数入口，显示“正在准备账本”加载占位，需要主控在 composition 接入后才有正式业务界面。

主控将一个 `LedgerRepository.watchMonth(month)` 的原子月快照映射为首页的 `AsyncValue<(LedgerMonthData, BudgetSnapshot)>`。同一快照经 B 的 BudgetCalculator 派生额度再组成 record；不能分别订阅预算和交易并拼出“原子”数据。HomePage 不导入算法、Drift 或数据库。

```dart
// 示意：位于主控 composition 的 provider/装配中，不由 A 定义具体 provider 名。
final pair = monthAsync.whenData((ledger) {
  final snapshot = calculator.calculate(
    month: ledger.month,
    today: clock.now(),
    budget: ledger.budget?.amount,
    entries: ledger.entries,
  );
  return (ledger, snapshot);
});
// HomePage(month: selectedMonth, state: pair, ...callbacks)
```

正式记账调用方用 `Navigator.push<LedgerEntry>` 打开 QuickEntryPage，传入有效分类、Clock，以及 `onSave: repository.createExpense`。页面等待 Future 成功并返回 LedgerEntry；调用方提示“已保存支出”，首页由快照流刷新，不能在 UI 先行加账。分类列表必须来自最近一次可靠月快照；类别变化时更新页面输入，失效选择需重新确认。

预算使用 `showBudgetEditor(context, month: ..., initialBudget: ..., onSave: (amount) => repository.saveBudget(month, amount))`。helper 禁止点击遮罩或拖动关闭，保存时禁用取消；完成后等待数据流更新。历史账单、明细、月份选择、刷新和主题回调按主控路由/Provider 接入。主题持久化、午夜/恢复前台刷新均由主控/B 实现。

`PocketFlowShell` 的 statistics 插槽交给 C 的页面，settings 插槽传入 SettingsPage。导出/备份/恢复目前仅提供 VoidCallback 入口，由主控协调 C 的服务流程，未接入前保持禁用。

## Mock 预览

依赖由主控/D 准备后运行：

```powershell
flutter run -t design/ui-ux/preview.dart
```

入口有常驻“演示环境 · 示例数据不保存”标记；菜单切换正常、空账单、无预算、零预算、超支、历史月、未来月、加载、读取失败、保存失败。默认时钟固定 2026-10-17；示例预算 1500 元、累计支出 600 元。记 18 元时复用 B 的已有算法，预期日额度 58.80 元。演示写入只修改当前预览内存，关闭后丢失；不实现另一个 Repository、数据库或预算算法。

设置页可切浅/深/跟随系统；月份可切换；明细可查看；保存失败场景用于检查草稿保留。预览代码本轮未运行，以上是入口能力与预期，不是测试通过声明。

## 实际验证记录

| 检查 | 工具与结果 | 限制 |
| --- | --- | --- |
| M0 来源与隔离目录 | 通过 GitHub 连接读取远程规范；55 个文件与远程 blob SHA 一致；本地 HEAD 为上述 M0 SHA | Git HTTPS 凭据辅助进程不可用，发布通过已有 GitHub 连接；未触碰主控工作树的分支与改动 |
| UI 文件所有权 | `node design/ui-ux/inspect-ui.mjs`：变更路径均在 A 范围内 | 静态路径检查 |
| 相对导入/受控层依赖 | 同脚本：21 个 Dart 文件，无缺失的项目内导入，无 UI 对数据库/预算算法/Mock 入口的导入 | 不解析第三方包，不等于 Dart analyze |
| 错误文案 | 同脚本：v1 全部 12 个错误码都有对应中文映射 | 未运行错误场景 Widget |
| 文本对比度 | 同脚本：9 对文字/背景，浅深色合计 18 项均 ≥4.5；最低为浅色 muted/canvas 4.60 | 数学计算，不等于读屏/设备测试；弱分隔线未作为交互边界 |
| 静态视觉样稿 | 本机 Edge 155.0.4283.45，1640×1060 PNG；已人工查看四个画面 | 是 HTML 设计样稿，不是 Flutter 截图 |
| 样稿修正 | 首次发现记账页保存按钮裁切；压缩样稿间距后重渲染，按钮与底部空间均可见 | 仅验证设计样稿；实际 Flutter 用滚动布局处理小高度 |
| 文本变更检查 | `git diff --check` 无错误 | Git 的 LF/CRLF 提示不属于代码验收 |
| Node | v24.19.0 | 只用于静态检查 |

Edge 在限制沙箱内启动崩溃，未生成截图；改为经过自动审核许可的本地无窗口运行后完成渲染。没有安装浏览器、Flutter 或依赖。

Flutter/Dart 仍不在 PATH，指定 D 盘项目工具目录未发现工具链。本轮未运行 `dart format`、`flutter analyze`、`flutter test`、依赖解析、APK 构建、Android/Flutter 渲染或 TalkBack。不得把设计样稿或 Node 静态检查写成上述运行验证通过。

## 交给 D 的运行验收清单

1. 首页：1500−600，10/17 含今天 15 天，60.00/天；无预算与显式零预算不同；超支余额绝对值显示在“已超支”项，日额度零；过去月不显示日额度；未来月为计划日均。
2. 流状态：初载不出现假 0；首次错误可重试；刷新错误保留旧结果并标识；月份切换时不能把旧月快照冒充新月；后台返回与跨午夜由 B 更新时 UI 正确刷新。
3. 保存：模拟延迟 Future 并连续点击，只调用一次；成功前不能返回/改字段；失败后金额、分类、日期、备注完整保留；只在成功后返回实体。由 B 集成测试验证真实保存成功后刷新及重启持久化。
4. 输入边界：空、0、0.01、尾随小数点、第三位小数、九位整数、上限 999999999.99、超限；无可用分类与已归档分类；日期未来及页面跨日；备注 500 个 UTF-16 单元和含 emoji 的超限粘贴。
5. 返回：空稿直接返回；输入后清空并恢复初始分类/日期可直接返回；有改动则确认，取消放弃继续保留；系统返回和 AppBar 返回一致。
6. 尺寸：320/360/390/412/480dp；字体 1.0/1.3/2.0；浅/深色；横屏、小高度、系统键盘与手势/三键导航。没有金额省略、RenderFlex overflow、保存按钮遮挡或不可滚达的分类。
7. TalkBack：数字键、删除、小数点可操作且不重复输入；分类选中状态、金额方向、错误 live region 可读；预算键盘与备注键盘退出后焦点合理。
8. 长列表/长备注/大金额：列表惰性构建；金额完整；详情备注完整；归档/未知分类仍可显示历史账单。数据管理未接入时不能触发虚假的成功反馈。

## 未解决问题与集成依赖

- 必须先由 D 完成 M1 工具链，运行格式化、分析、Widget/设备检查；源码尚未经过 Dart 编译，PR 保持 Draft。
- 主控需把 PocketFlowApp 的 home 与主题状态、B 的原子快照/保存接口接入；无参数正式入口目前仅加载占位。
- 新增后实际预算刷新、跨午夜、持久化等待 B 与主控；预览内存反馈不能代替数据库验证。
- C 提供图表、导出与备份恢复；本 PR 不处理恢复确认、文件选择和恢复点展示。
- 记录编辑/删除交互、真实类别加载重试流程与主题持久化后续按主控集成范围推进；未自行扩展 v1 合同。
- 未修改在线 Figma；HTML 样稿与本地设计图用于本轮审阅，现有失败的 Figma 草稿仍不标记为完成。

官方 API 检查参考：[Flutter ThemeData.copyWith](https://api.flutter.dev/flutter/material/ThemeData/copyWith.html)、[PopScope](https://api.flutter.dev/flutter/widgets/PopScope-class.html)、[Riverpod AsyncValue](https://pub.dev/documentation/riverpod/latest/riverpod/AsyncValue-class.html)。仅核对接口用法，不能替代实际编译。
