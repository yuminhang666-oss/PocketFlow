import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import '../../../contracts/contracts.dart';
import '../../../core/database/app_database.dart' show AppDatabase;

class HttpsFeedbackPort implements FeedbackPort {
  HttpsFeedbackPort(this.endpoint);
  final Uri? endpoint;
  @override
  bool get configured =>
      endpoint != null &&
      endpoint!.scheme == 'https' &&
      endpoint!.host.isNotEmpty &&
      endpoint!.userInfo.isEmpty &&
      endpoint!.query.isEmpty &&
      endpoint!.fragment.isEmpty;
  @override
  Future<FeedbackReceipt> submit(FeedbackDraft draft) async {
    if (!configured || !draft.validToSend) {
      throw const PocketFlowException(PocketFlowErrorCode.feedbackUnavailable);
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      return await (() async {
        final req = await client.postUrl(endpoint!);
        req.followRedirects = false;
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(draft.payload()));
        final response = await req.close();
        if (response.statusCode != 200 && response.statusCode != 201) {
          throw const PocketFlowException(
            PocketFlowErrorCode.feedbackUnavailable,
          );
        }
        final bytes = <int>[];
        await for (final chunk in response) {
          if (bytes.length + chunk.length > 8192) {
            throw const FormatException('Invalid receipt');
          }
          bytes.addAll(chunk);
        }
        final raw = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final id = raw['receiptId'] as String,
            at = raw['acceptedAtUtcMs'] as int;
        if (id.isEmpty || id.length > 100 || at <= 0) {
          throw const FormatException('Invalid receipt');
        }
        return FeedbackReceipt(id: id, acceptedAtUtcMs: at);
      })().timeout(const Duration(seconds: 25));
    } catch (_) {
      throw const PocketFlowException(PocketFlowErrorCode.feedbackUnavailable);
    } finally {
      client.close(force: true);
    }
  }
}

class DriftFeedbackDraftStore implements FeedbackDraftStore {
  DriftFeedbackDraftStore(this.db);
  final AppDatabase db;
  @override
  Future<List<FeedbackDraft>> readDrafts() async {
    try {
      return [
        for (final r
            in await db
                .customSelect(
                  'SELECT payload FROM feedback_draft_rows ORDER BY rowid',
                )
                .get())
          _decode(
            jsonDecode(r.read<String>('payload')) as Map<String, dynamic>,
          ),
      ];
    } catch (e) {
      throw PocketFlowException(PocketFlowErrorCode.dataCorrupted, cause: e);
    }
  }

  FeedbackDraft _decode(Map<String, dynamic> j) => FeedbackDraft(
    id: j['feedbackId'] as String,
    type: FeedbackType.values.byName(j['type'] as String),
    content: j['content'] as String,
    steps: j['steps'] as String,
    expected: j['expected'] as String,
    actual: j['actual'] as String,
    contact: j['contact'] as String,
    appVersion: j['appVersion'] as String?,
    buildCode: j['buildCode'] as int?,
    androidApi: j['androidApi'] as int?,
    status: j['status'] == 'submitting'
        ? FeedbackStatus.failed
        : FeedbackStatus.values.byName(j['status'] as String),
    receipt: j['receiptId'] == null
        ? null
        : FeedbackReceipt(
            id: j['receiptId'] as String,
            acceptedAtUtcMs: j['acceptedAtUtcMs'] as int,
          ),
  );
  @override
  Future<void> saveDraft(FeedbackDraft draft) async {
    final payload = {
      ...draft.payload(),
      'status': draft.status.name,
      if (draft.receipt != null) ...{
        'receiptId': draft.receipt!.id,
        'acceptedAtUtcMs': draft.receipt!.acceptedAtUtcMs,
      },
    };
    try {
      await db.customInsert(
        'INSERT INTO feedback_draft_rows(id,payload) VALUES (?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload',
        variables: [
          Variable.withString(draft.id),
          Variable.withString(jsonEncode(payload)),
        ],
        updates: {db.feedbackDraftRows},
      );
    } catch (e) {
      throw PocketFlowException(PocketFlowErrorCode.storageFailure, cause: e);
    }
  }
}
