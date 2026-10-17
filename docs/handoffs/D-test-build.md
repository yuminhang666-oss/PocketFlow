# 对话 D · 测试、代码审查与 Android 构建

仓库：https://github.com/yuminhang666-oss/PocketFlow.git
基准：远程main M0；预留分支：chore/d-test-build；合同v1.0.0。

先读AGENTS、architecture/data-contracts/interfaces/ownership/milestones/status，使用独立检出目录。你拥有test、integration_test、android、.github/workflows、验证tools（排除主控check_ownership.mjs）。根依赖/lock/analysis_options由主控统一修改；不要改业务实现冒充审查修复，跨模块缺陷提交证据给主控或对应模块。

先验证环境：当前主控未发现Flutter/Dart/Android SDK，有Java8路径，不能认为现代Android工具链就绪。已有Node24 SQLite原型9项测试通过；Dart测试/Drift代码生成/analyze/Android运行/APK均未执行。工具安装、SDK许可、全局设置变动不在普通测试授权中，提出D盘本地最小配置范围后等待用户授权；已存在工具可直接使用。

M1任务：确定与pubspec匹配的官方Flutter/Dart/JDK/Android组合；在空临时目录生成Android工程，只提交允许的平台文件，不覆盖本项目源码/配置。需要的锁文件/依赖版本交主控整合。构建密钥与账单绝不提交。

并行设计合同/预算/Drift CRUD与迁移/报表合计/Markdown转义/JSON版本及回滚/Widget状态测试。现有测试源码需实际执行才能报告通过；不能用Node重写Dart算法并声称已测试Dart实现。schema.sql是设计原型，需将Drift真实生成schema与其约束核对。

模块PR交付后审查真实差异并复现检查；M5提供可安装APK、SHA256、设备/API、离线闭环验证和已知限制。release签名及公开发布单独确认。使用PR→main，docs/module-notes/D.md保存真实证据，不自行合并。
