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
          message = '上次已打开邮件客户端，投递状态未知。草稿保留在本机。';
        }
      }
      dirty = false;
    } catch (e) {
      if (mounted) message = presentationError(e);
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
      if (mounted) setState(() => message = '草稿已保存在本机');
    } catch (e) {
      if (mounted) setState(() => message = presentationError(e));
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
      await widget.store.saveDraft(value);
      await Clipboard.setData(
        ClipboardData(
          text:
              '收件人：$feedbackEmailRecipient\n主题：${feedbackEmailSubject(value)}\n\n${feedbackEmailBody(value)}',
        ),
      );
      dirty = false;
      if (mounted) setState(() => message = '收件人、主题和反馈内容已复制，草稿仍在本机。');
    } catch (e) {
      if (mounted) setState(() => message = presentationError(e));
    }
  }

  Future<void> send() async {
    if (busy) return;
    FeedbackDraft value;
    try {
      value = draft(FeedbackStatus.draft);
      if (!value.validToSend) {
        throw const FormatException('内容去首尾空白后须为10—2000字符');
      }
    } catch (e) {
      setState(() => message = e is FormatException ? e.message : '请检查反馈内容');
      return;
    }
    setState(() => busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('预览反馈邮件'),
          content: SingleChildScrollView(
            child: SelectableText(
              '收件人：$feedbackEmailRecipient\n主题：${feedbackEmailSubject(value)}\n\n${feedbackEmailBody(value)}\n\n确认后打开手机邮件客户端，请在那里完成发送。不会附加账本、数据库、日志、截图或设备标识。请勿填写身份证号或密码。',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('打开邮件客户端'),
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
              ? '已打开邮件客户端，请在那里完成发送；App无法确认是否发送或送达。'
              : '未找到可用的邮件客户端。草稿已保存在本机，可复制内容后自行发送。',
        );
      }
    } catch (e) {
      if (mounted) setState(() => message = presentationError(e));
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
      appBar: AppBar(title: const Text('建议与 Bug 反馈')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SelectableText('反馈邮箱：$feedbackEmailRecipient'),
                const Text('先预览，再由手机邮件客户端发送。草稿保存在本机；只包含你填写的内容与选择附带的环境信息。'),
                DropdownButtonFormField<FeedbackType>(
                  key: ValueKey(id),
                  initialValue: type,
                  items: const [
                    DropdownMenuItem(
                      value: FeedbackType.suggestion,
                      child: Text('功能建议'),
                    ),
                    DropdownMenuItem(
                      value: FeedbackType.bug,
                      child: Text('问题反馈'),
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
                  decoration: const InputDecoration(
                    labelText: '反馈内容（10—2000字符）',
                  ),
                ),
                if (type == FeedbackType.bug)
                  for (final field in [
                    (steps, '操作步骤'),
                    (expected, '期望结果'),
                    (actual, '实际结果'),
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
                  decoration: const InputDecoration(labelText: '联系方式（选填）'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('附带环境信息'),
                  subtitle: Text(
                    'App ${widget.installed?.versionName ?? '未提供'} · build ${widget.installed?.versionCode ?? '未提供'} · Android API ${widget.installed?.androidApi ?? '未提供'}',
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
                  child: Text(busy ? '请稍候…' : '预览反馈邮件'),
                ),
                TextButton(
                  onPressed: busy ? null : save,
                  child: const Text('保存草稿'),
                ),
                TextButton(
                  onPressed: busy ? null : copy,
                  child: const Text('复制邮箱和反馈内容'),
                ),
                if (opened)
                  TextButton(
                    onPressed: busy ? null : newFeedback,
                    child: const Text('写一条新反馈'),
                  ),
              ],
            ),
    ),
  );
}
