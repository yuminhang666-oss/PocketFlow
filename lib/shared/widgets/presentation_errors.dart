import '../../contracts/pocketflow_exception.dart';

String presentationError(Object error) {
  if (error is! PocketFlowException) return '暂时无法完成，请重试';
  return switch (error.code) {
    PocketFlowErrorCode.invalidAmount => '请输入有效金额，最多保留两位小数',
    PocketFlowErrorCode.invalidDate => '请选择有效日期，支出日期不能晚于今天',
    PocketFlowErrorCode.invalidCategory => '该分类暂不可用，请重新选择',
    PocketFlowErrorCode.notFound => '这笔记录已不存在，请刷新后重试',
    PocketFlowErrorCode.storageFailure => '账本暂时无法保存，请重试',
    PocketFlowErrorCode.dataCorrupted => '账本数据无法读取，请检查备份或重试',
    PocketFlowErrorCode.unsupportedBackupVersion => '当前版本不支持这份备份',
    PocketFlowErrorCode.invalidBackup => '这份备份无法读取，请选择有效备份',
    PocketFlowErrorCode.backupFailed => '备份未完成，请重试',
    PocketFlowErrorCode.restoreFailed => '恢复未完成，请重试',
    PocketFlowErrorCode.exportFailed => '导出未完成，请重试',
    PocketFlowErrorCode.importFailed => '文件无法读取，请重新选择',
    PocketFlowErrorCode.conflict => '记录或计划已变化，请刷新后重试',
    PocketFlowErrorCode.feedbackUnavailable => '暂时无法打开反馈邮件，草稿已保留，可复制内容后发送',
  };
}
