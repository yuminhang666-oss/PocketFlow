# 0.1.1实际验证证据

2026-10-17，Android API36 Google APIs x86_64 / 官方Emulator37.2.12，实际APK安装与界面操作。所有记录和截图均来自自建模拟器与虚构数据；不含用户手机账单。

- analyze.log / flutter-test.log：静态分析0问题；39项Flutter测试通过。
- apk-build.log / apk-validation.json：实际Debug构建；相同签名、版本2及每ABI原生插件/库检查。
- old-native-error.log / old-startup.png：原发布0.1.0在Android的动态库缺失及持续加载复现。
- upgrade-package-record.log：adb install -r成功，版本1→2，firstInstallTime保持不变。
- device-verification.json：对照实际设备SQLite、系统保存的Markdown/JSON、恢复快照及界面XML核验；数据库二进制不入库。
- upgraded-home.png：旧数据目录中的虚构预算和账单在升级后保留。
- budget-1105-saved.png / working-statistics.png：实际保存预算及显示统计。
- fresh-ledger-reopened-corrected.png：另从空账本建库、保存、强制停止并重开，仍保留1500/30/1470。

实际交付构建命令为tools/build-test-apk.ps1；Android执行adb install -r、am start/force-stop、uiautomator dump及系统文件选择器操作。覆盖保留使用预置夹具，首启/保存另外从空数据库验证；说明见docs/hotfix-0.1.1.md。