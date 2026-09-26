package id.catat.catat

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import java.io.File
import java.io.IOException

/// Slip gaji dari pemilih file Android (F6): foto disalin, PDF dirender
/// halaman pertamanya jadi PNG supaya bisa dibaca OCR yang sama dengan struk.
/// Juga dipakai gambar yang dibagikan ke catat.
object SlipFile {
    /// Lebar render PDF: cukup tajam untuk OCR, tetap ringan di memori.
    private const val PDF_WIDTH = 1600

    /// Halaman sangat panjang (mis. PDF iseng 1×1000) dipotong: bitmap
    /// raksasa bikin app crash kehabisan memori.
    private const val PDF_MAX_HEIGHT = PDF_WIDTH * 3

    /// Foto struk/slip wajar jauh di bawah ini. File lebih besar ditolak
    /// (memenuhi penyimpanan / crash saat didekode OCR).
    private const val MAX_BYTES = 20L * 1024 * 1024

    /// Salinan di cache berisi dokumen pribadi (slip gaji) → dibuang.
    private val PREFIXES = listOf("slip_", "bagikan_")
    private const val KEEP_MS = 60L * 60 * 1000

    fun pickIntent(): Intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
        .addCategory(Intent.CATEGORY_OPENABLE)
        .setType("*/*")
        .putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "application/pdf"))

    /// Salin isi [uri] ke [target], maksimal [MAX_BYTES].
    fun copyLimited(context: Context, uri: Uri, target: File) {
        try {
            context.contentResolver.openInputStream(uri)!!.use { input ->
                target.outputStream().use { out ->
                    val buffer = ByteArray(64 * 1024)
                    var total = 0L
                    while (true) {
                        val n = input.read(buffer)
                        if (n < 0) break
                        total += n
                        if (total > MAX_BYTES) throw IOException("File terlalu besar")
                        out.write(buffer, 0, n)
                    }
                }
            }
        } catch (e: Exception) {
            target.delete()
            throw e
        }
    }

    /// Salin / render ke cache, hasilnya path gambar.
    fun toImage(context: Context, uri: Uri): String {
        val isPdf = context.contentResolver.getType(uri) == "application/pdf"
        val stamp = System.currentTimeMillis()
        if (!isPdf) {
            val target = File(context.cacheDir, "slip_$stamp.jpg")
            copyLimited(context, uri, target)
            return target.path
        }
        // PdfRenderer butuh file yang bisa di-seek → salin dulu.
        val pdf = File(context.cacheDir, "slip_$stamp.pdf")
        copyLimited(context, uri, pdf)
        try {
            ParcelFileDescriptor.open(pdf, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
                PdfRenderer(fd).use { renderer ->
                    renderer.openPage(0).use { page ->
                        val height = (PDF_WIDTH.toLong() * page.height / page.width.coerceAtLeast(1))
                            .coerceIn(1L, PDF_MAX_HEIGHT.toLong()).toInt()
                        val bitmap = Bitmap.createBitmap(PDF_WIDTH, height, Bitmap.Config.ARGB_8888)
                        // PDF transparan → latar putih biar teks kebaca.
                        bitmap.eraseColor(Color.WHITE)
                        // Skala dari lebar saja: halaman kepanjangan terpotong di bawah.
                        val scale = PDF_WIDTH.toFloat() / page.width.coerceAtLeast(1)
                        val matrix = android.graphics.Matrix().apply { setScale(scale, scale) }
                        page.render(bitmap, null, matrix, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
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

    /// Buang salinan slip / gambar bagikan yang lebih tua dari 1 jam.
    fun cleanCache(context: Context) {
        val cutoff = System.currentTimeMillis() - KEEP_MS
        context.cacheDir.listFiles()?.forEach { f ->
            if (PREFIXES.any { f.name.startsWith(it) } && f.lastModified() < cutoff) f.delete()
        }
    }
}
