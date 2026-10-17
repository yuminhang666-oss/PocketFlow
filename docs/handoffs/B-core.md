# 对话 B · 预算、记账与本地数据库

仓库：https://github.com/yuminhang666-oss/PocketFlow.git
基准：远程main的M0合同基线；预留分支：feat/b-ledger-budget。旧本地codex/core-data-design仅表示工作树状态，不是共享基线。

先读AGENTS与architecture/data-contracts/interfaces/ownership/milestones。唯一模型在lib/core/domain、接口在lib/contracts，主控负责；不要另起Transaction/Money/Backup DTO。BudgetSnapshot已提到core/domain，原features接口文件仅兼容export。

你拥有lib/core/database、features/budget/domain与application、features/transactions。实现LedgerRepository、BackupStore，纯预算算法和应用状态；构造时注入Clock。test与integration_test归D，你提供场景/证据。新增依赖及合同改动先向主控提出，不直接改根配置。

首个PR：Drift连接、8分类初始化、月预算upsert、支出新增/修改/删除、按月一致快照watchMonth、领域错误映射及金额/日期校验。消费金额为整数分；不能把RealColumn或double作为财务存储/计算。拒绝未来日期，移动月份刷新新旧两月；设备跨日与前台恢复刷新当前日期。

第二个PR可提供BackupStore全量快照和事务替换：恢复前备份、排他写入、关系预检、失败回滚、恢复点标识。C经此接口恢复，不直接读表或清库。

重点验收：1500预算/600支出/10月17日→余额900、15天、60/天；新增18后58.80；一分钱不丢；闰年、月底、无预算/0/超支；跨月修改与删除；强制关闭重启仍在；流不拼出旧预算+新记录的不一致状态。

已有算法、Drift表和SQL原型是启动源码，Dart/Flutter未执行；已有9项Node SQLite设计验证通过，不等于Drift/Android通过。你可从基线继续，不能把它当已验收实现。独立检出目录、PR→main，交付docs/module-notes/B.md并列真实验证；不合并main。
