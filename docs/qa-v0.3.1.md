# 0.3.1 验证记录

基线：main cce2a22bf07da031c58e07e08a762498f68e1c91；版本0.3.1+6；合同3.1.0候选；schema4 / JSON3 / recovery3。Flutter 3.47.7、Dart 3.13.5，使用既有锁定依赖与工具，无新增依赖。

实际执行：

- dart run tools/generate_localizations.dart：本地资源生成并与ARB键/占位符核对。
- dart run build_runner build --force-jit：真实Drift生成通过。
- flutter analyze --no-pub：0问题。
- flutter test --no-pub --reporter expanded：完整168项通过。
- node --test tools/schema.test.mjs tools/coordination.test.mjs server/feedback/server.test.mjs：20项通过。server为保留的历史备选，生产仍为系统邮件反馈。
- 三主题真实组件的首页、记账、预算、统计共12张预览：独立1项渲染通过，不与客户端168重复统计。夹具为虚构预算1600元/食堂24.80元，临时Windows字体只用于预览。

阶段检查：主题/首页/分类17项、预算/统计及旧流程51项、三主题三语言大字体9项通过，均与最终168存在重叠，不累计为额外测试数量。

最终Android Release、签名/三ABI/16KiB及实际覆盖安装证据在本次交付报告和Release清单中列明。安装器被打开不能视为安装成功。真实手机/OEM、完整TalkBack和性能仍需设备复核；不以Windows组件渲染替代真机结果。

本次改造只优化呈现与平台更新能力，未改变财务算法、币种、金额整数分、用户原文、数据库路径或备份格式。旧版本首次获取新更新器受旧代码和网络限制。没有承诺150–160MB内存上限。
