package id.catat.catat

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat

/// Notifikasi catat.: pengingat harian ([DailyReminder]) & tagihan ([BillReminder]).
/// Catat otomatis dari notifikasi bank/SMS/email dihapus 5 Okt 2026.
object AppNotifications {
    const val ACTION_REMINDER = "id.catat.catat.REMINDER"
    const val CHANNEL_REMINDER = "pengingat"
    const val CHANNEL_BILLS = "tagihan"

    /// Saluran & pengaturan peninggalan catat otomatis.
    private const val LEGACY_CHANNEL = "transaksi"
    private const val PREFS = "catat_auto"
    private const val KEEP_KEY = "reminder"

    fun canPost(context: Context): Boolean =
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
                CHANNEL_REMINDER,
                "Pengingat harian",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply { description = "Pengingat kalau hari ini belum catat" },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_BILLS,
                "Pengingat tagihan",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = "Cicilan & tagihan yang jatuh tempo besok" },
        )
        manager.deleteNotificationChannel(LEGACY_CHANNEL)
    }

    /// Buang antrean & sakelar catat otomatis lama; pilihan pengingat tetap.
    fun cleanupLegacy(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val stale = prefs.all.keys.filter { it != KEEP_KEY }
        if (stale.isEmpty()) return
        prefs.edit().apply { stale.forEach { remove(it) } }.apply()
    }
}
