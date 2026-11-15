package com.example.shtager

import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** مزود ملفات خاص بالوصولات (حتى ما يتعارض مع مزود share_plus). */
class ReceiptFileProvider : FileProvider()

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "shtager/native")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "shareToWhatsApp" -> result.success(
                            shareToWhatsApp(
                                call.argument<String>("path")!!,
                                call.argument<String>("text") ?: "",
                                call.argument<String>("phone") ?: ""
                            )
                        )
                        "saveToDownloads" -> result.success(
                            saveToDownloads(call.argument<String>("path")!!, call.argument<String>("name")!!)
                        )
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("native_error", e.message, null)
                }
            }
    }

    /**
     * يفتح الواتساب ومعه ملف الـ PDF. إذا انطى رقم، يفتح محادثة الشخص مباشرة
     * (عن طريق extra "jid")، وإذا لا، الواتساب يطلب منك تختار الشخص.
     */
    private fun shareToWhatsApp(path: String, text: String, phone: String): Boolean {
        val uri = FileProvider.getUriForFile(this, "$packageName.receipts", File(path))
        for (pkg in listOf("com.whatsapp", "com.whatsapp.w4b")) {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                setPackage(pkg)
                putExtra(Intent.EXTRA_STREAM, uri)
                if (text.isNotEmpty()) putExtra(Intent.EXTRA_TEXT, text)
                if (phone.isNotEmpty()) putExtra("jid", "$phone@s.whatsapp.net")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            try {
                startActivity(intent)
                return true
            } catch (_: ActivityNotFoundException) {
                // جرب الواتساب بزنس
            }
        }
        return false
    }

    /** يحفظ الملف بمجلد Download/Shtager ويرجع مكانه. */
    private fun saveToDownloads(path: String, name: String): String {
        val src = File(path)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Shtager")
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("تعذر إنشاء الملف")
            contentResolver.openOutputStream(uri)!!.use { out -> src.inputStream().use { it.copyTo(out) } }
            return "Download/Shtager/$name"
        }
        @Suppress("DEPRECATION")
        val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "Shtager")
        val target = try {
            dir.mkdirs(); File(dir, name).also { src.copyTo(it, overwrite = true) }
        } catch (_: Exception) {
            val fallback = File(getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS), name)
            src.copyTo(fallback, overwrite = true)
        }
        return target.absolutePath
    }
}
