# PocketFlow QA 与环境验证报告

日期：2026-10-17（Asia/Shanghai）。角色 D。合同 v1.0.0。
基线：远程 main `26d8e4b47eef5d17fe2ca8385da3ddb58adce95e`；独立分支 `chore/d-test-build`。

## 当前结论

优先完成网络、Flutter/Dart 与可重复验证环境，不以 APK 为本轮首要交付。当前 main 是 M0 架构基线，包含共享模型、合同、预算算法、Drift 表定义与静态首页；实际 Repository、统计/导出/恢复、正式依赖装配与 Android 工程尚未交付。不能把这些功能记为测试通过。

GitHub 连接器与经现有系统代理的 Git 私有仓库读取均成功。原命令行直连超时；Git 默认未读取 Windows 系统代理。沙箱内另有 MSYS/凭据助手启动失败，正常执行环境可使用已有凭据，无需复制令牌或修改全局配置。

Flutter3.47.7/Dart3.13.5已在D盘安装、官方SHA256校验通过，版本命令与doctor实际运行成功；doctor确认网络资源可访问，但Android SDK缺失。**原始M0依赖解析失败**：build_runner2.17.1要求build5.x，drift_dev2.35.1要求build<5。主分支不能进入编译/测试，不得标记M1完成。公共依赖文件未修改。

候选诊断克隆（全英文路径`D:\Codex\PocketFlowTools\probes\m0-candidate`）仅将build_runner改为2.16.2；Flutter依赖解析还自动在analysis_options新增`build/**`排除项。候选锁强制校验成功、Drift/JIT生成成功、31项Flutter测试全部通过（含5项真实Drift/SQLite测试）；静态分析有6条info、退出1，严格门禁未通过。调试资源包构建因Android SDK缺失失败，没有生成kernel或APK。候选结果不能当成原M0通过。

Node SQLite设计原型已实际运行，9/9通过；它验证schema.sql设计，不代表Drift或Android数据库验证。

## 环境与复现

