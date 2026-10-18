package cn.pocketflow

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class AppUpdateBridge(private val activity: Activity) {

    @Suppress("DEPRECATION")
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "installedApp" -> {
                    val flags = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
                    val info = activity.packageManager.getPackageInfo(activity.packageName, flags)
                    val signatures = if (Build.VERSION.SDK_INT >= 28) info.signingInfo!!.apkContentsSigners else info.signatures!!
                    require(signatures.size == 1)
                    val digest = MessageDigest.getInstance("SHA-256").digest(signatures[0].toByteArray())
                        .joinToString("") { "%02x".format(it.toInt() and 0xff) }
                    result.success(mapOf("applicationId" to activity.packageName, "versionName" to info.versionName,
                        "versionCode" to if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong(),
                        "certificateSha256" to digest))
                }
                "openDownload" -> {
                    val url = Uri.parse(requireNotNull(call.argument<String>("url")))
                    require(url.scheme == "https" && url.host == "github.com" && url.userInfo == null && url.port == -1)
                    require(url.query == null && url.fragment == null)
                    require(url.path == "/yuminhang666-oss/PocketFlow/releases" ||
                        Regex("^/yuminhang666-oss/PocketFlow/releases/download/(mvp-)?v[0-9]+\\.[0-9]+\\.[0-9]+(-debug)?/PocketFlow-[0-9]+\\.[0-9]+\\.[0-9]+-debug\\.apk$").matches(url.path ?: ""))
                    activity.startActivity(Intent(Intent.ACTION_VIEW, url).addCategory(Intent.CATEGORY_BROWSABLE))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (_: Exception) { result.error("UPDATE_UNAVAILABLE", "Unable to open update operation", null) }
    }
}
