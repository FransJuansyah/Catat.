package id.catat.catat

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var autoChannel: MethodChannel? = null

    /// Aksi dari notif catat. / share gambar, menunggu diambil Dart.
    private var pendingLaunch: Map<String, Any>? = null
    private var permissionResult: MethodChannel.Result? = null
    private var slipResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        current = java.lang.ref.WeakReference(this)
        AutoCapture.createChannels(this)
        Thread { SlipFile.cleanCache(this) }.start()
        pendingLaunch = launchOf(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        launchOf(intent)?.let {
            pendingLaunch = it
            autoChannel?.invokeMethod("launch", null)
        }
    }

    private fun launchOf(intent: Intent?): Map<String, Any>? {
        intent ?: return null
        return when (intent.action) {
            AutoCapture.ACTION_CAPTURE -> {
                val id = intent.getStringExtra(AutoCapture.EXTRA_CAPTURE_ID) ?: return null
                val capture = AutoCapture.take(this, id) ?: return null
                mapOf("type" to "capture", "capture" to capture)
            }
            AutoCapture.ACTION_REMINDER -> mapOf("type" to "reminder")
            AutoCapture.ACTION_OPEN -> {
                val route = intent.getStringExtra(AutoCapture.EXTRA_ROUTE) ?: return null
                // Tombol "Ubah" tidak menutup notif sendiri.
                NotificationManagerCompat.from(this).cancel(intent.getIntExtra(AutoCapture.EXTRA_NOTIF_ID, 0))
                mapOf("type" to "route", "route" to route)
            }
            Intent.ACTION_SEND -> {
                if (intent.type?.startsWith("image/") != true) return null
                val uri = if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                } ?: return null
                val path = copyShared(uri) ?: return null
                mapOf("type" to "share", "path" to path)
            }
            else -> null
        }
    }

    /// Salin gambar yang dibagikan ke cache (URI dari app lain bisa kedaluwarsa).
    private fun copyShared(uri: Uri): String? = try {
        val target = File(cacheDir, "bagikan_${System.currentTimeMillis()}.jpg")
        SlipFile.copyLimited(this, uri, target)
        target.path
    } catch (e: Exception) {
        android.util.Log.w("catat.share", "Gambar yang dibagikan gagal dibaca: $uri", e)
        null
    }

    @Deprecated("FlutterActivity belum pakai Activity Result API")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_SLIP) return
        val result = slipResult ?: return
        slipResult = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        // Render PDF bisa ratusan ms → jangan di UI thread.
        Thread {
            val path = try {
                SlipFile.toImage(this, uri)
            } catch (e: Exception) {
                android.util.Log.w("catat.slip", "Slip gagal dibuka: $uri", e)
                null
            }
            runOnUiThread {
                if (path != null) {
                    result.success(path)
                } else {
                    result.error("SLIP", "File slip nggak bisa dibuka", null)
                }
            }
        }.start()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            REQUEST_NOTIFICATIONS -> permissionResult?.success(AutoCapture.canPostNotifications(this))
            REQUEST_CAMERA -> permissionResult?.success(cameraGranted())
        }
        permissionResult = null
    }

    private fun cameraGranted() =
        checkSelfPermission(Manifest.permission.CAMERA) == android.content.pm.PackageManager.PERMISSION_GRANTED

    private fun requestPermission(permission: String, code: Int, granted: Boolean, result: MethodChannel.Result) {
        if (granted) {
            result.success(true)
        } else {
            permissionResult = result
            requestPermissions(arrayOf(permission), code)
        }
    }

    private fun autoStatus() = mapOf(
        "sources" to AutoCapture.SOURCES.associateWith { AutoCapture.isSourceOn(this, it) },
        "cameraGranted" to cameraGranted(),
        "listenerAccess" to AutoCapture.hasListenerAccess(this),
        "canNotify" to AutoCapture.canPostNotifications(this),
        "reminder" to DailyReminder.isOn(this),
        "reminderHour" to DailyReminder.HOUR,
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        autoChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "id.catat.catat/auto")
            .apply {
                setMethodCallHandler { call, result ->
                    when (call.method) {
                        "status" -> result.success(autoStatus())
                        "setSource" -> {
                            AutoCapture.setSource(
                                this@MainActivity,
                                call.argument<String>("source")!!,
                                call.argument<Boolean>("on")!!,
                            )
                            result.success(autoStatus())
                        }
                        "requestCamera" -> requestPermission(
                            Manifest.permission.CAMERA,
                            REQUEST_CAMERA,
                            cameraGranted(),
                            result,
                        )
                        "openAppSettings" -> {
                            // Izin Android (kamera, notifikasi) cuma bisa dicabut dari sini.
                            startActivity(
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                                    .setData(Uri.fromParts("package", packageName, null)),
                            )
                            result.success(true)
                        }
                        "setReminder" -> {
                            DailyReminder.set(this@MainActivity, call.argument<Boolean>("on")!!)
                            result.success(autoStatus())
                        }
                        "openAccessSettings" -> {
                            openListenerSettings()
                            result.success(true)
                        }
                        "requestNotifications" -> requestPermission(
                            Manifest.permission.POST_NOTIFICATIONS,
                            REQUEST_NOTIFICATIONS,
                            AutoCapture.canPostNotifications(this@MainActivity),
                            result,
                        )
                        "takeLaunch" -> {
                            result.success(pendingLaunch)
                            pendingLaunch = null
                        }
                        else -> result.notImplemented()
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "id.catat.catat/files")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickSlip" -> {
                        slipResult?.success(null)
                        slipResult = result
                        startActivityForResult(SlipFile.pickIntent(), REQUEST_SLIP)
                    }
                    else -> result.notImplemented()
                }
            }
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

    /// Android 11+: langsung ke sakelar catat. (beberapa ROM, mis. XOS, salah
    /// mengarahkan halaman daftar). Versi lama / gagal: halaman daftar.
    private fun openListenerSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val detail = Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).putExtra(
                Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                android.content.ComponentName(this, CatatNotificationListener::class.java)
                    .flattenToString(),
            )
            try {
                startActivity(detail)
                return
            } catch (e: Exception) {
                // lanjut ke halaman daftar
            }
        }
        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
    }

    override fun onDestroy() {
        if (current?.get() === this) current = null
        super.onDestroy()
    }

    companion object {
        private const val REQUEST_NOTIFICATIONS = 42
        private const val REQUEST_CAMERA = 43
        private const val REQUEST_SLIP = 44
        private var current: java.lang.ref.WeakReference<MainActivity>? = null

        /// Catatan berubah dari latar belakang → UI yang terbuka muat ulang.
        fun notifyDataChanged() {
            current?.get()?.autoChannel?.invokeMethod("dataChanged", null)
        }
    }
}
