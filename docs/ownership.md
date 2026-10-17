# 文件所有权与分支

所有分支以远程 `main` 为起点。分支已由主控预留时检出该远程分支，不另起同名但来源不同的分支。每个对话用独立 clone；同一电脑建议使用 `.worktrees/A`、`.worktrees/B` 等独立目录，不共享正在使用的工作树。

| 角色 | 分支 | 允许主要修改 |
| --- | --- | --- |
| A | feat/a-ui-mvp | lib/app/（排除 composition/）、lib/shared/widgets/、lib/features/home/presentation/、entry_editor/presentation/、ledger_list/presentation/、settings/presentation/；design/；docs/module-notes/A.md；docs/ui-ux-proposal-v1.md |
| B | feat/b-ledger-budget | lib/core/database/；lib/features/budget/domain/、application/；lib/features/transactions/；docs/module-notes/B.md |
| C | feat/c-report-backup | lib/features/statistics/、export/、backup/；docs/module-notes/C.md |
| D | chore/d-test-build | test/、integration_test/、android/、.github/workflows/；tools/（排除 check_ownership.mjs）；docs/module-notes/D.md；docs/qa-report.md |
| 主控 | integration/<milestone>、contract/<change> | lib/core/domain/、lib/contracts/、lib/main.dart、lib/app/composition/；根配置/依赖；AGENTS.md、CODEOWNERS、架构/合同/计划/决策；tools/check_ownership.mjs；跨模块集成 |

A/B/C 不直接改 test/；在模块交付说明列测试场景，D 按公共合同补测试。模块可运行现有测试，不受所有权限制。若一个缺陷必须修改别的模块，提交主控处理或拆成另一模块的 PR；不要把所有权当作不报告缺陷的理由。

`pubspec.yaml`、`pubspec.lock`、`analysis_options.yaml`、共享模型/接口由主控统一修改。新增依赖请求需列用途、版本、官方来源、Android最低要求与许可证；主控确认后先开公共依赖 PR。不要各模块反复解析不同依赖并提交互相冲突的 lock。

现有 `lib/features/transactions/domain/ledger_repository.dart` 仅为兼容 export，唯一接口在 `lib/contracts/ledger_repository.dart`；B 不另定义同名接口。BudgetSnapshot 已移至 core/domain，B 只实现算法。旧数字编号文档是前期调研背景，架构规范以无编号的本套文档为准。

## 独立工作目录

从统一仓库建立自己的 clone，再检出预留分支。若用 worktree，必须协调共享 Git 元数据，不能两个工作树检出同一分支。工具缺乏 Git 凭据时可通过已有 GitHub 连接操作自己的分支；不要要求用户在聊天粘贴令牌。

当前本地根目录已出现 `codex/core-data-design` 工作分支；主控保留该工作树，不将其强行切换成 main。远程基线和模块分支一经建立，各对话应在独立目录从该基线继续，不能把当前未提交文件当成分支已交付。

## 检查与执行力度

PR 的 ownership 检查按分支前缀校验变更路径；CODEOWNERS 标记主控负责审查。它们是协作保护，不是账号级隔离：四个对话若使用同一 GitHub 身份，不能提供彼此独立的身份审批。仓库分支保护/Ruleset 尚未配置，不能声称系统已禁止直接 push；当前禁止直推是一项明确协作规则。后续如增加独立协作者，再配置不可自审的 GitHub 审批规则。
