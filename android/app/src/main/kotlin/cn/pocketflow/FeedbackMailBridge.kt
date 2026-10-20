package cn.pocketflow

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class FeedbackMailBridge(private val activity: Activity) {
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "openComposer") { result.notImplemented(); return }
        try {
            val recipient = requireNotNull(call.argument<String>("to"))
            val subject = requireNotNull(call.argument<String>("subject"))
            val body = requireNotNull(call.argument<String>("body"))
            require(recipient == "yuminhang666@gmail.com")
            require(subject.length in 1..200 && !subject.contains('\n') && !subject.contains('\r'))
            require(body.length in 1..12000)
            val uri = Uri.parse("mailto:${recipient}?subject=${Uri.encode(subject)}&body=${Uri.encode(body)}")
            val intent = Intent(Intent.ACTION_SENDTO, uri).apply {
                putExtra(Intent.EXTRA_EMAIL, arrayOf(recipient))
                putExtra(Intent.EXTRA_SUBJECT, subject)
                putExtra(Intent.EXTRA_TEXT, body)
            }
            if (intent.resolveActivity(activity.packageManager) == null) {
                result.success(false)
            } else {
                activity.startActivity(intent)
                // Android provides no email delivery result. Never claim sent.
                result.success(true)
            }
        } catch (_: ActivityNotFoundException) {
            result.success(false)
        } catch (_: Exception) {
            result.error("MAIL_UNAVAILABLE", "Unable to open email composer", null)
        }
    }
}
