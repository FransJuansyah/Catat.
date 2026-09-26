package id.catat.catat

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import java.text.NumberFormat
import java.util.Locale
import java.util.UUID

/// Catat otomatis: notifikasi bank/e-wallet/SMS/email disaring kasar di sini,
/// lalu dicatat di belakang layar oleh Dart (BackgroundRecorder →
/// lib/background.dart). Kalau mesinnya error: antrean + notif "Ketuk buat catat".
object AutoCapture {
    const val ACTION_CAPTURE = "id.catat.catat.CAPTURE"
    const val ACTION_REMINDER = "id.catat.catat.REMINDER"
    const val EXTRA_CAPTURE_ID = "captureId"
    const val ACTION_OPEN = "id.catat.catat.OPEN"
    const val EXTRA_ROUTE = "route"
    const val EXTRA_RECORD_ID = "recordId"
    const val EXTRA_INCOME = "income"
    const val EXTRA_NOTIF_ID = "notifId"

    const val CHANNEL_CAPTURE = "transaksi"
    const val CHANNEL_REMINDER = "pengingat"

    private const val PREFS = "catat_auto"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_QUEUE = "queue"
    private const val KEY_SEEN = "seen"
    private const val KEY_MATCHED = "matched"
    private const val MATCHED_KEEP_MS = 4L * 24 * 60 * 60 * 1000
    private const val MAX_QUEUE = 20
    private const val MAX_AGE_MS = 3L * 24 * 60 * 60 * 1000
    private const val DEDUP_MS = 2L * 60 * 1000
    private const val TAG = "catat.auto"

    /// Sama dengan financeApps di Dart.
    val APPS = mapOf(
        "com.gojek.app" to "GoPay",
        "com.gojek.gopay" to "GoPay",
        "id.dana" to "DANA",
        "ovo.id" to "OVO",
        "com.shopee.id" to "ShopeePay",
        "com.bca" to "BCA",
        "com.bca.mybca.omni.android" to "myBCA",
        "id.bmri.livin" to "Livin'",
        "id.co.bri.brimo" to "BRImo",
        "id.bni.wondr" to "BNI",
        "src.com.bni" to "BNI",
        "com.bsm.activity2" to "BSI",
        "com.jago.digitalBanking" to "Jago",
        "id.co.bankbkemobile.digitalbank" to "SeaBank",
        "com.bcadigital.blu" to "blu",
        "com.btpn.dc" to "Jenius",
        "com.telkom.mwallet" to "LinkAja",
    )

    /// Aplikasi Pesan/SMS (+ aplikasi SMS default HP, lihat [sourceOf]).
    private val SMS_APPS = setOf(
        "com.google.android.apps.messaging",
        "com.android.mms",
        "com.samsung.android.messaging",
    )

    private val EMAIL_APPS = setOf(
        "com.google.android.gm",
        "com.microsoft.office.outlook",
        "com.yahoo.mobile.client.android.mail",
    )

    /// Nama bank / e-wallet di SMS & email (sama dengan _bankNames di Dart).
    private val BANKS = listOf(
        "brimo|bank rakyat|\\bbri\\b" to "BRI",
        "\\bbca\\b|mybca|klikbca" to "BCA",
        "wondr|\\bbni\\b" to "BNI",
        "livin'?|mandiri" to "Mandiri",
        "\\bbsi\\b|bank syariah indonesia" to "BSI",
        "\\bbtn\\b" to "BTN",
        "cimb|octo" to "CIMB Niaga",
        "permata" to "Permata",
        "danamon" to "Danamon",
        "\\bocbc\\b" to "OCBC",
        "maybank" to "Maybank",
        "\\bbjb\\b" to "bjb",
        "\\bjago\\b" to "Jago",
        "seabank" to "SeaBank",
        "jenius|\\bbtpn\\b" to "Jenius",
        "\\bblu\\b" to "blu",
        "gopay" to "GoPay",
        "\\bovo\\b" to "OVO",
        "shopeepay" to "ShopeePay",
        "linkaja" to "LinkAja",
    ).map { (p, name) -> Regex(p, RegexOption.IGNORE_CASE) to name } +
        // "dana" juga kata biasa ("dana instan") → hanya huruf kapital.
        (Regex("\\bDANA\\b") to "DANA")

    private fun bankIn(text: String): String? =
        BANKS.firstOrNull { it.first.containsMatchIn(text) }?.second

