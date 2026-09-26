package id.catat.catat

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/// Baca notifikasi HANYA dari m-banking/e-wallet (AutoCapture.APPS), aplikasi
/// Pesan/SMS & email. Aplikasi lain (termasuk chat seperti WhatsApp)
/// diabaikan tanpa dibaca isinya. Semua diproses di HP.
class CatatNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val pkg = sbn.packageName
        val source = AutoCapture.sourceOf(applicationContext, pkg) ?: return
        val n = sbn.notification ?: return
        // Ringkasan grup tidak berisi transaksi.
        if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        val extras = n.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = (
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_TEXT)
            )?.toString().orEmpty()
        if (title.isBlank() && text.isBlank()) return
        AutoCapture.onFinanceNotification(
            applicationContext,
            pkg,
            source,
            title,
            text,
            sbn.postTime,
        )
    }
}
