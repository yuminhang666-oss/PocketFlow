# 验证记录

## 已实际执行

2026-10-17：Node 24.19.0，`node --test tools/schema.test.mjs`，9项通过、0失败。覆盖整数分聚合、非法金额/精度/类型/分类拒绝、无预算与0及重复月份、增删改/跨月移动、收入排除、日/分类合计、事务失败回滚、分类外键、文件关闭后重开。

范围：执行的是schema.sql设计原型，**不是Drift生成数据库、Dart业务算法或Android存储的验收**。D须在实际Flutter工具链中核对真实schema与运行结果。

GitHub：私有仓库与push权限已读核验。发布与分支SHA以后续主控返回的真实结果为准。

## 尚未执行

Flutter依赖解析、Drift生成、flutter analyze、Dart/Flutter测试、Widget/设备适配、导出与恢复业务测试、Android构建和APK安装。现有test源码仅表示已编写用例。

Figma构建两次失败后回滚，画布为空；不计作UI完成。设计构建源码有语法检查证据，但不能替代视觉验收。
