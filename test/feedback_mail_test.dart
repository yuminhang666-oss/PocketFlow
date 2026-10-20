import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/features/feedback/data/android_feedback_mail_port.dart';
import 'package:pocketflow/features/backup/domain/json_backup_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FeedbackDraft draft({bool environment = false}) => FeedbackDraft(
    id: '3d8d9db1-b31b-4dda-a193-9114e84a67d9',
    type: FeedbackType.bug,
    content: 'SYNTHETIC 中文 & ? # % + email test',
    steps: 'SYNTHETIC steps',
    expected: 'SYNTHETIC expected',
    actual: 'SYNTHETIC actual',
    appVersion: environment ? '0.3.0' : null,
    buildCode: environment ? 5 : null,
    androidApi: environment ? 36 : null,
  );
  test(
    'email contains only explicit form and opted-in environment, fixed recipient',
    () {
      expect(feedbackEmailRecipient, 'yuminhang666@gmail.com');
      expect(feedbackEmailSubject(draft()), 'PocketFlow 问题反馈');
      expect(feedbackEmailBody(draft()), contains('中文 & ? # % +'));
      expect(feedbackEmailBody(draft()), isNot(contains('Android API')));
      expect(
        feedbackEmailBody(draft(environment: true)),
        contains('Android API 36'),
      );
      expect(feedbackEmailBody(draft()), isNot(contains('数据库')));
    },
  );
  test(
    'native handoff uses a fixed mailbox and has no automatic-send command',
    () async {
      MethodCall? received;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(AndroidFeedbackMailPort.channel, (
        call,
      ) async {
        received = call;
        return true;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          AndroidFeedbackMailPort.channel,
          null,
        ),
      );
      expect(
        await const AndroidFeedbackMailPort().openComposer(draft()),
        isTrue,
      );
      expect(received!.method, 'openComposer');
      expect(received!.arguments, {
        'to': feedbackEmailRecipient,
        'subject': 'PocketFlow 问题反馈',
        'body': feedbackEmailBody(draft()),
      });
    },
  );
  test('no email client returns false and native failure is visible', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      AndroidFeedbackMailPort.channel,
      (_) async => false,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        AndroidFeedbackMailPort.channel,
        null,
      ),
    );
    expect(
      await const AndroidFeedbackMailPort().openComposer(draft()),
      isFalse,
    );
    messenger.setMockMethodCallHandler(
      AndroidFeedbackMailPort.channel,
      (_) async => throw PlatformException(code: 'MAIL_UNAVAILABLE'),
    );
    await expectLater(
      const AndroidFeedbackMailPort().openComposer(draft()),
      throwsA(isA<PocketFlowException>()),
    );
  });
  test('documented v3 backup remains a validated synthetic example', () {
    final decoded = const JsonBackupCodec().decode(
      File('docs/examples/backup-v3.json').readAsStringSync(),
    );
    expect(decoded.sourceFormatVersion, 3);
    expect(decoded.plans.rules, isEmpty);
  });
}
