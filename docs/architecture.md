# PocketFlow 架构与协作规范

状态：合同 v2.0.0 集成候选，2026-10-17；本分支 0.2 收支体验更新见 ADR 0005，合并前 main 仍为 v1.0.0。MVP 已完成正式装配和自动测试。实际 Android 构建及设备验收状态见 docs/status.md 与 docs/apk-delivery.md。

## 1. 唯一权威来源

GitHub 的默认分支 `main` 是所有开发对话共享代码、接口和决策的唯一权威来源。统一公开仓库为 [yuminhang666-oss/PocketFlow](https://github.com/yuminhang666-oss/PocketFlow)，clone URL 为 `https://github.com/yuminhang666-oss/PocketFlow.git`。负责人已核验当前连接具备 push 权限。实际初始化/同步状态与基线提交见 `docs/status.md`；模块必须以远程 main 的已发布合同为起点。

每个对话开始或续接都必须先读取仓库中的 `AGENTS.md`、本文件、`docs/data-contracts.md`、`docs/interfaces.md`、`docs/ownership.md`、`docs/milestones.md` 和自己的交接文件。不能假定可以读取另一个对话的聊天、本机文件或未合并分支。PR 链接和 commit SHA 是交付标识；聊天中的“已完成”不是共享代码证据。

## 2. 产品边界

第一版针对个人 Android 手机：单币种人民币、自然月生活费、支出优先、快速记账、本地 SQLite、动态图表、Markdown 月报、JSON 完整备份。无需账号或后端；没有自动上传、云同步或付费 AI API。真实可运行 APK 是最终验收对象。原型数据与测试夹具不得写入用户正式数据库。

核心闭环：设置月预算 → 新增/编辑/删除消费 → 本地事务成功 → 月份数据流更新 → 每日额度重新计算 → 重启仍可读取。先交付这个闭环，再加入图表与导出。

## 3. 固定技术选择

| 层 | 决策 | 理由 |
| --- | --- | --- |
| 客户端 | Flutter stable + Dart，Android 首发 | 沿用项目约定，减少独立开发维护成本 |
| UI | Material 3，中文，响应式布局 | 主流 Android 交互与无障碍基础 |
| 状态 | Riverpod 3；首版手写 Provider | 便于注入测试替身，减少状态代码生成依赖 |
| 存储 | Drift + SQLite，本地应用目录 | 类型化查询、迁移、事务与可观察查询 |
| 领域 | 纯 Dart、整数分金额、明确日历类型 | 独立测试，不让 UI/图表改变财务口径 |
| 图表 | fl_chart 1.2.0，已统一启用 | 只在图表坐标层使用 double |
| 文件 | Markdown 与 JSON 独立服务；系统文件选择/分享适配器 | 月报不是备份；平台权限隔离 |
| 工程 | 一个仓库、独立分支、PR、负责人集成 | 避免跨对话隐式状态与目录冲突 |

当前 pubspec 已固定兼容版本并提交真实生成的 pubspec.lock；禁止手写锁文件或依赖安装假成功。已核验官方文档支持的分层和查询流见 [Flutter](https://docs.flutter.dev/app-architecture/guide)、[Drift](https://drift.simonbinder.eu/dart_api/streams/)、[Riverpod](https://riverpod.dev/docs/introduction/getting_started)。

## 4. 目录与依赖方向

```text
lib/
  main.dart                         # 负责人：唯一入口和应用装配
  app/
    composition/                    # 负责人：实际实现的注入、跨模块接线
    pocketflow_app.dart              # A：App 壳与页面
    theme/ routing/                  # A：主题和 UI 路由
  core/
    domain/                         # 负责人：唯一共享数据模型
    database/                       # B：Drift 表、迁移、数据库连接
  contracts/                        # 负责人：跨模块接口与错误协议
  shared/widgets/                   # A：共用 UI 部件
  features/
    home/ entry_editor/ ledger_list/ settings/
      presentation/                 # A：页面、表单与交互
    budget/
      domain/ application/          # B：预算算法与响应式状态
    transactions/
      domain/ application/ data/     # B：记账校验与 Repository 实现
    statistics/ export/ backup/     # C：统计、导出和备份实现
test/ integration_test/              # D：自动测试
android/                            # D：Android 平台工程与构建；已生成并补齐文件通道
.github/workflows/                   # D：CI，禁止发布或暴露密钥
docs/                               # 共享规范与交接
design/                             # A：Figma 与设计源文件
tools/                              # D：可重复验证工具
```

共享模型不得依赖 Flutter、Riverpod、Drift 或 fl_chart。接口只依赖共享模型和 Dart 标准库。B/C 可依赖 contracts 与 core/domain，但不得导入 A 的页面；A 通过注入接口或应用状态使用 B/C，不导入 Drift 生成实体或直接操作 SQLite。C 不读写 B 的内部表，所有读取通过 LedgerRepository，恢复通过 BackupStore 的原子操作。跨功能组合和真实 Provider 注入只由负责人在 composition 接线。

## 5. 数据一致性

一个 `LedgerMonthData` 包含同一个事务快照读取出的预算、当月完整记录、分类和个人设置 profile。一次查询流通知不得把旧预算与新交易拼成一个快照。B 可用 Drift 自定义聚合/事务读取实现；不能用两个独立订阅简单 combine 后声称原子一致。A 的界面、B 的 BudgetCalculator、C 的 MonthlyReport 都使用同一个快照。

月数据包含该月全部已保存记录；预算和月报按 `asOfLocalDate` 过滤已发生消费，首版写入拒绝未来日期。当前月默认截止今天，历史月截止月末，未来月只用于预算规划。未来收入不计入可支出预算。

日期 Provider 在本地午夜及应用恢复到前台时刷新，跨月时自动切换“当前月”，但不强行改掉用户正在查看的历史月份。记录的本地归属日期写入后稳定，不因更改时区而重新分月。

## 6. 错误与变更

存储/导出/恢复失败使用 `PocketFlowException` 的稳定错误码；UI 映射成中文，不直接呈现 SQL 异常或文件路径。Stream 的错误通过 onError 传递，不能返回空列表伪装成功。写入完成 Future 才代表保存成功；失败保留用户输入，不重复记账。

接口、共享模型、数据库 schema、依赖版本与根配置属于受控面。模块提出变更申请 → 负责人记录 ADR → 修改 contract 并发布新版本 → 下游适配 → 测试通过 → 集成；不同对话不得各自添加相似但不兼容的 DTO。首次冻结版本为 v1.0.0；变更需要标明是否破坏兼容性与迁移方式。

## 7. 授权与发布

本次授权涵盖 PocketFlow 架构、仓库初始化、模块分支与 PR 协作；不涵盖公共发布、账单上传、签名密钥外传、全局环境修改。安装工具或连接权限不足时，完成可审阅内容后说明具体最小操作。其他对话不得向 main 提交或推送，负责人统一审查/合并，禁止 force push 和未经协调重写共享历史。

发布开源许可证尚未确定。参考项目的代码没有复制到工程中；调研来源见 `01-research.md`。Figma 空白文件与未完成构建脚本已留作 A 的输入，尚未形成可交付四页界面，不可标为完成。


## 8. MVP 集成决定

正式装配、schema v2、兼容依赖锁和 Android 原生文件通道见 [ADR 0002](decisions/0002-mvp-integration.md)。本次依赖解析、Drift 生成、静态分析及 38 项 Flutter 测试已通过；设备行为不能由这些结果替代。工具安装与 SDK 许可已有用户针对 D:\Codex\PocketFlowTools 的明确授权，未改全局 PATH。

2026-10-17用户追加明确授权：将PocketFlow仓库改为公开，并公开既有Debug测试版下载。该决定见 [ADR 0003](decisions/0003-public-test-download.md)，覆盖上文关于当前仓库可见性与本测试版公开下载的旧限制；账单及签名私钥上传仍未获授权。


Android插件打包与固定测试签名的交付门禁见 [ADR0004](decisions/0004-android-startup-and-update-signing.md)。0.1.1已直接在实际Android模拟器验证核心流程、原生文件保存/恢复及覆盖更新，物理手机复测仍由用户进行。
