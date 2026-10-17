import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../contracts/contracts.dart';

/// Flutter half of an explicit Android host protocol. Requires D to implement
/// the channel before composition injects this adapter (no silent fallback).
final class AndroidFileTransferPort implements FileTransferPort {
  const AndroidFileTransferPort({
    this._channel = const MethodChannel('pocketflow/file_transfer/v1'),
  });
  final MethodChannel _channel;

  @override
  Future<bool> saveText({
    required String suggestedName,
    required String mimeType,
    required String content,
  }) => _write('saveText', suggestedName, mimeType, content);

  @override
  Future<bool> shareTextFile({
    required String suggestedName,
    required String mimeType,
    required String content,
  }) => _write('shareTextFile', suggestedName, mimeType, content);

  Future<bool> _write(
    String method,
    String name,
    String mime,
    String content,
  ) async {
    try {
      final result = await _channel.invokeMethod<Object?>(method, {
        'suggestedName': name,
        'mimeType': mime,
        'bytes': Uint8List.fromList(utf8.encode(content)),
      });
      if (result is! bool) throw const FormatException('Invalid host result');
      return result;
    } catch (_) {
      throw const PocketFlowException(PocketFlowErrorCode.exportFailed);
    }
  }

  @override
  Future<SelectedTextFile?> pickJsonText() async {
    try {
      final result = await _channel.invokeMethod<Object?>('pickJsonText');
      if (result == null) return null;
      if (result is! Map ||
          result['name'] is! String ||
          result['bytes'] is! Uint8List) {
        throw const FormatException('Invalid host file');
      }
      var content = utf8.decode(
        result['bytes'] as Uint8List,
        allowMalformed: false,
      );
      if (content.startsWith('\uFEFF')) content = content.substring(1);
      return SelectedTextFile(name: result['name'] as String, content: content);
    } catch (_) {
      throw const PocketFlowException(PocketFlowErrorCode.importFailed);
    }
  }
}
