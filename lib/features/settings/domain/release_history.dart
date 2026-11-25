/// Offline, user-facing notes. Historical dates come from the actual Releases;
/// an unreleased candidate deliberately has no publication date.
class AppVersionNotes {
  const AppVersionNotes({
    required this.version,
    required this.title,
    this.publishedOn,
    this.additions = const [],
    this.fixes = const [],
    this.notes = const [],
  });

  final String version;
  final String title;
  final String? publishedOn;
  final List<String> additions;
  final List<String> fixes;
  final List<String> notes;
}

const pocketFlowVersionHistory = <AppVersionNotes>[
  AppVersionNotes(
    version: '0.4.2',
    title: '报告期间与记账体验优化',
    fixes: [
      '重复点击周报或月报保留查看期间，切换类型保留日期，较早月报切回周报时回到本周。',
      '明确切换月报与选择月份的操作，修正月初日期筛选的时区边界。',
      '备注入口显示文字，细分类提供滚动按钮，保存失败明确保留输入。',
      '完善筛选与报告的读屏提示，页内跳转遵循系统减少动画设置。',
    ],
    notes: ['沿用原包名与升级签名，旧账本和备份可继续读取。'],
  ),
  AppVersionNotes(
    version: '0.4.1',
    title: '账单布局与设计复查修正',
    fixes: [
      '账单按日期分组，搜索筛选按需展开，优先展示记录。',
      '日历缩短日格，选择日期后直接定位当天明细。',
      '完整分类入口前置，压缩首页目标和报告布局，明确周期分组。',
      '区分预算为零与预算用完，统一分类占比的整数分计算。',
    ],
    notes: ['沿用原包名与升级签名，旧账本和备份可继续读取。'],
  ),
  AppVersionNotes(
    version: '0.4.0',
    title: '总览、日历与报告改版',
    additions: [
      '总览新增小目标进度与四宫格，日历整合到账单标签。',
      '报告中心支持周报月报切换、趋势、分类排行和账目核对。',
      '统一分类身份色与收红支绿，自定义分类颜色随备份保留。',
    ],
    fixes: ['查询月份与发生日期分开，普通记账始终从今天开始。', '周期计划支持实际发生日期，跨月逾期待办可查看。'],
    notes: ['沿用原包名与升级签名，旧账本和备份可继续读取。'],
  ),
  AppVersionNotes(
    version: '0.3.4',
    title: '记账与返回体验优化',
    fixes: [
      '连续记账提供三秒撤销，保留下一笔输入与保存失败的草稿。',
      '统一全量账单入口，编辑取消或保存后返回详情，保留来源筛选。',
      '简化快捷分类，完整分类独立搜索；账单筛选条件可查看和逐项移除。',
    ],
    notes: ['真实手机体验与性能仍待验收。'],
  ),
  AppVersionNotes(
    version: '0.3.3',
    title: '金额卡片对齐与自适应',
    fixes: ['修复账单与统计卡片中的金额拆行及基线错位。', '按系统字体与完整金额自适应列数，改善长金额和大字体显示。'],
    notes: ['保持原有账目与备份格式，支持覆盖安装。'],
  ),
  AppVersionNotes(
    version: '0.3.2',
    title: '主题衔接与图标居中',
    publishedOn: '2026-10-21',
    fixes: [
      '修复毛玻璃页面过渡的浅色闪变，统一新页面与返回过程的主题。',
      '校正蓝白钱包图标的视觉中心，统一桌面遮罩与传统图标的留白。',
      '保留数据重载期间的外观偏好，完善减少动画与分类选中反馈。',
    ],
    notes: ['保持原有账目与备份格式，支持覆盖安装。'],
  ),
  AppVersionNotes(
    version: '0.3.1',
    title: '毛玻璃主题与应用内更新',
    publishedOn: '2026-10-20',
    additions: [
      '统一浅色、深色和毛玻璃主题，优化首页、记账、预算和统计的布局与无障碍。',
      '增加简体中文、繁體中文和English选择，界面立即切换并保存，用户自定义内容保持原文。',
      '增加独立的毛玻璃浅色主题，选择后固定为浅色并跨重启保留。',
      '在应用内下载更新，显示进度并校验安装包，再由系统确认覆盖安装。',
    ],
    fixes: ['保存后的撤销提示在3秒后自动消失。', '检查更新增加官方备用入口，区分网络、超时和校验错误并支持重试。'],
  ),
  AppVersionNotes(
    version: '0.3.0',
    title: '计划、提醒与回顾',
    additions: [
      '为根分类设置月预算，查看分类已用与未分配金额，并可复制上月设置。',
      '管理周期账单与收入，支持确认入账、跳过和重新处理；未确认的计划不会自动记账。',
      '查看每周回顾和历史月报，分别了解支出、收入及每日收支。',
      '增加预算进度提醒与提醒设置，支持关闭；周报与预算提示不会连续弹出。',
      '管理本地恢复点，恢复前预览内容，并保留最近3个、30天内的恢复点。',
      '反馈可预览后交给邮件客户端发送，无客户端时保留草稿或复制内容。',
      '在“关于 PocketFlow”查看各版本更新记录，离线也能阅读。',
    ],
    fixes: [
      '修复首页同一天记录较多时，日收支汇总只计算部分记录的问题。',
      '修复补记日期与保存并继续的日期保留问题，优化小屏分类选择与大字体布局。',
      '修正负数金额的显示，以及Markdown月报中根分类和子分类重复计算的问题。',
      '修复检查更新失败后仍显示旧候选版本的问题，并保持旧版更新清单兼容。',
      '加强保存后撤销的修改冲突检查，避免撤销已经被修改或关联周期计划的账目。',
      '升级分类目录时保留历史分类ID与用户改动，恢复失败时完整回滚。',
    ],
  ),
  AppVersionNotes(
    version: '0.2.1',
    title: '手动检查更新',
    publishedOn: '2026-10-18',
    additions: [
      '在“我的”增加“检查更新”，主动检查后查看新版内容与安装包大小。',
      '通过浏览器下载更新包，再由Android系统确认覆盖安装。',
    ],
    notes: ['仅主动检查时联网，不自动下载、安装或在首页弹出更新提醒。'],
  ),
  AppVersionNotes(
    version: '0.2.0',
    title: '收支与使用体验升级',
    publishedOn: '2026-10-18',
    additions: [
      '支持收入记录、账单搜索筛选、记账日历和收支分类统计。',
      '增加两级分类管理、常用模板和手动储蓄目标。',
      '新增浅色、深色及跟随系统主题，个人设置可跨重启保留。',
      '备份包含主题、目标和模板，并继续兼容旧版备份。',
    ],
    fixes: ['调整四页导航与独立记账入口，避免底部按钮遮挡账单金额。'],
  ),
  AppVersionNotes(
    version: '0.1.1',
    title: '修复Android账本启动',
    publishedOn: '2026-10-17',
    fixes: [
      '修复Android中账本无法读取、预算无法保存、统计持续加载的问题。',
      '读取失败时显示明确提示并支持手动重试，避免一直停留在加载状态。',
    ],
    notes: ['沿用原应用包名与签名，支持覆盖更新并保留原有数据。'],
  ),
  AppVersionNotes(
    version: '0.1.0',
    title: '首个个人测试版本',
    publishedOn: '2026-10-17',
    additions: ['提供月预算、支出记录、分类统计、Markdown月报和JSON备份恢复。', '账本保存在手机本地，无需注册账号。'],
    notes: ['此版本存在Android账本启动问题，已在0.1.1修复。'],
  ),
];
