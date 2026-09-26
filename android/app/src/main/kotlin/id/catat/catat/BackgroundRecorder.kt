package id.catat.catat

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/// Mesin Flutter tanpa layar untuk catat otomatis: logika pencatatan tetap di
/// Dart (lib/background.dart → BudgetRepository), aplikasi tidak dibuka.
/// Mesin dimatikan 1 menit setelah tugas terakhir.
object BackgroundRecorder {
    private const val CHANNEL = "id.catat.catat/background"
    private const val IDLE_MS = 60_000L
    private const val TAG = "catat.auto"

    private val main = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var ready = false
    private val waiting = ArrayDeque<() -> Unit>()

    private val shutdown = Runnable {
        engine?.destroy()
        engine = null
        channel = null
        ready = false
        waiting.clear()
    }

    private fun start(context: Context) {
        if (engine != null) return
        val app = context.applicationContext
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(app)
        loader.ensureInitializationComplete(app, null)
        val e = FlutterEngine(app)
        val ch = MethodChannel(e.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result ->
            if (call.method == "ready") {
                ready = true
                while (waiting.isNotEmpty()) waiting.removeFirst().invoke()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        e.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "autoRecordMain"),
        )
        engine = e
        channel = ch
    }

    /// Jalankan [task] di thread utama setelah Dart siap.
    private fun run(context: Context, task: (MethodChannel) -> Unit) {
        main.post {
            main.removeCallbacks(shutdown)
            try {
                start(context)
            } catch (e: Exception) {
                Log.w(TAG, "Mesin latar belakang gagal jalan", e)
                return@post
            }
            val job = { channel?.let(task) ?: Unit }
            if (ready) job() else waiting.addLast(job)
        }
    }

    private fun idle() {
        main.removeCallbacks(shutdown)
        main.postDelayed(shutdown, IDLE_MS)
    }

    private fun result(onValue: (Any?) -> Unit, onFail: () -> Unit) = object : MethodChannel.Result {
        override fun success(value: Any?) {
            onValue(value)
            idle()
        }

        override fun error(code: String, message: String?, details: Any?) {
            Log.w(TAG, "Dart error $code: $message")
            onFail()
            idle()
        }

        override fun notImplemented() {
            Log.w(TAG, "Dart belum siap / method tidak ada")
            onFail()
            idle()
        }
    }

    /// Catat langsung. [fallback] = mesin latar belakang error → tawarkan
    /// catat manual lewat notif.
    fun record(context: Context, capture: Map<String, Any>, fallback: () -> Unit) {
        run(context) { ch ->
            ch.invokeMethod(
                "record",
                capture,
                result(
                    onValue = { value ->
                        @Suppress("UNCHECKED_CAST")
                        val record = value as? Map<String, Any?>
                        if (record == null) {
                            // Bukan transaksi (iklan, OTP, tagihan, info
                            // saldo) / belum setup: diam, jangan ganggu user.
                            Log.i(TAG, "Bukan transaksi, dilewati")
                        } else if (record["duplicate"] == true) {
                            // User sudah catat manual / scan duluan: diam saja.
                            Log.i(TAG, "Sudah tercatat, dilewati")
                            (record["id"] as? String)?.let { AutoCapture.addMatched(context, it) }
                        } else {
                            AutoCapture.postRecorded(context, record)
                            MainActivity.notifyDataChanged()
                        }
                    },
                    onFail = fallback,
                ),
            )
        }
    }

    fun undo(context: Context, id: String, income: Boolean, done: (Boolean) -> Unit) {
        run(context) { ch ->
            ch.invokeMethod(
                "undo",
                mapOf("id" to id, "income" to income),
                result(
                    onValue = {
                        MainActivity.notifyDataChanged()
                        done(true)
                    },
                    onFail = { done(false) },
                ),
            )
        }
    }
}

/// Tombol "Batalkan" di notif "Tercatat": hapus lagi tanpa membuka aplikasi.
class UndoRecordReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra(AutoCapture.EXTRA_RECORD_ID) ?: return
        val income = intent.getBooleanExtra(AutoCapture.EXTRA_INCOME, false)
        val pending = goAsync()
        BackgroundRecorder.undo(context, id, income) { ok ->
            AutoCapture.postUndone(context, id, ok)
            pending.finish()
        }
    }
}
