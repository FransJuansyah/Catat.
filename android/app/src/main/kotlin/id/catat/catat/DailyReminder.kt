package id.catat.catat

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.io.File
import java.util.Calendar

/// Pengingat jam 21:00, hanya kalau hari itu belum ada catatan.
/// Pakai alarm tidak-eksak (tanpa izin exact alarm), jadi bisa telat beberapa
/// menit. Dijadwal ulang tiap berbunyi & setelah HP restart.
object DailyReminder {
    const val HOUR = 21
    private const val WINDOW_MS = 15L * 60 * 1000
    private const val NOTIFICATION_ID = 2100
    private const val PREFS = "catat_auto"
    private const val KEY_ON = "reminder"

    fun isOn(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ON, false)

    fun set(context: Context, on: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putBoolean(KEY_ON, on).apply()
        if (on) schedule(context) else cancel(context)
    }

    private fun pending(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            NOTIFICATION_ID,
            Intent(context, DailyReminderReceiver::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

    fun schedule(context: Context) {
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, HOUR)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        val alarms = context.getSystemService(AlarmManager::class.java)
        alarms.setWindow(AlarmManager.RTC_WAKEUP, next.timeInMillis, WINDOW_MS, pending(context))
    }

    private fun cancel(context: Context) {
        context.getSystemService(AlarmManager::class.java).cancel(pending(context))
    }

    /// Ada pengeluaran/pemasukan hari ini? Baca DB drift langsung (read-only).
    /// Kalau DB tidak bisa dibaca, anggap belum (lebih baik mengingatkan).
    fun hasEntryToday(context: Context): Boolean {
        val file = File(context.filesDir.parentFile, "app_flutter/catat.sqlite")
        if (!file.exists()) return false
        val start = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis / 1000 // drift: detik Unix
        return try {
            SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                fun count(table: String): Long = db.rawQuery(
                    "SELECT COUNT(*) FROM $table WHERE deleted_at IS NULL AND occurred_at >= ?",
                    arrayOf(start.toString()),
                ).use { c -> if (c.moveToFirst()) c.getLong(0) else 0 }
                count("expenses") + count("incomes") > 0
            }
        } catch (e: Exception) {
            false
        }
    }

    fun fire(context: Context) {
        if (!isOn(context)) return
        schedule(context)
        if (hasEntryToday(context) || !AutoCapture.canPostNotifications(context)) return
        val open = PendingIntent.getActivity(
            context,
            NOTIFICATION_ID,
            Intent(context, MainActivity::class.java).apply {
                action = AutoCapture.ACTION_REMINDER
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = NotificationCompat.Builder(context, AutoCapture.CHANNEL_REMINDER)
            .setSmallIcon(R.drawable.ic_stat_catat)
            .setContentTitle("Hari ini belum ada catatan")
            .setContentText("Tadi jajan apa? Catat sebentar, biar kantong tetap aman.")
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
    }
}

class DailyReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED ->
                if (DailyReminder.isOn(context)) DailyReminder.schedule(context)
            else -> DailyReminder.fire(context)
        }
    }
}