- SDK 安装目标：`D:\Codex\PocketFlowTools\3.47.7\flutter`。
- 固定 Flutter 3.47.7、Dart 3.13.5、revision `abaf9c523780a608bd46686fd5e53740a07077f8`。
- 官方 Windows SDK SHA256：`c2c875da25a1a1448d18ee4e8f398b2f6fce888b4775d8f9130538e16d826cb4`。
- 下载来源：[官方发布清单](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json)；安装依据：[Flutter 手动安装](https://docs.flutter.dev/install/manual)。
- 下载包1,934,624,561字节（1.93GB），包内展开文件3,486,675,789字节（3.49GB）；两者合计5.42GB，缓存另计，未删除安装包。
- 工具、Pub/Gradle/临时缓存使用 D 盘；环境脚本仅修改当前 PowerShell 进程。系统代理由本机读取，不提交端口或凭据。
- 当前仅发现 Java 8；未发现 Android SDK/adb。Android SDK、现代 JDK、SDK 许可与设备条件须在下一阶段落实。

在自己的检出目录执行：

```powershell
./tools/diagnose-network.ps1
./tools/bootstrap-flutter.ps1
. ./tools/enter-pocketflow.ps1
./tools/verify.ps1 -ResolveDependencies
```

**Windows需使用全英文独立工作路径。** 当前中文目录已分别复现AOT输出写入失败和LSP分析器崩溃；工具脚本会提前拒绝这类验证路径。不得搬移其他对话的工作树。D的报告/交付分支保留在`.worktrees/D`，候选运行证据来自上述英文诊断克隆。

首次解析在独立检出目录生成候选 pubspec.lock，由主控审阅并纳入公共基线；D 不在自己的 PR 修改根依赖/lock。已有锁文件时强制 `--enforce-lockfile`。验证脚本记录 SDK revision、实际命令输出、锁文件及 SHA256；随后执行 Drift 生成、静态分析、Flutter 测试与 SQL 设计测试。失败即停止并保留日志，不显示成功。

## MVP 测试计划

P0：数据损坏/丢失、安全或无法建立核心闭环；P1：主要功能错误或发布阻碍；P2：有限场景/体验问题；P3：低影响改进。未交付功能列为依赖缺口，不伪报为已复现 Bug。

| ID | 优先级/层级 | 操作与输入 | 必须满足的结果 | 当前阶段 |
| --- | --- | --- | --- | --- |
| ENV-01 | P1/环境 | 连接器和本地 Git 读取 main 与 D 分支 | SHA 一致；无凭据输出 | 已执行 |
| ENV-02 | P1/环境 | 校验 SDK SHA、版本、依赖锁并生成 Drift | 官方 hash 匹配；同一锁可重复解析 | 本轮执行 |
| BUD-01 | P1/单元 | 1500 元预算、600 元支出、10/17；再新增18元 | 15天含今天；60.00→58.80元/天 | 候选配置下通过 |
| BUD-02 | P1/单元 | 月末、12/31、1900/2000/2100与闰年2月 | 日历与剩余天数准确，历史月无日额度 | 候选配置下通过 |
| BUD-03 | P1/单元 | 无预算、0预算、超支1分、余1分 | null/0区分；负余额保留；额度不透支 | 候选配置下通过 |
| BUD-04 | P1/集成 | 编辑金额、删除、跨月移动历史账单 | 首页与两个相关月份快照一致刷新 | 等待 B 与主控装配 |
| MON-01 | P1/单元/表单 | 0.1+0.2、上限、负数/NaN/指数/多小数 | 整数分精确；非法交易拒绝 | 候选单元通过；表单等待 A |
| DB-01 | P0/真实数据库 | 保存预算与账单，关闭连接/进程并重新打开 | 全字段不变；不使用内存库替代持久化 | 候选真实账单文件关闭重开通过；APP重启/Repository预算保存待 B |
| DB-02 | P0/真实数据库 | CRUD、跨月修改、外键与重复ID、并发写入 | 原子快照、稳定排序、失败无部分写入 | 等待 B |
| DB-03 | P0/迁移 | 使用旧版真实 SQLite fixture 升级 | 原账单/分类/预算/审计字段完整保留 | 等待 schema 版本与迁移 |
| DB-04 | P0/恢复 | 故障注入到清表/插入中间，恢复前备份失败 | 原库不变；可找回的恢复点；错误不吞掉 | 等待 B/C |
| STA-01 | P1/单元/集成 | 混合分类/收入/截止日后记录/跨月记录 | 日/分类合计=对应范围总支出；收入不混入 | 等待 C |
| STA-02 | P1/组件 | 空月、改账/删账、未来月、月份切换 | 空态明确、实时刷新、未来实际月报拒绝 | 等待 C/A |
| EXP-01 | P1/单元 | 中文、管道符、反斜杠、换行、长备注 | Markdown明细完整，日期金额准确，不破表 | 等待 C |
| BAK-01 | P0/往返 | encode→decode→恢复→readAll，含收入与归档分类 | 全字段和整数分相等，所有月份保留 | 等待 B/C |
| BAK-02 | P0/错误矩阵 | 未知版本、重复ID/月、缺字段、孤立分类、非法类型/日期 | 明确拒绝；原库不变；取消不写入 | 等待 B/C |
| BAK-03 | P1/集成 | 连续两次导入同一备份 | 全量替换确认；不重复追加；恢复点可用 | 等待 B/C/A |
| UI-01 | P2/组件/设备 | 320×568、412×915、字体100%/200%与浅/深主题 | 不溢出/裁切；可操作；足够对比 | 当前静态浅色空态4场景通过；深色主题/设备待交付 |
| UI-02 | P1/组件/集成 | 保存中连点、失败重试、返回和页面切换 | 单次账单；失败保留输入；返回语义正确 | 等待 A/B |
| UI-03 | P2/组件 | 加载/异常/空态/1万条虚构账单与500字符备注 | 状态准确、列表懒加载、无明显卡顿 | 等待 A/B/C |
| DAY-01 | P1/集成 | 午夜跨日/跨年与后台恢复，当前/历史月分别查看 | 当前月更新，历史月份选择不强制跳转 | 等待 B/A/主控 |
| AND-01 | P1/构建/设备 | debug编译、安装、离线启动并完成核心闭环 | APK真实存在且SHA记录；账单重启保留 | 本轮不作为首要目标 |
| SEC-01 | P1/审查 | 权限、日志、依赖与导出路径 | 无自动上传、密钥/账单泄漏；依赖许可证可追溯 | 依交付逐步审查 |

## 自动化执行记录

| 检查 | 实际命令 | 结果 |
| --- | --- | --- |
| Git版本 | `git --version` | 2.53.0.windows.3 |
| 私有仓库访问 | `git -c http.proxy=<现有系统代理> ls-remote ...` | main与D均为基线 SHA |
| Node版本 | `node --version` | v24.19.0 |
| SQL设计原型 | `node --test tools/schema.test.mjs` | 9通过、0失败 |
| PowerShell语法 | Parser.ParseFile（bootstrap/enter/verify） | 0解析错误；不等同运行通过 |
| SDK安装/版本 | `./tools/bootstrap-flutter.ps1`、`dart --version` | 官方SHA匹配；Flutter3.47.7/Dart3.13.5 |
| 工具与网络环境 | `flutter --suppress-analytics doctor -v` | Flutter/网络通过；Android SDK缺失；无Android设备 |
| 原M0依赖解析 | `./tools/verify.ps1 -ResolveDependencies` | 失败：build_runner与drift_dev的build约束冲突 |
| 候选锁解析 | 英文克隆`flutter pub get --enforce-lockfile` | 通过；锁SHA256见下文 |
| 候选Drift生成 | `dart run build_runner build --force-jit` | 成功；47个生成输出 |
| 候选静态分析 | `flutter analyze --no-pub` | 0 error/0 warning/6 info，退出1，严格门禁失败 |
| 候选Flutter测试 | `flutter test --no-pub --reporter expanded` | 31通过/0失败；包括5项真实数据库测试 |
| 候选调试资源包 | `flutter build bundle --debug --no-pub --target-platform android-arm64` | 失败：Android SDK缺失；kernel文件不存在 |
| Android APK/安装/启动 | 未执行 | 缺工具与平台工程；未提供APK |

候选锁SHA256：`cbffdad20062a90a8987d6db776e9d8581a43394b8dd7f865f54b669c193f616`。100项解析依赖是候选图，不是已批准生产依赖。

可共享证据包：`tools/qa-evidence/m0/`，包含真实候选锁文件（非项目活动锁）、候选配置diff、具体命令日志、源码SHA256清单（`validated-source-inputs.json`）和原M0解析失败日志，可直接随PR读取。完整本地证据另保存在`.local/qa/candidate-20261017-114521/`。英文克隆的验证脚本在静态分析退出1时按预期停止，Flutter测试随后独立执行；不得称整套验证脚本通过。

## 审查发现与协作事项

1. **ENV-01 / P1 / 已定位并绕过**：本地命令行网络没有使用现有Windows代理；直接Git访问公开仓库也超时。复现：无代理运行 `git ls-remote https://github.com/flutter/flutter.git refs/heads/stable`；使用进程级代理后成功。建议复用环境脚本，不改全局Git、不关闭TLS验证。
2. **BUILD-01 / P1 / 待主控**：基线无真实 `pubspec.lock`，暂不能保证传递依赖可复现。首次生成候选锁，主控审查后纳入公共基线，CI强制校验锁。定位：根pubspec与架构M1。
3. **BUILD-02 / P1 / 交付缺口**：原main尚不能生成Drift，Android工程缺失，原CI只有ownership/SQL原型检查。本轮D补充正式Flutter CI；它要求先有主控审阅的锁。候选Drift与测试结果不能替代原main的门禁，也不能代表Android通过。
4. **SCOPE-01 / P2 / 待主控协调**：用户明确要求 `docs/qa-report.md`，现有 `tools/check_ownership.mjs` 的D白名单只允许 `docs/module-notes/D.md`。本报告按用户当前精确要求纳入D的草稿PR；首次远程ownership检查已确认仅此路径被拒，主控协调白名单后再合并。D不擅改ownership。
5. **LICENSE-01 / P2 / 待发布前完成**：项目许可证尚未确定；第三方传递依赖清单须以真实锁文件为准核验。未发现引用项目代码复制的证据，不据此声称许可证全面合规。
6. **DEP-01 / P1 / 已复现，阻断编译测试**：`pubspec.yaml`的`build_runner: 2.17.1`与`drift_dev: 2.35.1`无可满足版本组合。复现：官方Flutter3.47.7运行`flutter pub get`。日志：`tools/qa-evidence/m0/original-pub-get.log`。官方包元数据同样确认前者build约束`>=5.0.0 <5.1.0`，后者`>=3.0.0 <5.0.0`。建议由主控将build_runner精确固定到2.16.2（build约束`^4.0.9`），评估候选实跑结果后合入真实锁文件。D仅在独立诊断副本验证，不更改共享根依赖。
7. **PATH-01 / P1 / 已复现环境限制**：同一`void main() {}`经Dart3.13.5编译AOT，中文输出路径退出254，ASCII输出路径退出0；中文目录`flutter analyze`发生LSP JSON截断、退出255，英文克隆能完成分析。使用全英文独立构建检出；脚本提前检查路径。JIT仅是代码生成模式，不能解决未来release AOT的中文路径问题。
8. **ANALYZE-01 / P2（阻断严格门禁）/ B处理**：`lib/core/database/app_database.dart:10`的use_super_parameters和`tables.dart:16,17,30,31,32`的recursive_getters共6条info。不是已复现栈溢出：生成表的5项真实数据库测试通过。建议B按Drift DSL核对，在确认生成行为后局部处理误报，并使用super参数；不全局关闭lint或吞掉分析失败。

首次远程CI已实际执行（PR #2，head `a5f0bee1852a99bc604f8eaac038f24d4311f9fc`）：[ownership检查](https://github.com/yuminhang666-oss/PocketFlow/actions/runs/39000625775)失败，日志确认唯一拒绝项为`docs/qa-report.md`，SQL步骤被跳过；[Flutter门禁](https://github.com/yuminhang666-oss/PocketFlow/actions/runs/39000625772)因根`pubspec.lock`缺失而失败，SDK安装、生成、分析和测试步骤都未运行。两项均未通过；远程结果与本地候选测试必须区分。

所有执行结果以具体输入和日志为准；模块未实现、测试未执行、设备未具备的项目不得标“通过”。

## 发布检查清单

- [ ] 主控合并固定共享合同与真实依赖锁；独立目录可从零复现。
- [ ] 固定SDK revision与官方SHA核验，静态分析无错误，Flutter/真实数据库测试通过。
- [ ] A/B/C实际实现经PR审查并由主控接线；演示替身不进入生产默认路径。
- [ ] 预算边界、持久化、迁移、恢复回滚、统计守恒与导出完整性通过。
- [ ] 浅/深主题、窄屏、大字体、输入错误与重复点击通过。
- [ ] Android SDK/JDK/Gradle/最低API版本记录；SDK许可已由有权者接受。
- [ ] debug APK实际构建，记录SHA256、设备/API、安装与离线闭环结果。
- [ ] 许可证与依赖安全检查完成，生产日志脱敏，权限最小化。
- [ ] release签名策略与发布渠道单独获批；无密钥或真实账单上传。
- [ ] 无未处理P0/P1；必要限制和恢复方式已记录，主控决定发布。
