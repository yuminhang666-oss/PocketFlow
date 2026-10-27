# 0.4.0 设计验收映射

来源：2026-10-26 设计说明正文与验收清单，图片仅作概念参照。自动测试、设备操作和人工辅助功能验收分别记录；下表是用例与证据入口，不声称未执行的手机检查已通过。

| 原清单 | 本轮检查入口 | 验证层级与边界 |
| --- | --- | --- |
| D01–D09 | v040_navigation、v034_navigation、v034_entry、planning_storage、storage_integration | 真实内存 SQLite + 页面交互；月份隔离、补记、模板、连续保存、编辑、撤销；午夜由原 clock/生命周期回归覆盖 |
| N01–N05 | v040_navigation、v034_navigation、prompt_coordination | 既有标签重置、日历/列表、更多直达我的、报告共用与详情返回 |
| E01–E06 | v040_navigation、v034_entry、vnext_modal、vnext_layout、user_flow_widget | 标题、更多模板、覆盖取消/确认、忙碌/失败草稿、连续保存与小屏操作 |
| B01–B05 | budget_calculator、budget_mvp_regression、v040_data、user_flow_widget、v031_ui | 整数分、剩余日含今天、零/超支、分类预算和同步刷新；低于已支出额新增确认面板 |
| G01–G03 | app_foundation、v040_data、vnext_modal；设备首页与目标面板 | 登记不写账、不扣预算、顺序保留、真实超过目标金额；仅设置目标后显示首页目标区，清空后隐藏；管理入口保留在我的 |
| K01–K03 | v040_calendar、v040_navigation、storage_integration | 闰年、31日夹取、回今天、七列布局、显式补记及零支出；筛选不能绕过已有支出 |
| R01–R04 | planning_storage、v040_data、v030_pages | 周期原子确认/幂等、实际日期、跨月归属、跳过/撤回、短月/版本/暂停历史；确认和账单仅一份 |
| R05 | 周期计划源码与设备入口；待处理跨月计数 | 从已有版本生成其他月份逾期项，显式展开并按到期日排序 |
| S01–S04 | v040_navigation、v040_data、review_policy、v030_pages | 周/月期间、截至日、851.90/600/−251.90 与 93.9/3.8/2.3%、历史和空比较；图表支持逐日辅助明细 |
| C01–C05 | v040_data、v033_metric_layout、v034_layout；设备截图 | 单一分类映射、根子继承、颜色持久与备份、收红支绿、净值/零值、真实比例；选择同时有勾选 |
| X01–X02 | v040_calendar、v034_layout、vnext_layout、v030_pages、v032_theme_transition | 320–412dp、最高200%字体、浅/深/毛玻璃、三语言；设备复核实际渲染 |
| X03 | localization 与语义属性检查 | 三语资源和文字不截断；完整 TalkBack 焦点操作仍待真实设备验收 |
| X04 | v040_data、planning_storage、baseline_integrity、storage_integration；覆盖升级证据 | 旧备份和数据库继续读取；颜色/实际日期/账目关联经 JSON 与恢复点往返核对；安装升级另记 |
| X05 | feedback_mail、app_updates、file_transfer_contract、user_flow_widget | 取消、错误、本地草稿/打开邮件与实际送达区分，下载校验与系统安装交接原能力保留 |

静态与自动检查并不替代所有真机步骤。对物理手机、OEM、完整 TalkBack、用户网络下载和系统安装授权，最终交付明确保留限制，不把设计清单的“待测”批量改为“通过”。
