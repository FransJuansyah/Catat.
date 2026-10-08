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
import java.text.NumberFormat
import java.util.Calendar
import java.util.Locale

/// Pengingat tagihan & cicilan (layar 71): tiap pagi jam 09:00 cek tabel
/// `bills` di DB drift; tagihan yang jatuh tempo besok / hari ini diberi
/// notif dengan aksi "Udah bayar" (buka app) & "Ingetin nanti" (3 jam lagi).
/// Logika jatuh tempo sama dengan lib/domain/bills.dart.
object BillReminder {
    const val ACTION_PAY = "id.catat.catat.BILL_PAY"
    const val ACTION_SNOOZE = "id.catat.catat.BILL_SNOOZE"
    const val ACTION_CHECK = "id.catat.catat.BILL_CHECK"
    const val EXTRA_ID = "billId"
    private const val HOUR = 9
    private const val SNOOZE_MS = 3L * 60 * 60 * 1000
    private const val WINDOW_MS = 15L * 60 * 1000
    private const val REQUEST_DAILY = 2200

    private data class Due(val id: String, val name: String, val amount: Long, val days: Int, val dueDate: Calendar)

    private fun dailyIntent(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            REQUEST_DAILY,
            Intent(context, BillReminderReceiver::class.java).setAction(ACTION_CHECK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

    /// Jadwalkan cek harian jam 09:00 (tidak eksak, seperti pengingat harian).
    fun schedule(context: Context) {
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, HOUR)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        context.getSystemService(AlarmManager::class.java)
            .setWindow(AlarmManager.RTC_WAKEUP, next.timeInMillis, WINDOW_MS, dailyIntent(context))
    }

    fun snooze(context: Context, billId: String) {
        NotificationManagerCompat.from(context).cancel(notificationId(billId))
        val pending = PendingIntent.getBroadcast(
            context,
            notificationId(billId),
            Intent(context, BillReminderReceiver::class.java)
                .setAction(ACTION_CHECK)
                .putExtra(EXTRA_ID, billId),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        context.getSystemService(AlarmManager::class.java).setWindow(
            AlarmManager.RTC_WAKEUP,
            System.currentTimeMillis() + SNOOZE_MS,
            WINDOW_MS,
            pending,
        )
    }

    /// Cek & kirim notif. [onlyId] = hasil "Ingetin nanti" untuk satu tagihan.
    fun check(context: Context, onlyId: String?) {
        if (onlyId == null) schedule(context)
        if (!AppNotifications.canPost(context)) return
        for (due in dueBills(context)) {
            if (onlyId != null && due.id != onlyId) continue
            // Cek harian: besok & hari ini. Ditunda: selama belum dibayar.
            if (onlyId == null && due.days !in 0..1) continue
            if (onlyId != null && due.days > 1) continue
            notify(context, due)
        }
    }

    fun notificationId(billId: String) = 3000 + (billId.hashCode() and 0x3FF)

    private fun notify(context: Context, due: Due) {
        val rupiah = "Rp " + NumberFormat.getIntegerInstance(Locale("id", "ID")).format(due.amount)
        val months = arrayOf("Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agu", "Sep", "Okt", "Nov", "Des")
        val date = "${due.dueDate.get(Calendar.DAY_OF_MONTH)} ${months[due.dueDate.get(Calendar.MONTH)]}"
        val title = when {
            due.days < 0 -> "${due.name} telat dibayar"
            due.days == 0 -> "Hari ini bayar ${due.name}"
            else -> "Besok bayar ${due.name}"
        }
        val id = notificationId(due.id)
        val pay = PendingIntent.getActivity(
            context,
            id,
            Intent(context, MainActivity::class.java).apply {
                action = ACTION_PAY
                putExtra(EXTRA_ID, due.id)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val later = PendingIntent.getBroadcast(
            context,
            id + 1,
            Intent(context, BillReminderReceiver::class.java)
                .setAction(ACTION_SNOOZE)
                .putExtra(EXTRA_ID, due.id),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = NotificationCompat.Builder(context, AppNotifications.CHANNEL_BILLS)
            .setSmallIcon(R.drawable.ic_stat_catat)
            .setContentTitle(title)
            .setContentText("$rupiah jatuh tempo $date.")
            .setContentIntent(pay)
            .addAction(0, "Udah bayar", pay)
            .addAction(0, "Ingetin nanti", later)
            .setAutoCancel(true)
            .build()
        NotificationManagerCompat.from(context).notify(id, notification)
    }

    /// Tagihan aktif yang belum lunas, dengan sisa hari ke jatuh tempo.
    private fun dueBills(context: Context): List<Due> {
        val file = File(context.filesDir.parentFile, "app_flutter/catat.sqlite")
        if (!file.exists()) return emptyList()
        val today = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        return try {
            SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                db.rawQuery(
                    "SELECT id, name, amount, due_day, kind, remaining, start_month, paid_through " +
                        "FROM bills WHERE deleted_at IS NULL AND remind = 1",
                    null,
                ).use { c ->
                    buildList {
                        while (c.moveToNext()) {
                            val kind = c.getString(4)
                            val remaining = if (c.isNull(5)) null else c.getInt(5)
                            if (kind == "cicilan" && (remaining ?: 0) <= 0) continue
                            val next = maxOf(c.getInt(7) + 1, c.getInt(6))
                            val due = Calendar.getInstance().apply {
                                clear()
                                set(next / 12, next % 12, 1)
                                set(Calendar.DAY_OF_MONTH, minOf(c.getInt(3), getActualMaximum(Calendar.DAY_OF_MONTH)))
                            }
                            val days = ((due.timeInMillis - today.timeInMillis) / 86_400_000L).toInt()
                            add(Due(c.getString(0), c.getString(1), c.getLong(2), days, due))
                        }
                    }
                }
            }
        } catch (e: Exception) {
            emptyList() // tabel belum ada (belum update) / DB terkunci
        }
    }
}

class BillReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            BillReminder.ACTION_SNOOZE ->
                intent.getStringExtra(BillReminder.EXTRA_ID)?.let { BillReminder.snooze(context, it) }
            else -> BillReminder.check(context, intent.getStringExtra(BillReminder.EXTRA_ID))
        }
    }
}
