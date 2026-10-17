# PocketFlow · 大学生生活费管理

把每月生活费变成每天心中有数的额度。目标平台：Android；默认人民币；离线使用、无需账号。

## 统一协作入口（2026-10-17）

私有仓库：[yuminhang666-oss/PocketFlow](https://github.com/yuminhang666-oss/PocketFlow)；基准分支 `main`；共享合同 `v1.0.0`。

主控负责架构、接口和集成；A 负责 UI，B 负责数据库与记账预算，C 负责统计导出备份，D 负责测试与 Android 构建。各对话使用独立目录、独立分支、PR 交付，不直接推送或合并 main。

必读：[架构](docs/architecture.md)、[数据合同](docs/data-contracts.md)、[模块接口](docs/interfaces.md)、[文件范围](docs/ownership.md)、[里程碑](docs/milestones.md)、[项目状态](docs/status.md)、[PR流程](docs/workflow.md)。

交接：[A](docs/handoffs/A-ui.md) / [B](docs/handoffs/B-core.md) / [C](docs/handoffs/C-report-backup.md) / [D](docs/handoffs/D-test-build.md)。先读取远程 M0 基线，不根据另一聊天的片段重新设计模型。

## 工程状态

已完成第一阶段的开源代码调研、架构与数据模型规划、MVP 验收清单，以及 Flutter 源码基础结构。已编写整数金额、日历月份、动态预算的领域代码与测试。Figma 界面用于评审设计，示例金额不是用户真实账单。

**当前还不是可安装的应用。** 此机器没有发现 Flutter / Dart / Android SDK，Android 平台工程尚未生成，依赖尚未解析，Dart / Flutter 测试尚未执行，尚未生成 APK。当前首页仅为未设置预算的空态界面，没有接入数据库或开放记账操作。

## 阅读入口

- [开源调研与取舍](docs/01-research.md)
- [架构、数据库与计算规则](docs/02-architecture.md)
- [开发任务与验收标准](docs/03-mvp-plan.md)
- [界面与交互规范](docs/04-design.md)
- [环境检查与下一步](docs/05-environment.md)
- [验证记录](docs/06-validation.md)

Figma：[PocketFlow 设计文件](https://www.figma.com/design/1aJ6wUjoLXAA649lqVyhYr)（最近检查画布为空，未交付四页设计）。

## 项目目录

```text
lib/
  main.dart                     # 入口
  app/                          # Material 3 主题与首页空态
  core/domain/                  # 金额、月份、消费记录；不依赖 Flutter
  core/database/                # Drift 数据库与 SQL 模型
  features/budget/domain/        # 每日可支配预算计算
  features/transactions/domain/  # 数据仓库接口
test/                           # Dart 金额与预算边界测试（待执行）
tools/                          # SQLite 设计验证
design/                         # Figma 构建源码、节点记录与设计规范
docs/                           # 调研、计划与验收证据
```

## 开发工具就绪后

先按 `docs/05-environment.md` 在临时空目录生成 Android 工程，再把生成的平台目录合入项目，保留本项目源码与文档。之后在本目录运行：

```powershell
flutter pub get
dart run build_runner build
flutter analyze
flutter test
flutter run
```

依赖版本在 pubspec.yaml 中按 2026-10-17 的 pub.dev 元数据固定，实际兼容性需要完成依赖解析后确认；不手写 pubspec.lock 或 Drift 生成文件。

## 工程与隐私边界

没有复制四个参考应用的业务代码、图标或品牌资源。本阶段只参考设计与架构思路。项目发布许可证待决定。不要将个人账单、备份、签名密钥或本机路径配置提交到仓库。未来导出只调用用户主动选择的系统分享；Markdown 用于阅读分析，JSON 用于完整恢复。

GitHub 仓库由用户提供，主控发布 M0 合同基线和模块分支；实际提交及运行验证见项目状态，不以本 README 代替验收证据。
