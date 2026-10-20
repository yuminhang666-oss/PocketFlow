enum FeedbackType { suggestion, bug }

enum FeedbackStatus { draft, submitting, submitted, failed, mailOpened }

const feedbackEmailRecipient = 'yuminhang666@gmail.com';

String feedbackEmailSubject(FeedbackDraft draft) =>
    'PocketFlow ${draft.type == FeedbackType.bug ? '问题反馈' : '功能建议'}';

String feedbackEmailBody(FeedbackDraft draft) => [
  feedbackEmailSubject(draft),
  '反馈编号：${draft.id}',
  '\n反馈内容：\n${draft.content.trim()}',
  if (draft.type == FeedbackType.bug) ...[
    '\n操作步骤：\n${draft.steps.trim()}',
    '\n期望结果：\n${draft.expected.trim()}',
    '\n实际结果：\n${draft.actual.trim()}',
  ],
  if (draft.contact.trim().isNotEmpty) '\n联系方式：${draft.contact.trim()}',
  if (draft.appVersion != null)
    '\n环境信息：App ${draft.appVersion} / build ${draft.buildCode} / Android API ${draft.androidApi ?? '未提供'}',
].join('\n');

final class FeedbackDraft {
  FeedbackDraft({
    required this.id,
    required this.type,
    required this.content,
    this.steps = '',
    this.expected = '',
    this.actual = '',
    this.contact = '',
    this.appVersion,
    this.buildCode,
    this.androidApi,
    this.status = FeedbackStatus.draft,
    this.receipt,
    this.privacyNoticeVersion = 1,
  }) {
    if (!RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        ).hasMatch(id) ||
        content.runes.length > 2000 ||
        contact.runes.length > 100 ||
        [steps, expected, actual].any((v) => v.runes.length > 2000) ||
        privacyNoticeVersion != 1 ||
        (appVersion == null) != (buildCode == null) ||
        (appVersion != null && appVersion!.length > 40)) {
      throw const FormatException('反馈字段无效');
    }
  }
  final String id, content, steps, expected, actual, contact;
  final FeedbackType type;
  final FeedbackStatus status;
  final String? appVersion;
  final int? buildCode, androidApi;
  final int privacyNoticeVersion;
  final FeedbackReceipt? receipt;
  bool get validToSend => content.trim().runes.length >= 10;
  Map<String, Object?> payload() => {
    'feedbackId': id,
    'type': type.name,
    'content': content.trim(),
    'steps': steps.trim(),
    'expected': expected.trim(),
    'actual': actual.trim(),
    'contact': contact.trim(),
    if (appVersion != null) ...{
      'appVersion': appVersion,
      'buildCode': buildCode,
      if (androidApi != null) 'androidApi': androidApi,
    },
    'privacyNoticeVersion': privacyNoticeVersion,
  };
}

final class FeedbackReceipt {
  const FeedbackReceipt({required this.id, required this.acceptedAtUtcMs});
  final String id;
  final int acceptedAtUtcMs;
}
