# PocketFlow 项目协作规则

## 唯一权威基线

- 仓库：https://github.com/yuminhang666-oss/PocketFlow（公开）；默认基线：`main`。
- 开始/续接时从远程读取本文件及 docs/architecture.md、data-contracts.md、interfaces.md、ownership.md、milestones.md、status.md 和自己的 docs/handoffs/ 交接文件。
- 不假定对话间共享上下文或本地文件。未合并 PR 不构成公共接口事实。
- 每个对话用独立 clone/worktree；禁止在其他对话正在使用的目录切换分支、reset、stash 或覆盖文件。

## 角色与变更

- 主控：共享模型、contracts、入口装配、依赖/根配置、架构决策、审查集成。
- A：UI/UX、页面、主题、公共 UI 组件、design/。
- B：数据库、预算算法、记账业务/仓库实现。
- C：统计、Markdown、JSON、文件适配。
- D：测试、构建、Android 平台、CI。
- 精确路径以 docs/ownership.md 为准；跨范围改动先提接口/依赖申请，不能顺手改动。
- 所有 A–D 工作必须在独立分支经 PR 交付，不得直接提交/推送 main，不得自行合并。
- 主控初始化空仓库可建立首次 main 基线；后续主控集成也使用 PR。不执行 force push。

## 真实性与验证

- 金额始终整数分；共享数据结构唯一来源为 lib/core/domain/ 与 lib/contracts/。
- 不伪造测试、APK、截图或数据；占位/演示与生产实现明确区分。
- Flutter/Android 工具缺失时报告阻碍，不能用源码存在代替可运行验收。
- 保留已有改动，未经授权不安装依赖、不改全局设置、不公开仓库、不上传真实账单或密钥。
- 测试应验证边界和数据一致性；记录运行命令、工具版本与结果。
- PR 须说明基线提交、合同版本、文件范围、实际验证、限制及影响模块。
