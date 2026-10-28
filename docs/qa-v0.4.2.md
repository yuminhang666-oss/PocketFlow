# PocketFlow 0.4.2 验证记录

日期：2026-10-28；以下为发布前验证记录，后续发布状态以GitHub Release为准。基线：远程main `dd71ccbe00bb9377a02658ee8114d7bdcb86ccc4`，分支 `integration/v0.4.2-experience`，版本 `0.4.2+13`。

## 环境与命令

复用已有Flutter3.47.7（revision `abaf9c523780a608bd46686fd5e53740a07077f8`）、Dart3.13.5、JDK17、Android API36与原签名。锁定依赖通过 `flutter pub get --offline --enforce-lockfile` 解析；没有安装新工具或依赖、改全局配置。中文路径下Dart/Android工具有限制，实际生成、检查和构建使用D盘英文路径副本。

| 检查 | 实际结果 |
| --- | --- |
| `dart run build_runner build --force-jit` | 成功生成；共享模型、数据合同与数据库实现未改 |
| `dart run tools/generate_localizations.dart` | 三语资源生成成功，键与参数一致性检查通过 |
| `flutter analyze --no-pub` | 最终代码0问题 |
| `flutter test --no-pub --reporter expanded` | **297项全部通过** |
| `node --test tools/schema.test.mjs server/feedback/server.test.mjs` | **17项全部通过**；历史服务只测试，不装配或部署 |
| `flutter test --no-pub tools/v042_performance_test.dart` | 单独的1项基准通过，不计入297项 |
| `flutter build apk --release --no-pub` | 成功；使用原升级签名 |
| `aapt dump badging` / `apksigner verify --verbose --print-certs` | 包名cn.pocketflow、版本0.4.2、versionCode13，签名验证通过并与0.4.1相同 |

源码与英文路径构建输入逐文件摘要核对记录在交付包 `source-build-sha256.json`；安装包大小/摘要见 `apk-validation.json`。初轮完整回归出现普通屏幕快捷分类越过键盘边界3px，收紧留白后修正；模拟器安全区进一步暴露日期与备注换行挤压分类，精简日期可见文字、保留完整语义并新增回归后，最终297项通过。初轮失败记录保留，不冒充最终通过记录。

## 关键覆盖

- 历史周/月重复点击不重置期间、类型切换保留锚点、超出周报范围回本周、选月取消。
- 当前月1日、历史月、闰年2月的日期上下界；未来月份禁用日期筛选。
- 保存失败保留金额/备注/类别/日期，重试一次只写一笔，忙碌时两个保存入口都不可重复提交，连续保存与撤销冲突。
- 普通新增/历史查询/日历补记/模板与日期独立；预算四态、零支出、目标独立、周期确认、备份恢复和邮件交接沿用原回归。
- 新增细分类溢出按钮能到末项，全部能放下时隐藏；日期、备注及快捷分类在360×640dp且有Android安全区时可达。
- 新增三主题×三语言的320×568dp/200%报告与录入回归；原有320/360/390/412dp和字体/页面测试继续运行。该自动化覆盖不等于所有实机组合已测。

## Android模拟器证据

仅使用明确的合成账本，不操作真实手机或账单。设备为Android API36 x86_64，标准360×640dp/100%字体。先在SwiftShader模式使用 `emulator-5596`，随后在推荐端口的 `emulator-5582` 重建合成基线；两次均在毛玻璃导航过程中发生模拟器宿主 `qemu-system-x86_64-headless.exe` 访问冲突（0xc0000005，模块unknown），系统事件保存在 `verification/emulator-host-crashes.txt`。后改用同一只读AVD的host GPU模式，日志识别RTX4060，毛玻璃四页与返回补验完成，未再出现该中断。不能据此断言根因为端口、应用或图形驱动，也没有宣称修复所有GPU问题。原AVD不保存本轮改动。

0.4.1+12→0.4.2+13实际覆盖安装成功，firstInstallTime保持；安装前后数据库文件字节相同，12张表逐表摘要一致。保留14笔记录、83个分类、2个月预算、1个周期规则及1个版本和偏好，schema4，integrity_check=ok、foreign_key_check为空。数据证据为 `upgrade-validation.json` 及两份明确命名的合成SQLite文件。

旧版设备已复现周报重复点击跳回本周；新版周报保留2026-10-19—25，合成样例支出851.90元、收入600.00元、净收支−251.90元；月报切到9月后再次点击保持9月。数值与预期样例一致。

另将隔离模拟器时钟设为2026-11-01中午：旧版在Etc/GMT+5（UTC−05）点击日期无响应；新版在同一环境及Asia/Shanghai（UTC+08）均打开“筛选当前月份日期”。设备时区、实际时间和截图见 `date-timezone-validation.json`。测试后恢复日期与时区；该受控时钟不代表发布日。

截图与设备语义树按页面放在交付目录 `screenshots/`；浅/深/玻璃分别检查首页、录入、账单和历史报告，筛选摘要另有截图。截图均为合成测试数据。不同设备的字体、GPU、系统栏与首屏范围仍需实际手机确认。

在host GPU模式启用已安装的TalkBack16.0.0.738667889，系统记录服务已绑定、touch exploration已启用；截图可见焦点。使用ADB注入触摸打开录入、输入与保存，一次新增后合成记录14→15，原14笔逐字段保持。该检查是读屏启用环境的冒烟检查，没有监听TTS实际发声，也未完整验证读屏手势、编辑、失败及弹窗焦点返回；不能称为完整TalkBack验收。记录见 `talkback-smoke.json`、`verification/talkback-*-services.txt` 及对应截图。服务随后在隔离模拟器恢复关闭。

## 性能测量与限制

Windows Flutter test VM、内存SQLite；每组1000或10000笔当月记录、100条周期规则，预热1次、正式9次。下表为本轮主机结果，不能写成手机输入延迟或性能提升。

| 数据量 | 操作 | 中位数/ms | 9次样本最近秩p95/ms | 每次SELECT数 | SELECT返回行数 |
| --- | --- | ---: | ---: | ---: | ---: |
| 1000 | 月快照 | 8.63 | 12.51 | 6 | 1286 |
| 1000 | 分类保存 | 6.87 | 7.44 | 6 | 1286 |
| 10000 | 月快照 | 56.27 | 65.06 | 6 | 10286 |
| 10000 | 分类保存 | 61.58 | 66.84 | 6 | 10286 |

数据见 `performance.json`，包含全部样本。结果表明此路径的返回行数随账本增长；本版未删校验、改事务或承诺提速。后续应在物理手机测量后另行决定数据库优化。

## 未完成的设备验收

物理手机/OEM、真实GPU下毛玻璃细线与性能、完整TalkBack听读和焦点返回流程仍待验收。界面语义树和控件测试不能替代真实听读；未将未测项标为已修复或已通过。以上为本地候选阶段记录；后续用户授权的源码上传复核见 [上传记录](source-upload-v0.4.2.md)，应用内更新仍未上线。
