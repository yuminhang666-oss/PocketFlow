package cn.pocketflow

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val io = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    private val limit = 50 * 1024 * 1024

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val updates = AppUpdateBridge(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pocketflow/app_updates/v1")
            .setMethodCallHandler { call, result -> updates.handle(call, result) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pocketflow/file_transfer/v1")
            .setMethodCallHandler { call, result -> handle(call, result) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (pending != null) {
            result.error("BUSY", "A file operation is already active", null)
            return
        }
        try {
            when (call.method) {
                "saveText" -> {
                    val (name, mime, bytes) = payload(call)
                    pending = result
                    pendingBytes = bytes
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = mime
                        putExtra(Intent.EXTRA_TITLE, name)
                    }
                    startActivityForResult(intent, 4701)
                }
                "pickJsonText" -> {
                    pending = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain", "application/octet-stream"))
                    }
                    startActivityForResult(intent, 4702)
                }
                "shareTextFile" -> {
                    val (name, mime, bytes) = payload(call)
                    pending = result
                    io.execute {
                        try {
                            val directory = File(cacheDir, "exports").apply { mkdirs() }
                            // Only our private temporary exports expire, never user-selected files.
                            directory.listFiles()?.filter { it.isFile &&
                                System.currentTimeMillis() - it.lastModified() > 7L * 24 * 3600 * 1000 }
                                ?.forEach { it.delete() }
                            val file = File(directory, UUID.randomUUID().toString() + "-" + name)
                            file.outputStream().use { it.write(bytes) }
                            val uri = FileProvider.getUriForFile(this, "$packageName.files", file)
                            runOnUiThread {
                                if (pending !== result) return@runOnUiThread
                                try {
                                    val send = Intent(Intent.ACTION_SEND).apply {
                                        type = mime
                                        putExtra(Intent.EXTRA_STREAM, uri)
                                        clipData = ClipData.newUri(contentResolver, name, uri)
                                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    }
                                    startActivity(Intent.createChooser(send, "分享文件"))
                                    complete(result, true)
                                } catch (_: Exception) { fail(result) }
                            }
                        } catch (_: Exception) { runOnUiThread { fail(result) } }
                    }
                }
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            if (pending === result) fail(result)
            else result.error("FILE_FAILURE", "Unable to open file operation", null)
        }
    }

    private fun payload(call: MethodCall): Triple<String, String, ByteArray> {
        val name = requireNotNull(call.argument<String>("suggestedName"))
        require(name.isNotBlank() && name.length <= 180 && !name.contains('/') &&
            !name.contains('\\') && !name.contains("..") && name.none { it.code < 32 })
        val mime = requireNotNull(call.argument<String>("mimeType"))
        require(mime == "application/json" || mime == "text/markdown" || mime == "text/plain")
        val bytes = requireNotNull(call.argument<ByteArray>("bytes"))
        require(bytes.size <= limit)
        return Triple(name, mime, bytes)
    }

    @Deprecated("Android legacy result bridge required by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 4701 && requestCode != 4702) return
        val result = pending ?: return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            complete(result, if (requestCode == 4701) false else null)
            return
        }
        val bytes = pendingBytes
        io.execute {
            try {
                val response: Any = if (requestCode == 4701) {
                    requireNotNull(bytes)
                    requireNotNull(contentResolver.openOutputStream(uri, "wt")).use {
                        it.write(bytes)
                        it.flush()
                    }
                    true
                } else {
                    val content = requireNotNull(contentResolver.openInputStream(uri)).use { input ->
                        val output = java.io.ByteArrayOutputStream()
                        val buffer = ByteArray(8192)
                        var total = 0
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            total += count
                            require(total <= limit)
                            output.write(buffer, 0, count)
                        }
                        output.toByteArray()
                    }
                    mapOf("name" to displayName(uri), "bytes" to content)
                }
                runOnUiThread { complete(result, response) }
            } catch (_: Exception) { runOnUiThread { fail(result) } }
        }
    }

    private fun displayName(uri: Uri): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) return it.getString(0) ?: "backup.json"
        }
        return "backup.json"
    }

    private fun complete(result: MethodChannel.Result, value: Any?) {
        if (pending !== result) return
        pending = null
        pendingBytes = null
        result.success(value)
    }

    private fun fail(result: MethodChannel.Result) {
        if (pending !== result) return
        pending = null
        pendingBytes = null
        result.error("FILE_FAILURE", "File operation failed", null)
    }

    override fun onDestroy() {
        pending?.let { fail(it) }
        io.shutdown()
        super.onDestroy()
    }
}
