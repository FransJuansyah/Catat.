package id.catat.catat

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "id.catat.catat/downloads")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "save" -> result.success(
                            save(
                                call.argument<String>("path")!!,
                                call.argument<String>("name")!!,
                                call.argument<String>("mime")!!,
                            ),
                        )
                        "open" -> {
                            open(call.argument<String>("uri")!!, call.argument<String>("mime")!!)
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("DOWNLOADS", e.message, null)
                }
            }
    }

    /// Salin file ke folder Download. Android 10+ lewat MediaStore (tanpa izin
    /// penyimpanan); versi lama: folder Download milik aplikasi.
    private fun save(path: String, name: String, mime: String): Map<String, String> {
        val source = File(path)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, mime)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Gagal membuat file di Download")
            resolver.openOutputStream(uri)!!.use { out -> source.inputStream().use { it.copyTo(out) } }
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return mapOf("uri" to uri.toString(), "location" to "Download")
        }
        val dir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)!!
        val target = File(dir, name)
        source.copyTo(target, overwrite = true)
        val uri = FileProvider.getUriForFile(this, "$packageName.laporan", target)
        return mapOf("uri" to uri.toString(), "location" to "folder aplikasi")
    }

    private fun open(uri: String, mime: String) {
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(Uri.parse(uri), mime)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(Intent.createChooser(intent, "Buka laporan").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}
