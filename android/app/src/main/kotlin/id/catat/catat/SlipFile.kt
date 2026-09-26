package id.catat.catat

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import java.io.File

/// Slip gaji dari pemilih file Android (F6): foto disalin, PDF dirender
/// halaman pertamanya jadi PNG supaya bisa dibaca OCR yang sama dengan struk.
object SlipFile {
    /// Lebar render PDF: cukup tajam untuk OCR, tetap ringan di memori.
    private const val PDF_WIDTH = 1600

    fun pickIntent(): Intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
        .addCategory(Intent.CATEGORY_OPENABLE)
        .setType("*/*")
        .putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "application/pdf"))

    /// Salin / render ke cache, hasilnya path gambar.
    fun toImage(context: Context, uri: Uri): String {
        val isPdf = context.contentResolver.getType(uri) == "application/pdf"
        val stamp = System.currentTimeMillis()
        if (!isPdf) {
            val target = File(context.cacheDir, "slip_$stamp.jpg")
            context.contentResolver.openInputStream(uri)!!.use { input ->
                target.outputStream().use { input.copyTo(it) }
            }
            return target.path
        }
        // PdfRenderer butuh file yang bisa di-seek → salin dulu.
        val pdf = File(context.cacheDir, "slip_$stamp.pdf")
        context.contentResolver.openInputStream(uri)!!.use { input ->
            pdf.outputStream().use { input.copyTo(it) }
        }
        try {
            ParcelFileDescriptor.open(pdf, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
                PdfRenderer(fd).use { renderer ->
                    renderer.openPage(0).use { page ->
                        val height = PDF_WIDTH * page.height / page.width
                        val bitmap = Bitmap.createBitmap(PDF_WIDTH, height, Bitmap.Config.ARGB_8888)
                        // PDF transparan → latar putih biar teks kebaca.
                        bitmap.eraseColor(Color.WHITE)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        val target = File(context.cacheDir, "slip_$stamp.png")
                        target.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
                        bitmap.recycle()
                        return target.path
                    }
                }
            }
        } finally {
            pdf.delete()
        }
    }
}
