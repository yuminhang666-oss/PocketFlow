import 'package:flutter/services.dart';
import '../../../contracts/contracts.dart';

class AndroidFeedbackMailPort implements FeedbackMailPort {
  const AndroidFeedbackMailPort();
  static const channel = MethodChannel('pocketflow/feedback_mail/v1');
  @override
  Future<bool> openComposer(FeedbackDraft draft) async {
    if (!draft.validToSend) {
      throw const PocketFlowException(PocketFlowErrorCode.feedbackUnavailable);
    }
    try {
      return await channel.invokeMethod<bool>('openComposer', {
            'to': feedbackEmailRecipient,
            'subject': feedbackEmailSubject(draft),
            'body': feedbackEmailBody(draft),
          }) ??
          false;
    } on PlatformException {
      throw const PocketFlowException(PocketFlowErrorCode.feedbackUnavailable);
    }
  }
}