    /// "financeApp" / "sms" / "email", atau null = jangan dibaca (termasuk
    /// semua aplikasi chat seperti WhatsApp).
    fun sourceOf(context: Context, pkg: String): String? = when {
        APPS.containsKey(pkg) -> "financeApp"
        pkg in EMAIL_APPS -> "email"
        pkg in SMS_APPS ||
            pkg == android.provider.Telephony.Sms.getDefaultSmsPackage(context) -> "sms"
        // Uji di HP: `adb shell cmd notification post` dianggap SMS (debug saja).
        pkg == "com.android.shell" &&
            context.applicationInfo.flags and
            android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE != 0 -> "sms"
        else -> null
    }

    private val skipRe = Regex(
        "\\b(otp|kode (verifikasi|otp|rahasia|aktivasi)|verification code|" +
            "jangan (berikan|bagikan)|promo|diskon|voucher|hemat|gratis|undian|" +
            "top ?up|topup|isi saldo|gagal|dibatalkan|batal|tertunda|pending|" +
            "ditolak|kedaluwarsa|expired|jatuh tempo|pinjaman)\\b",
        RegexOption.IGNORE_CASE,
    )
    private val inRe = Regex(
        "\\b(masuk|menerima|diterima|terima|dapet|kredit|credit|refund|" +
            "pengembalian dana|received|incoming)\\b",
        RegexOption.IGNORE_CASE,
    )
    // "Rp50.000", "IDR43.000,00." (titik akhir kalimat tidak ikut), "Rp1,2jt".
    private val rpRe = Regex(
        "(Rp|IDR)\\.?\\s*(\\d[\\d.,]*\\d|\\d)\\s*(rb|ribu|k|jt|juta)?\\b",
        RegexOption.IGNORE_CASE,
    )
    private val balanceRe = Regex(
        "(saldo( akhir| efektif)?|sisa( saldo)?|limit|balance)\\W*$",
        RegexOption.IGNORE_CASE,
    )

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /// Sumber catat otomatis yang bisa dipilih user (layar Privasi & Izin).
    val SOURCES = listOf("financeApp", "sms", "email")

    /// Sumber dinyalakan user? Versi lama cuma punya satu saklar "enabled".
    fun isSourceOn(context: Context, source: String): Boolean =
        prefs(context).getBoolean("src_$source", prefs(context).getBoolean(KEY_ENABLED, false))

    fun setSource(context: Context, source: String, on: Boolean) {
        val p = prefs(context)
        val edit = p.edit()
        // Pindah dari saklar lama: tulis semua sumber dulu sebelum mengubah satu.
        for (s in SOURCES) if (!p.contains("src_$s")) edit.putBoolean("src_$s", isSourceOn(context, s))
        edit.putBoolean("src_$source", on)
        edit.apply()
        val any = SOURCES.any { if (it == source) on else isSourceOn(context, it) }
        p.edit().putBoolean(KEY_ENABLED, any).apply()
        if (!any) p.edit().remove(KEY_QUEUE).apply()
    }

    /// Ada sumber yang menyala.
    fun isEnabled(context: Context) = SOURCES.any { isSourceOn(context, it) }

    fun hasListenerAccess(context: Context): Boolean {
        val flat = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        val me = ComponentName(context, CatatNotificationListener::class.java)
        return flat.split(":").any { ComponentName.unflattenFromString(it) == me }
    }

    fun canPostNotifications(context: Context): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED

