# 实际验证证据

2026-10-17，隔离集成目录 `D:\Codex\PocketFlowIntegration`。

| 文件 | 命令与结果 |
| --- | --- |
| analyze.log | flutter analyze --no-pub：0 问题 |
| flutter-test.log | flutter test --no-pub --reporter expanded：38/38，无跳过 |
| sql-design.log | node --test tools/schema.test.mjs：9/9，设计原型单独计数 |
| flutter-doctor.log | flutter doctor -v：Android 工具链通过，无连接 Android 设备 |
| apk-build.log | flutter build apk --debug --no-pub：成功 |
| apk-badging.log | aapt dump badging：应用、SDK、ABI 与启动 Activity 元数据 |
| apk-signature.log | apksigner verify --verbose --print-certs：调试签名验证通过 |

日志按原输出转成 UTF-8 并移除控制台行尾填充空格；原日志保留在 .local/qa/integration/。文件端口自动测试使用受控替身；安装、启动及系统文件界面没有设备证据。版本、原始模块提交与限制见 `docs/integration-report.md`，最终 APK 哈希及实际路径见 `docs/apk-delivery.md`。pubspec.lock 是本轮真实解析结果，Drift 生成文件不入库，运行前需生成。
