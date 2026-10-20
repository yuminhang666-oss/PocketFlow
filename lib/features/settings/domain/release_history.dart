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
