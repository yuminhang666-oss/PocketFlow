import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/contracts/contracts.dart';
import 'package:pocketflow/features/export/data/android_file_transfer_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pocketflow/file_transfer/v1');
  const port = AndroidFileTransferPort();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'UTF-8 bytes, MIME, filename and cancellation match Android host protocol',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'saveText');
        final arguments = call.arguments as Map;
        expect(arguments['suggestedName'], '账单.md');
        expect(arguments['mimeType'], 'text/markdown');
        expect(utf8.decode(arguments['bytes'] as Uint8List), '# 中文\n金额 ¥30.00');
        return false;
      });
      expect(
        await port.saveText(
          suggestedName: '账单.md',
          mimeType: 'text/markdown',
          content: '# 中文\n金额 ¥30.00',
        ),
        false,
      );
    },
  );

  test(
    'picker preserves UTF-8, removes BOM and rejects malformed bytes',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => {
          'name': '备份.json',
          'bytes': Uint8List.fromList(utf8.encode('\uFEFF{"中文":1}')),
        },
      );
      expect((await port.pickJsonText())?.content, '{"中文":1}');
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => {
          'name': 'bad.json',
          'bytes': Uint8List.fromList([0xff]),
        },
      );
      await expectLater(
        port.pickJsonText(),
        throwsA(isA<PocketFlowException>()),
      );
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      expect(await port.pickJsonText(), isNull);
    },
  );
}
