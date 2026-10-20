# 0.3.1 主控交接

2026-10-20。最新用户授权：完成普通浅色、深色、独立毛玻璃浅色的 UI 优化，与三秒撤销、应用内更新及简/繁/英一起作为 0.3.1 发布。实际平台是 Android，只参考 iOS 的视觉品质，保留 Android 返回、Material 3 弹层、系统权限与安装行为。用户取消内存优化。apple-design Skill 缺失，用户已同意按官方 HIG / Material 3 审查，实施采用已存在的 frontend-design 技能，不安装依赖或插件。

基线 main cce2a22bf07da031c58e07e08a762498f68e1c91，已核对远程；独立 source 为 D:/Codex/记账/updates/v0.3.1/source，分支 integration/v031-control-bugfixes。英文路径构建副本 D:/Codex/PocketFlow-v031-20261020。资源已重新生成并同步，之前资源映射不同步、英文网格溢出及额度阻碍均已解决。旧根目录及其他对话工作树未切换/reset/stash。

实现与合同：PersonalProfile 的可选 surfaceStyle/locale 及 savePreferences 参数；标准 Flutter 本地化 Delegate 和本地 ARB/生成常量；用户自定义文字不翻译。classic/glass 独立于 system/light/dark，glass 固定浅色。schema4/JSON3/recovery3、原包名/测试签名/DB路径、财务算法均不变。更新新增可选 AppPackageUpdatePort，主动原生流式下载、进度、取消，验证摘要/大小/真实APK包名版本与安装证书，再打开系统安装器；GitHub API失败时仅使用同仓库官方latest清单备用。

UI 已分阶段实现：统一排版、圆角、三种表面及浮动导航；首页精简卡片尾部、次级快捷入口；分类自适应和明确选中、键盘层级；预算摘要和分类进度；统计分析分组、图表表面及提示语言。导航160ms轻过渡尊重 disableAnimations；高对比度关闭玻璃模糊。未增加业务逻辑、存储或依赖。

本次最终代码生成通过、静态检查0问题、Flutter完整168项通过；Node SQL/协作/历史反馈服务20项通过。第一阶段17项、预算/统计阶段51项和新增三主题/三语言大字体9项另有阶段日志，不与完整168重复累加。12张真实Flutter组件预览由一个独立渲染测试生成，不计入168；虚构1600预算/24.80食堂消费，渲染测试临时加载Windows字体，不打包进App。

Android API36隔离只读模拟器已正常启动，真实线上0.3.0 APK摘要已验证并安装，已通过旧UI建立1600预算/24.80食堂虚构记录。升级前83分类、1预算、1记录已拉取成SQLite/JSON基准，后续应核对新版覆盖、firstInstallTime、所有表与外键/完整性，再测试语言/主题、三秒提示和更新界面。不得把组件截图或编译当完整原生下载安装成功。最终Release构建和包检查当前正在进行；最终摘要/设备结果/PR与CI/发布状态以交付QA和线上Release为准，不用旧预览APK替代。

发布授权已覆盖提交/推送、PR审查集成、tag和Release。必须走PR，不能直推main/force push。发布资产沿用v1/v2清单及同字节debug文件名兼容；只上传已审阅源码/APK/清单/校验和，不上传账本、签名密钥或本地工具缓存。Git网络使用进程级现有代理即可；认证由既有Git凭据助手取得，不打印令牌。发布后再核对公共latest元数据/摘要和已安装新版行为。

未验证或需明确限制：用户真机/OEM、完整TalkBack语音手势、帧率与内存；旧0.2.1无法远程获得新更新器，首次升级受旧能力和网络限制。不得承诺150–160MB内存上限或完全无法访问GitHub时仍能下载。当前UI审查和预览在deliverables/ui-review及deliverables/v0.3.1/preview，最终证据在验证副本.local/final-*.log和交付evidence。