    fun createChannels(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_CAPTURE,
                "Transaksi terdeteksi",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply { description = "Catatan otomatis dari notifikasi bank, SMS & email" },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_REMINDER,
                "Pengingat harian",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply { description = "Pengingat kalau hari ini belum catat" },
        )
    }

    /// Nominal transaksi pertama (lewati nominal saldo).
    fun amountIn(text: String): Long? {
        for (m in rpRe.findAll(text)) {
            if (balanceRe.containsMatchIn(text.substring(0, m.range.first))) continue
            val raw = m.groupValues[2]
            val unit = m.groupValues[3].lowercase()
            val v = if (unit.isNotEmpty()) {
                val value = raw.replace(',', '.').toDoubleOrNull() ?: continue
                val factor = if (unit == "jt" || unit == "juta") 1_000_000 else 1_000
                Math.round(value * factor)
            } else {
                raw.replace(Regex("[.,]\\d{2}$"), "")
                    .replace(Regex("[.,]"), "")
                    .toLongOrNull() ?: continue
            }
            if (v > 0) return v
        }
        return null
    }

    /// Dipanggil listener untuk setiap notifikasi dari aplikasi keuangan.
    fun onFinanceNotification(
        context: Context,
        pkg: String,
        source: String,
        title: String,
        text: String,
        postedAt: Long,
    ) {
        // Sumber ini dimatikan user (mis. SMS mati, m-banking nyala).
        if (!isSourceOn(context, source)) return
        val all = "$title. $text"
        // SMS & email: hanya yang menyebut bank / e-wallet (pengirim dulu).
        // Saringan kasar; keputusan akhir (iklan, arah, dll.) di Dart.
        val app = if (source == "financeApp") {
            APPS[pkg] ?: return
        } else {
            bankIn(title) ?: bankIn(text) ?: return
        }
        if (skipRe.containsMatchIn(all)) return
        val amount = amountIn(all) ?: return
        createChannels(context)

        if (seenRecently(context, pkg, amount, postedAt)) {
            Log.i(TAG, "Notif dobel, dilewati")
            return
        }
        Log.i(TAG, "Transaksi terdeteksi dari $source")

        // Langsung dicatat di belakang layar. Kalau tidak bisa (ambigu, belum
        // setup, error) → simpan ke antrean & tawarkan catat manual.
        val capture = mapOf<String, Any>(
            "matched" to matchedIds(context),
            "pkg" to pkg,
            "source" to source,
            "title" to title,
            "text" to text,
            "postedAt" to postedAt,
        )
        BackgroundRecorder.record(context, capture) {
            val id = enqueue(context, capture, amount)
            postOffer(context, id, app, amount, inRe.containsMatchIn(all))
        }
    }

    /// Notifikasi yang di-update / dikirim dobel (paket + nominal, 2 menit).
    private fun seenRecently(context: Context, pkg: String, amount: Long, postedAt: Long): Boolean {
        val seen = try {
            JSONArray(prefs(context).getString(KEY_SEEN, "[]"))
        } catch (e: Exception) {
            JSONArray()
        }
        val kept = JSONArray()
        var dup = false
        for (i in 0 until seen.length()) {
            val o = seen.getJSONObject(i)
            val close = kotlin.math.abs(o.getLong("postedAt") - postedAt) < DEDUP_MS
            if (close) kept.put(o)
            if (close && o.getString("pkg") == pkg && o.getLong("amount") == amount) dup = true
        }
        if (!dup) {
            kept.put(JSONObject().put("pkg", pkg).put("amount", amount).put("postedAt", postedAt))
        }
        prefs(context).edit().putString(KEY_SEEN, kept.toString()).apply()
        return dup
    }

    /// Catatan user (manual / scan / gajian) yang sudah dipasangkan dengan
    /// notifikasi: satu catatan hanya menyerap satu notifikasi.
    private fun matchedList(context: Context): JSONArray {
        val all = try {
            JSONArray(prefs(context).getString(KEY_MATCHED, "[]"))
        } catch (e: Exception) {
            JSONArray()
        }
        val now = System.currentTimeMillis()
        val kept = JSONArray()
        for (i in 0 until all.length()) {
            val o = all.getJSONObject(i)
            if (now - o.getLong("at") < MATCHED_KEEP_MS) kept.put(o)
        }
        return kept
    }

    private fun matchedIds(context: Context): List<String> {
        val list = matchedList(context)
        return (0 until list.length()).map { list.getJSONObject(it).getString("id") }
    }

    fun addMatched(context: Context, id: String) {
        val list = matchedList(context)
        list.put(JSONObject().put("id", id).put("at", System.currentTimeMillis()))
        prefs(context).edit().putString(KEY_MATCHED, list.toString()).apply()
    }

    private fun enqueue(context: Context, capture: Map<String, Any>, amount: Long): String {
        val id = UUID.randomUUID().toString()
        val item = JSONObject(capture).put("id", id).put("amount", amount)
        val now = System.currentTimeMillis()
        val kept = JSONArray()
        val queue = readQueue(context)
        for (i in 0 until queue.length()) {
            val o = queue.getJSONObject(i)
            if (now - o.getLong("postedAt") < MAX_AGE_MS) kept.put(o)
        }
        kept.put(item)
        while (kept.length() > MAX_QUEUE) kept.remove(0)
        writeQueue(context, kept)
        return id
    }

    /// Notif "Tercatat …" + tombol Batalkan (di belakang layar) & Ubah.
    fun postRecorded(context: Context, record: Map<String, Any?>) {
        if (!canPostNotifications(context)) return
        val id = record["id"] as? String ?: return
        val income = record["income"] == true
        val amount = (record["amount"] as? Number)?.toLong() ?: return
        val title = record["title"] as? String ?: ""
        val pocket = record["pocketName"] as? String
        val notifId = id.hashCode()

        val route = if (income) "/pemasukan-masuk/$id" else "/transaksi/$id"
        val open = PendingIntent.getActivity(
            context,
            notifId,
            Intent(context, MainActivity::class.java).apply {
                action = ACTION_OPEN
                putExtra(EXTRA_ROUTE, route)
                putExtra(EXTRA_NOTIF_ID, notifId)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val undo = PendingIntent.getBroadcast(
            context,
            notifId,
            Intent(context, UndoRecordReceiver::class.java).apply {
                putExtra(EXTRA_RECORD_ID, id)
                putExtra(EXTRA_INCOME, income)
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val heading = if (income) {
            "Pemasukan ${rupiah(amount)} tercatat"
        } else {
            "Tercatat ${rupiah(amount)}"
        }
        val body = if (income) {
            "$title · udah dibagi ke kantong"
        } else {
            listOfNotNull(title, pocket).joinToString(" · ")
        }
        val notification = NotificationCompat.Builder(context, CHANNEL_CAPTURE)
            .setSmallIcon(R.drawable.ic_stat_catat)
            .setContentTitle(heading)
            .setContentText(body)
            .setContentIntent(open)
            .setAutoCancel(true)
            .addAction(0, "Batalkan", undo)
            .addAction(0, "Ubah", open)
            .build()
        NotificationManagerCompat.from(context).notify(notifId, notification)
    }

    /// Setelah "Batalkan": ganti notif jadi konfirmasi singkat.
    fun postUndone(context: Context, id: String, ok: Boolean) {
        if (!canPostNotifications(context)) return
        val notification = NotificationCompat.Builder(context, CHANNEL_CAPTURE)
            .setSmallIcon(R.drawable.ic_stat_catat)
            .setContentTitle(if (ok) "Dibatalkan" else "Gagal membatalkan")
            .setContentText(if (ok) "Catatan tadi udah dihapus." else "Buka catat. buat hapus manual.")
            .setAutoCancel(true)
            .setTimeoutAfter(4_000)
            .build()
        NotificationManagerCompat.from(context).notify(id.hashCode(), notification)
    }

    private fun rupiah(amount: Long): String =
        "Rp " + NumberFormat.getInstance(Locale.forLanguageTag("id-ID")).format(amount)

    private fun postOffer(context: Context, id: String, app: String, amount: Long, incoming: Boolean) {
        if (!canPostNotifications(context)) return
        val intent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_CAPTURE
            putExtra(EXTRA_CAPTURE_ID, id)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pending = PendingIntent.getActivity(
            context,
            id.hashCode(),
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val title = if (incoming) "Ada uang masuk ${rupiah(amount)}" else "Barusan keluar ${rupiah(amount)}"
        val body = if (incoming) {
            "Dari $app. Ketuk buat catat sebagai pemasukan."
        } else {
            "Dari $app. Ketuk buat catat ke kantong."
        }
        val notification = NotificationCompat.Builder(context, CHANNEL_CAPTURE)
            .setSmallIcon(R.drawable.ic_stat_catat)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(pending)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .build()
        NotificationManagerCompat.from(context).notify(id.hashCode(), notification)
    }

    /// Ambil satu tangkapan (dan hapus dari antrean + tutup notifnya).
    fun take(context: Context, id: String): Map<String, Any>? {
        val queue = readQueue(context)
        val rest = JSONArray()
        var found: JSONObject? = null
        for (i in 0 until queue.length()) {
            val o = queue.getJSONObject(i)
            if (o.getString("id") == id) found = o else rest.put(o)
        }
        writeQueue(context, rest)
        NotificationManagerCompat.from(context).cancel(id.hashCode())
        val o = found ?: return null
        return mapOf(
            "pkg" to o.getString("pkg"),
            "source" to o.optString("source", "financeApp"),
            "title" to o.getString("title"),
            "text" to o.getString("text"),
            "postedAt" to o.getLong("postedAt"),
        )
    }

    private fun readQueue(context: Context): JSONArray =
        try {
            JSONArray(prefs(context).getString(KEY_QUEUE, "[]"))
        } catch (e: Exception) {
            JSONArray()
        }

    private fun writeQueue(context: Context, queue: JSONArray) {
        prefs(context).edit().putString(KEY_QUEUE, queue.toString()).apply()
    }
}
