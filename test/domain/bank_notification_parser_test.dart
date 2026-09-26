import 'package:catat/domain/bank_notification_parser.dart';
import 'package:catat/domain/types.dart';
import 'package:flutter_test/flutter_test.dart';

/// F6.5: baca notifikasi bank & e-wallet. Contoh mengikuti pola notifikasi
/// umum tiap aplikasi (nama & nominal samaran).
void main() {
  final now = DateTime(2026, 9, 26, 12, 30);

  DetectedTransaction? parse(String pkg, String title, String text) =>
      parseBankNotification(
        packageName: pkg,
        title: title,
        text: text,
        postedAt: now,
      );

  group('uang keluar', () {
    test('GoPay bayar ke toko', () {
      final t = parse(
        'com.gojek.app',
        'Pembayaran berhasil',
        'Rp25.000 berhasil dibayar ke Kopi Kenangan pakai GoPay.',
      )!;
      expect(t.direction, MoneyDirection.out);
      expect(t.amount, 25000);
      expect(t.counterparty, 'Kopi Kenangan');
      expect(t.appName, 'GoPay');
      expect(t.occurredAt, now);
      expect(t.pocketGuess, PocketType.keinginan);
    });

    test('DANA bayar merchant', () {
      final t = parse(
        'id.dana',
        'Transaksi Berhasil',
        'Kamu berhasil bayar Rp 52.000 ke INDOMARET PASAR MINGGU.',
      )!;
      expect(t.direction, MoneyDirection.out);
      expect(t.amount, 52000);
      expect(t.counterparty, 'Indomaret Pasar Minggu');
      expect(t.pocketGuess, PocketType.wajib);
    });

    test('BNI transfer keluar, lewati nominal saldo', () {
      final t = parse(
        'id.bni.wondr',
        'Transaksi Keluar',
        'Transfer Rp 150.000,00 ke BUDI SANTOSO berhasil. Saldo Rp 1.250.000',
      )!;
      expect(t.direction, MoneyDirection.out);
      expect(t.amount, 150000);
      expect(t.counterparty, 'Budi Santoso');
    });

    test('saldo disebut duluan tetap ambil nominal transaksi', () {
      final t = parse(
        'com.jago.digitalBanking',
        'Uang keluar',
        'Saldo Rp 800.000. Kamu bayar Rp 45.000 di Warung Makan Sederhana',
      )!;
      expect(t.amount, 45000);
      expect(t.counterparty, 'Warung Makan Sederhana');
    });

    test('OVO format IDR', () {
      final t = parse(
        'ovo.id',
        'Payment successful',
        'Payment of IDR 30,000 to Solaria was successful',
      )!;
      expect(t.direction, MoneyDirection.out);
      expect(t.amount, 30000);
      expect(t.counterparty, 'Solaria');
    });

    test('tanpa nama toko: judul pakai nama aplikasi', () {
      final t = parse(
        'id.co.bankbkemobile.digitalbank',
        'Pembayaran QRIS',
        'Pembayaran QRIS Rp18.000 berhasil',
      )!;
      expect(t.counterparty, isNull);
      expect(t.title, 'SeaBank');
    });
  });

  group('uang masuk', () {
    test('transfer masuk dari orang', () {
      final t = parse(
        'id.bni.wondr',
        'Dana Masuk',
        'Kamu menerima Rp 250.000 dari ANDI PRATAMA.',
      )!;
      expect(t.direction, MoneyDirection.into);
      expect(t.amount, 250000);
      expect(t.counterparty, 'Andi Pratama');
    });

    test('GoPay dapet transfer', () {
      final t = parse(
        'com.gojek.app',
        'Kamu dapet transfer!',
        'Rp50.000 masuk dari Sinta ke GoPay kamu.',
      )!;
      expect(t.direction, MoneyDirection.into);
      expect(t.counterparty, 'Sinta');
    });

    test('refund dihitung masuk', () {
      final t = parse(
        'id.dana',
        'Refund',
        'Pengembalian dana Rp 20.000 dari Tokopedia sudah masuk',
      )!;
      expect(t.direction, MoneyDirection.into);
      expect(t.amount, 20000);
    });
  });

  group('SMS & email bank', () {
    DetectedTransaction? via(
      NotificationSource source,
      String pkg,
      String title,
      String text,
    ) => parseBankNotification(
      packageName: pkg,
      title: title,
      text: text,
      postedAt: now,
      source: source,
    );

    test('SMS debit BCA', () {
      final t = via(
        NotificationSource.sms,
        'com.google.android.apps.messaging',
        'BCA',
        'Transaksi Debit Rp 75.000 di ALFAMART CILANDAK tgl 26/09. '
            'Saldo Rp 1.200.000',
      )!;
      expect(t.appName, 'BCA');
      expect(t.direction, MoneyDirection.out);
      expect(t.amount, 75000);
      expect(t.counterparty, 'Alfamart Cilandak');
    });

    test('SMS kredit BRI dari nomor pendek, nama bank di isi', () {
      final t = via(
        NotificationSource.sms,
        'com.google.android.apps.messaging',
        '3300',
        'BRI: Dana masuk Rp 500.000 dari PT MAJU JAYA ke rek 1234xxx',
      )!;
      expect(t.appName, 'BRI');
      expect(t.direction, MoneyDirection.into);
      expect(t.counterparty, 'Pt Maju Jaya');
    });

    test('email transaksi Mandiri', () {
      final t = via(
        NotificationSource.email,
        'com.google.android.gm',
        "Livin' by Mandiri",
        'Notifikasi Transaksi: Pembayaran Rp 120.000 ke Tokopedia berhasil',
      )!;
      expect(t.appName, 'Mandiri');
      expect(t.direction, MoneyDirection.out);
      expect(t.counterparty, 'Tokopedia');
    });

    // Pola SMS BNI asli (rekening, referensi & nama disamarkan).
    test('SMS BNI dana keluar, lewati saldo akhir', () {
      final t = via(
        NotificationSource.sms,
        'com.google.android.apps.messaging',
        'BNI',
        '18/06/2025 07:39 Pada No. Rek 1300xxxx88 ada dana keluar sebesar '
            'IDR209.000,00. Saldo akhir: IDR 520,00.Berita: 88100xxxx99 '
            'Dana DNID FRAXX JUAXXXXX',
      )!;
      expect(t.direction, MoneyDirection.out);
      expect(t.amount, 209000);
      expect(t.appName, 'BNI');
    });

    test('SMS telat: waktu catatan dari isi pesan', () {
      final t = parseBankNotification(
        packageName: 'com.google.android.apps.messaging',
        title: 'BNI',
        text:
            '24/09/2026 07:39 Pada No. Rek 1300xxxx88 ada dana keluar '
            'sebesar IDR50.000,00. Saldo akhir: IDR 520,00.',
        postedAt: now, // diterima 26 Sep, 2 hari kemudian
        source: NotificationSource.sms,
      )!;
      expect(t.occurredAt, DateTime(2026, 9, 24, 7, 39));
    });

    test(
      'tanggal di pesan terlalu lama / di masa depan: pakai waktu terima',
      () {
        for (final date in ['01/01/2026 10:00', '30/09/2026 10:00']) {
          final t = parseBankNotification(
            packageName: 'com.google.android.apps.messaging',
            title: 'BNI',
            text: '$date ada dana keluar sebesar IDR50.000,00.',
            postedAt: now,
            source: NotificationSource.sms,
          )!;
          expect(t.occurredAt, now, reason: date);
        }
      },
    );

    test('SMS BNI dana masuk', () {
      final t = via(
        NotificationSource.sms,
        'com.google.android.apps.messaging',
        'BNI',
        '17/06/2025 21:58 Pada No. Rek 1300xxxx88 ada dana masuk sebesar '
            'IDR200.000,00. Saldo akhir: IDR 209.520,00.Berita: Bik S***',
      )!;
      expect(t.direction, MoneyDirection.into);
      expect(t.amount, 200000);
    });

    // Pola iklan / tagihan / OTP asli yang sering masuk.
    for (final (sender, body) in const [
      (
        'Allo Bank',
        'Butuh dana ekstra? Allo Bank PayLater siap bantu! Limit s.d Rp100JT, '
            'tenor s.d 36bln, KUPON BUNGA 0%* untuk kamu yang terpilih! '
            'Klik myads.id/xxxx Penawaran/info ini bermanfaat? Jika tidak, '
            'Kirim STOP Allo Bank ke 8000',
      ),
      (
        'PinjamDuit',
        'Butuh dana cepat? PinjamDuit bantu! Limit hingga Rp50.000.000, '
            'peluang disetujui 96%! Ajukan sekarang. Klik: myads.id/xxxx',
      ),
      (
        '3 DigiFin',
        'Saldo tipis pasca lebaran? Pake Kredit Pintar, dana s.d. Rp50 jt '
            'siap back up. Bunga rendah mulai 0,08% per hari.',
      ),
      (
        'Bank Mega',
        'WOW! Bonus s.d Rp850rb menantimu. Buka tabungan Mega Zaver dan '
            'nikmati bebas biaya transfer antar bank. Ajukan: myads.id/xxxx',
      ),
      (
        'Seabank ID',
        'Bonus 100RB bisa masuk ke rekeningmu! Download SeaBank & pakai kode '
            'referral: SEABANKxxx sda-ida.id/xxxx . *S&K berlaku SPX',
      ),
      (
        'GoPayLater',
        'Pelanggan Yth,Tagihan GoPay Later 145,506 dari MAB sdh jatuh tempo.'
            'Biaya denda 50rb akan dibebankan besok jika tdk ada pembayaran.',
      ),
      (
        'BCA',
        'BCA：5480 poin Anda akan kedaluwarsa hari ini. Klik tautan ini：'
            'https://lnk.ink/xxxx untuk menukarkan hadiah.',
      ),
      (
        'DANA',
        'AWAS PENIPUAN! Akunmu masuk di perangkat baru. Jangan bagi kode ini '
            'ke siapapun, termasuk pihak DANA. Kode OTP: 1234.',
      ),
    ]) {
      test('iklan/tagihan/OTP dibuang: $sender', () {
        expect(
          via(
            NotificationSource.sms,
            'com.google.android.apps.messaging',
            sender,
            body,
          ),
          isNull,
        );
      });
    }

    test('nama bank cuma disebut di tengah pesan tidak dihitung', () {
      expect(
        via(
          NotificationSource.sms,
          'com.google.android.apps.messaging',
          'Budi',
          'Udah aku transfer Rp 50.000 ke rekening BCA kamu ya',
        ),
        isNull,
      );
    });

    test('Rp dengan satuan rb / jt', () {
      final t = via(
        NotificationSource.sms,
        'com.google.android.apps.messaging',
        'BRI',
        'BRI: Pembayaran Rp1,2jt ke TOKO ELEKTRONIK berhasil',
      )!;
      expect(t.amount, 1200000);
    });

    test('SMS pribadi tanpa nama bank diabaikan', () {
      expect(
        via(
          NotificationSource.sms,
          'com.google.android.apps.messaging',
          'Mama',
          'Nak, uang Rp 100.000 udah mama kirim ya',
        ),
        isNull,
      );
    });

    test('email promo bank diabaikan', () {
      expect(
        via(
          NotificationSource.email,
          'com.google.android.gm',
          'BCA',
          'Promo cashback Rp 50.000 pakai kartu kredit BCA',
        ),
        isNull,
      );
    });
  });

  group('dibuang', () {
    test('OTP', () {
      expect(
        parse(
          'id.bni.wondr',
          'Kode OTP',
          'Kode OTP 123456 untuk transaksi Rp 100.000. Jangan berikan ke siapapun',
        ),
        isNull,
      );
    });

    test('promo', () {
      expect(
        parse(
          'com.gojek.app',
          'Promo spesial!',
          'Diskon Rp10.000 buat GoFood kamu hari ini',
        ),
        isNull,
      );
    });

    test('top up (akan dobel dengan notif bank)', () {
      expect(
        parse('id.dana', 'Top Up Berhasil', 'Top up Rp 100.000 berhasil masuk'),
        isNull,
      );
    });

    test('transaksi gagal', () {
      expect(
        parse(
          'ovo.id',
          'Pembayaran gagal',
          'Pembayaran Rp 30.000 ke Solaria gagal',
        ),
        isNull,
      );
    });

    test('tanpa nominal', () {
      expect(
        parse('id.dana', 'Transfer berhasil', 'Transfer kamu sudah diterima'),
        isNull,
      );
    });

    test('arah tidak jelas', () {
      expect(parse('id.dana', 'Info', 'Saldo kamu sekarang Rp 90.000'), isNull);
    });

    test('bukan aplikasi keuangan', () {
      expect(
        parse('com.whatsapp', 'Budi', 'Udah aku transfer Rp 50.000 ya'),
        isNull,
      );
    });
  });
}
