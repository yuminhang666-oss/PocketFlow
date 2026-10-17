# D：质量与工具链交付

2026-10-17，合同 v1.0.0，基线 `26d8e4b47eef5d17fe2ca8385da3ddb58adce95e`。

本轮优先网络排查、Flutter/Dart安装与可复现分析/测试环境。独立检出 `chore/d-test-build`，保留其他对话工作树。

已实际确认：连接器可读取私有仓库；Git使用Windows现有代理后可读取main与D分支。正常执行环境已有凭据可用，沙箱另有MSYS凭据助手失败。未读取/复制令牌，未改全局Git。Node24.19.0运行SQL设计原型9/9通过，这不等于Drift验证。

`tools/flutter-toolchain.json`固定官方Flutter3.47.7、Dart3.13.5、revision与WindowsSHA256。`bootstrap-flutter.ps1`核验官方manifest和包；`enter-pocketflow.ps1`仅配置当前进程、D盘缓存、现有代理；`verify.ps1`保留版本、锁、生成/分析/测试日志，失败即停止。使用方法见脚本参数。首次依赖解析生成候选锁交主控审阅，D不提交根依赖/lock。

补充：共享日历/金额边界、不可变快照、MVP新增18元→58.80元/天、日额度保守分配、静态首页窄屏/大字体与真实生成Drift数据库约束/事务/文件重开测试。

MVP回归顺序：环境→共享合同/预算→B真实数据库CRUD/重启/事务/迁移→A正式接线与重复提交→C统计守恒/Markdown/JSON与恢复回滚→Android安装离线验收。未交付功能保持待验证，不以SQL原型或静态首页替代。

Flutter3.47.7与Dart3.13.5已安装、官方SHA256匹配，版本命令与doctor实际成功；SDK展开约3.49GB，保留下载包后约5.42GB，缓存另计。doctor网络资源可达，Android SDK缺失。新增Windows Flutter CI门禁：主控须先合入锁，否则明确失败；不把无锁解析称作可复现验证。远程CI尚未运行。

**DEP-01 / P1：主分支不能解析依赖。** `build_runner2.17.1`要求build5.x，与`drift_dev2.35.1`要求build<5冲突。官方SDK实际`flutter pub get`失败，日志在`.local/qa/20261017-114002/pub-get.log`。官方包API核实2.16.2要求build^4.0.9，候选成功解析；公共pubspec未修改。

候选实跑位置`D:\Codex\PocketFlowTools\probes\m0-candidate`，基于同一M0、D新增测试，仅改build_runner2.16.2；Flutter解析自动追加analysis_options的build/**排除项。候选锁强制校验通过，SHA256 `cbffdad20062a90a8987d6db776e9d8581a43394b8dd7f865f54b669c193f616`；Drift/JIT生成47个输出；Flutter测试31/31通过，含5项真实Drift/SQLite测试。静态分析0error/0warning/6info、退出1，完整verify门禁仍失败，测试是随后独立运行。6条info在B的app_database.dart:10和tables.dart:16/17/30/31/32，需B确认处理。调试资源包编译因AndroidSDK缺失失败，未生成kernel或APK，未安装/启动Android。

**PATH-01 / P1环境限制**：最小空程序在中文输出路径AOT退出254，英文路径退出0；中文分析器LSP崩溃255，英文分析正常完成。请用全英文独立克隆，verify脚本会预检拒绝非ASCII Windows工作路径。JIT是生成器的官方模式，不能解决未来release AOT路径问题。

共享证据`tools/qa-evidence/m0/`保存生成的候选锁、配置diff、实跑命令日志和源码SHA；该锁仅供主控审阅，任何脚本/CI都不将其作为活动锁。完整本地证据另存`.local/qa/candidate-20261017-114521/`；不包含真实账单。完整MVP用例、缺陷与发布检查清单在用户指定`docs/qa-report.md`。该单文件按当前用户精确要求纳入草稿PR，当前ownership白名单将拒绝此路径，主控协调后再合并，不擅改白名单。

主控事项：修正上述依赖冲突并合入真实锁；审核正式Flutter CI；Android现代JDK/SDK/许可；协调用户要求的`docs/qa-report.md`路径（当前D白名单仅允许本说明）；发布前确定许可证。D不修改共享模型、根依赖、其他模块实现、ownership脚本，不合并main。
