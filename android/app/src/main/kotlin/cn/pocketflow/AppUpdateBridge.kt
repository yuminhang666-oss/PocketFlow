package cn.pocketflow

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest
import java.io.File
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL
import java.util.concurrent.Executors

class AppUpdateBridge(private val activity: Activity) {
    private val io = Executors.newSingleThreadExecutor()
    @Volatile private var busy = false
    @Volatile private var cancelled = false
    @Volatile private var received = 0L
    @Volatile private var connection: HttpURLConnection? = null
    private var ready: DownloadSpec? = null
    private val directory get() = File(activity.cacheDir, "updates")
    private val apkFile get() = File(directory, "update.apk")
    private data class DownloadSpec(val url: String, val bytes: Long, val sha256: String,
        val versionCode: Long, val versionName: String)

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
                        "certificateSha256" to digest, "androidApi" to Build.VERSION.SDK_INT))
                }
                "openDownload" -> {
                    val url = Uri.parse(requireNotNull(call.argument<String>("url")))
                    require(url.scheme == "https" && url.host == "github.com" && url.userInfo == null && url.port == -1)
                    require(url.query == null && url.fragment == null)
                    require(url.path == "/yuminhang666-oss/PocketFlow/releases" ||
                        Regex("^/yuminhang666-oss/PocketFlow/releases/download/(mvp-)?v[0-9]+\\.[0-9]+\\.[0-9]+(-(debug|release))?/PocketFlow-[0-9]+\\.[0-9]+\\.[0-9]+-(debug|release)\\.apk$").matches(url.path ?: ""))
                    activity.startActivity(Intent(Intent.ACTION_VIEW, url).addCategory(Intent.CATEGORY_BROWSABLE))
                    result.success(null)
                }
                "downloadUpdate" -> startDownload(call, result)
                "downloadedBytes" -> result.success(received)
                "cancelDownload" -> {
                    cancelled = true
                    connection?.disconnect()
                    result.success(null)
                }
                "installUpdate" -> install(result)
                else -> result.notImplemented()
            }
        } catch (_: Exception) { result.error("UPDATE_UNAVAILABLE", "Unable to open update operation", null) }
    }

    private fun startDownload(call: MethodCall, result: MethodChannel.Result) {
        if (busy) { result.error("BUSY", "Download already active", null); return }
        val spec = DownloadSpec(requireNotNull(call.argument<String>("url")),
            requireNotNull(call.argument<Number>("bytes")).toLong(),
            requireNotNull(call.argument<String>("sha256")),
            requireNotNull(call.argument<Number>("versionCode")).toLong(),
            requireNotNull(call.argument<String>("versionName")))
        val uri = Uri.parse(spec.url)
        require(uri.scheme == "https" && uri.host == "github.com" && uri.port == -1 &&
            uri.userInfo == null && uri.query == null && uri.fragment == null)
        require(Regex("^/yuminhang666-oss/PocketFlow/releases/(download/(mvp-)?v[0-9]+\\.[0-9]+\\.[0-9]+(-(debug|release))?|latest/download)/PocketFlow-[0-9]+\\.[0-9]+\\.[0-9]+-(debug|release)\\.apk$").matches(uri.path ?: ""))
        require(spec.bytes in 1..2147483648L && Regex("^[a-f0-9]{64}$").matches(spec.sha256))
        require(Regex("^[0-9]+\\.[0-9]+\\.[0-9]+$").matches(spec.versionName) && spec.versionCode > 0)
        busy = true; cancelled = false; received = 0; ready = null
        io.execute {
            val part = File(directory, "update.part")
            try {
                check(directory.isDirectory || directory.mkdirs())
                apkFile.delete()
                val started = System.nanoTime()
                var url = URL(spec.url)
                var response: HttpURLConnection? = null
                for (redirect in 0..5) {
                    check(!cancelled)
                    require(url.protocol == "https" && url.userInfo == null && url.port == -1 &&
                        url.host in setOf("github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com"))
                    val next = (url.openConnection() as HttpURLConnection).apply {
                        connectTimeout = 10000; readTimeout = 15000; instanceFollowRedirects = false
                        setRequestProperty("User-Agent", "PocketFlow-Updater")
                        setRequestProperty("Accept-Encoding", "identity")
                    }
                    connection = next
                    val status = next.responseCode
                    if (status in listOf(301, 302, 303, 307, 308)) {
                        val location = requireNotNull(next.getHeaderField("Location"))
                        url = URL(url, location); next.disconnect()
                    } else {
                        check(status == 200)
                        response = next; break
                    }
                }
                val responseBody = checkNotNull(response)
                if (responseBody.contentLengthLong >= 0) {
                    require(responseBody.contentLengthLong == spec.bytes)
                }
                responseBody.inputStream.use { input ->
                    part.outputStream().use { output ->
                        val buffer = ByteArray(65536)
                        while (true) {
                            check(!cancelled)
                            if (System.nanoTime() - started > 300_000_000_000L) throw SocketTimeoutException()
                            val count = input.read(buffer)
                            if (count < 0) break
                            require(received + count <= spec.bytes)
                            output.write(buffer, 0, count); received += count
                        }
                    }
                }
                check(!cancelled)
                verify(part, spec)
                check(!cancelled)
                check(part.renameTo(apkFile))
                ready = spec
                busy = false
                activity.runOnUiThread { result.success(null) }
            } catch (e: Exception) {
                part.delete(); apkFile.delete(); ready = null
                val code = when {
                    cancelled -> "CANCELLED"
                    e is SocketTimeoutException -> "TIMEOUT"
                    e is IllegalArgumentException || e is SecurityException -> "INTEGRITY"
                    else -> "DOWNLOAD"
                }
                busy = false
                activity.runOnUiThread { result.error(code, "Update download failed", null) }
            } finally {
                connection?.disconnect(); connection = null; busy = false
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun verify(file: File, spec: DownloadSpec) {
        require(file.length() == spec.bytes)
        val hash = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(65536)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                hash.update(buffer, 0, count)
            }
        }
        require(hash.digest().joinToString("") { "%02x".format(it.toInt() and 0xff) } == spec.sha256)
        val flags = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
        val installed = activity.packageManager.getPackageInfo(activity.packageName, flags)
        val archive = requireNotNull(activity.packageManager.getPackageArchiveInfo(file.path, flags))
        require(archive.packageName == activity.packageName && archive.versionName == spec.versionName)
        val archiveCode = if (Build.VERSION.SDK_INT >= 28) archive.longVersionCode else archive.versionCode.toLong()
        val currentCode = if (Build.VERSION.SDK_INT >= 28) installed.longVersionCode else installed.versionCode.toLong()
        require(archiveCode == spec.versionCode && archiveCode > currentCode)
        val currentSigners = if (Build.VERSION.SDK_INT >= 28) installed.signingInfo!!.apkContentsSigners else installed.signatures!!
        val archiveSigners = if (Build.VERSION.SDK_INT >= 28) archive.signingInfo!!.apkContentsSigners else archive.signatures!!
        require(currentSigners.size == 1 && archiveSigners.size == 1 &&
            currentSigners[0] == archiveSigners[0])
    }

    private fun install(result: MethodChannel.Result) {
        val spec = ready
        if (spec == null || !apkFile.isFile || busy) {
            result.error("INTEGRITY", "No verified package available", null); return
        }
        if (Build.VERSION.SDK_INT >= 26 && !activity.packageManager.canRequestPackageInstalls()) {
            activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:${activity.packageName}")))
            result.success(false); return
        }
        io.execute {
            try {
                verify(apkFile, spec)
                activity.runOnUiThread {
                    try {
                        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.files", apkFile)
                        activity.startActivity(Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        })
                        result.success(true)
                    } catch (_: Exception) { result.error("INSTALLER", "Cannot open installer", null) }
                }
            } catch (_: Exception) {
                apkFile.delete(); ready = null
                activity.runOnUiThread { result.error("INTEGRITY", "Package verification failed", null) }
            }
        }
    }
}
