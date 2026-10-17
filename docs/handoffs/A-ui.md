# 对话 A · UI/UX 与 Flutter 页面

仓库：https://github.com/yuminhang666-oss/PocketFlow.git
基准：远程 main 的 M0 合同基线（见 docs/status.md 或主控返回的 SHA）。预留分支：feat/a-ui-mvp。不要从只有 README 的早期提交开始实现。

你负责中文 Material 3 UI、主题、路由、首页、快速记账、明细与设置页面，及 design/。先读 AGENTS.md、architecture、data-contracts、interfaces、ownership、milestones。使用独立检出目录，不切换其他对话当前目录的分支。

共享模型位于 lib/core/domain，接口位于 lib/contracts，合同 v1.0.0。消费记录已有实际 UTC 时间与固定 localDate，UI 可显示时分但不能自行重新分月。首页只展示 BudgetSnapshot；通过 LedgerRepository 保存/读取。正式注入由主控完成，你可用明确隔离的测试替身开发，不直接 import Drift 表或修改数据库/算法/contracts/依赖。

现有设计方向与清单在 docs/ui-ux-proposal-v1.md，是 A 的设计草案，不是工程验收证据。Figma 文件 https://www.figma.com/design/1aJ6wUjoLXAA649lqVyhYr 已创建但最近检查为空；design/build_figma.js 是失败后回滚的草稿：曾遇到组件属性与嵌套帧原型目标限制，不能宣称已执行成功。由你按实际设计需要继续，不必重建第二个APP。

首个PR交付：主题、可注入数据的首页、支出表单、明细与设置入口；支持未设置/零预算/超支/历史月/加载/错误状态。金额和分类触控区至少48dp，360/390/412宽度与大字体适配；保存中防重复、失败保留输入。快速记账默认今天与餐饮，保存成功后再更新额度。统计页面图表本体由C负责，你可提供布局/设计规范，避免重复实现。

你现在可以并行开发 UI 与替身；真实保存/数据库联动等待B和主控接线，设备验证等待D工具链。完成后提交PR到main，记录基线SHA、合同版本、实际截图/检查和未完成项；不合并main、不私自新增依赖。测试场景写 docs/module-notes/A.md，D维护自动测试。
