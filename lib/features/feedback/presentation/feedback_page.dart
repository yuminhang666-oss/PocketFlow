import 'package:pocketflow/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../contracts/contracts.dart';
import '../../../shared/widgets/presentation_errors.dart';
import '../../transactions/data/entry_id.dart';
import '../../../core/domain/app_update.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({
    super.key,
    required this.port,
    required this.store,
    this.installed,
  });
  final FeedbackMailPort port;
  final FeedbackDraftStore store;
  final InstalledApp? installed;
  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final content = TextEditingController(),
      steps = TextEditingController(),
      expected = TextEditingController(),
      actual = TextEditingController(),
      contact = TextEditingController();
  String id = newEntryId();
  FeedbackType type = FeedbackType.suggestion;
  bool environment = true,
      busy = false,
      dirty = false,
      loading = true,
      opened = false;
  String? message;
  @override
  void initState() {
    super.initState();
    load();
    for (final c in [content, steps, expected, actual, contact]) {
      c.addListener(() => dirty = true);
    }
  }

  Future<void> load() async {
    try {
      final drafts = await widget.store.readDrafts();
      if (!mounted) return;
      final existing = drafts.lastOrNull;
      if (existing != null) {
        id = existing.id;
        type = existing.type;
        content.text = existing.content;
        steps.text = existing.steps;
        expected.text = existing.expected;
        actual.text = existing.actual;
        contact.text = existing.contact;
        environment = existing.appVersion != null;
        if (existing.status == FeedbackStatus.mailOpened) {
          opened = true;
          message = tr(context, "上次已打开邮件客户端，投递状态未知。草稿保留在本机。");
        }
      }
      dirty = false;
    } catch (e) {
      if (mounted) message = tr(context, presentationError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  FeedbackDraft draft(FeedbackStatus status) => FeedbackDraft(
    id: id,
    type: type,
    content: content.text,
    steps: steps.text,
    expected: expected.text,
    actual: actual.text,
    contact: contact.text,
    appVersion: environment ? widget.installed?.versionName : null,
    buildCode: environment ? widget.installed?.versionCode : null,
    androidApi: environment ? widget.installed?.androidApi : null,
    status: status,
  );
  @override
  void dispose() {
    for (final c in [content, steps, expected, actual, contact]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.store.saveDraft(draft(FeedbackStatus.draft));
      dirty = false;
      if (mounted) setState(() => message = tr(context, "草稿已保存在本机"));
    } catch (e) {
      if (mounted) setState(() => message = tr(context, presentationError(e)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> newFeedback() async {
    if (busy) return;
    if (dirty) {
      await save();
      if (dirty || !mounted) return;
    }
    for (final c in [content, steps, expected, actual, contact]) {
      c.clear();
    }
    setState(() {
      id = newEntryId();
      opened = false;
      message = null;
      type = FeedbackType.suggestion;
      dirty = false;
    });
  }

  Future<void> copy() async {
    try {
      final value = draft(FeedbackStatus.draft);
      final clipboardText = tr(context, "收件人：{0}\n主题：{1}\n\n{2}", [
        feedbackEmailRecipient,
        feedbackEmailSubject(value),
        feedbackEmailBody(value),
      ]);
      final copiedNotice = tr(context, "收件人、主题和反馈内容已复制，草稿仍在本机。");
      await widget.store.saveDraft(value);
      await Clipboard.setData(ClipboardData(text: clipboardText));
      dirty = false;
      if (mounted) {
        setState(() => message = copiedNotice);
      }
    } catch (e) {
      if (mounted) setState(() => message = tr(context, presentationError(e)));
    }
  }

  Future<void> send() async {
    if (busy) return;
    FeedbackDraft value;
    try {
      value = draft(FeedbackStatus.draft);
      if (!value.validToSend) {
        throw FormatException(tr(context, "内容去首尾空白后须为10—2000字符"));
      }
    } catch (e) {
      setState(
        () =>
            message = e is FormatException ? e.message : tr(context, "请检查反馈内容"),
      );
      return;
    }
    setState(() => busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(tr(context, "预览反馈邮件")),
          content: SingleChildScrollView(
            child: SelectableText(
              tr(
                context,
                "收件人：{0}\n主题：{1}\n\n{2}\n\n确认后打开手机邮件客户端，请在那里完成发送。不会附加账本、数据库、日志、截图或设备标识。请勿填写身份证号或密码。",
                [
                  feedbackEmailRecipient,
                  feedbackEmailSubject(value),
                  feedbackEmailBody(value),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(tr(context, "取消")),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text(tr(context, "打开邮件客户端")),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await widget.store.saveDraft(value);
      dirty = false;
      final launched = await widget.port.openComposer(value);
      if (launched) {
        opened = true;
        await widget.store.saveDraft(draft(FeedbackStatus.mailOpened));
      }
      if (mounted) {
        setState(
          () => message = launched
              ? tr(context, "已打开邮件客户端，请在那里完成发送；App无法确认是否发送或送达。")
              : tr(context, "未找到可用的邮件客户端。草稿已保存在本机，可复制内容后自行发送。"),
        );
      }
    } catch (e) {
      if (mounted) setState(() => message = tr(context, presentationError(e)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy && !dirty,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop || busy || !dirty) return;
      await save();
      if (context.mounted && !dirty) Navigator.pop(context);
    },
    child: Scaffold(
      appBar: AppBar(title: Text(tr(context, "建议与 Bug 反馈"))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SelectableText(
                  tr(context, "反馈邮箱：{0}", [feedbackEmailRecipient]),
                ),
                Text(
                  tr(context, "先预览，再由手机邮件客户端发送。草稿保存在本机；只包含你填写的内容与选择附带的环境信息。"),
                ),
                DropdownButtonFormField<FeedbackType>(
                  key: ValueKey(id),
                  initialValue: type,
                  items: [
                    DropdownMenuItem(
                      value: FeedbackType.suggestion,
                      child: Text(tr(context, "功能建议")),
                    ),
                    DropdownMenuItem(
                      value: FeedbackType.bug,
                      child: Text(tr(context, "问题反馈")),
                    ),
                  ],
                  onChanged: busy
                      ? null
                      : (v) => setState(() {
                          type = v!;
                          dirty = true;
                          opened = false;
                        }),
                ),
                TextField(
                  controller: content,
                  enabled: !busy,
                  maxLength: 2000,
                  minLines: 4,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: tr(context, "反馈内容（10—2000字符）"),
                  ),
                ),
                if (type == FeedbackType.bug)
                  for (final field in [
                    (steps, tr(context, "操作步骤")),
                    (expected, tr(context, "期望结果")),
                    (actual, tr(context, "实际结果")),
                  ])
                    TextField(
                      controller: field.$1,
                      enabled: !busy,
                      maxLength: 2000,
                      maxLines: 3,
                      decoration: InputDecoration(labelText: field.$2),
                    ),
                TextField(
                  controller: contact,
                  enabled: !busy,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: tr(context, "联系方式（选填）"),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr(context, "附带环境信息")),
                  subtitle: Text(
                    tr(context, "App {0} · build {1} · Android API {2}", [
                      widget.installed?.versionName ?? tr(context, "未提供"),
                      widget.installed?.versionCode ?? tr(context, "未提供"),
                      widget.installed?.androidApi ?? tr(context, "未提供"),
                    ]),
                  ),
                  value: environment,
                  onChanged: busy
                      ? null
                      : (v) => setState(() {
                          environment = v;
                          dirty = true;
                        }),
                ),
                if (message != null) SelectableText(message!),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: busy ? null : send,
                  child: Text(
                    busy ? tr(context, "请稍候…") : tr(context, "预览反馈邮件"),
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : save,
                  child: Text(tr(context, "保存草稿")),
                ),
                TextButton(
                  onPressed: busy ? null : copy,
                  child: Text(tr(context, "复制邮箱和反馈内容")),
                ),
                if (opened)
                  TextButton(
                    onPressed: busy ? null : newFeedback,
                    child: Text(tr(context, "写一条新反馈")),
                  ),
              ],
            ),
    ),
  );
}
