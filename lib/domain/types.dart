/// Tipe kantong tetap (dipakai laporan). Nama/ikon/warna boleh dikustom user.
enum PocketType { wajib, darurat, keinginan }

/// Cara jatah kantong dihitung dari pemasukan.
enum AllocationMode { percent, nominal }

/// Asal pengeluaran.
enum ExpenseSource {
  manual,
  scan,

  /// Dari notifikasi bank / e-wallet (catat otomatis), dikonfirmasi user.
  notif;

  /// "Sumber" di detail transaksi & export.
  String get label => switch (this) {
    ExpenseSource.manual => 'Catat manual',
    ExpenseSource.scan => 'Scan struk',
    ExpenseSource.notif => 'Notifikasi bank',
  };

  /// Keterangan kecil di daftar catatan ("dari scan"); manual tidak ditandai.
  String? get tag => switch (this) {
    ExpenseSource.manual => null,
    ExpenseSource.scan => 'dari scan',
    ExpenseSource.notif => 'dari notif',
  };
}

/// Dari mana uang user biasanya datang (layar 27).
enum IncomeMode {
  /// Pekerja bergaji tetap: otomatis masuk tiap tanggal gajian.
  salary,

  /// Pelajar/mahasiswa: uang jajan otomatis masuk harian/mingguan/bulanan.
  allowance,

  /// Freelance, ojol, kerja harian: user menambah sendiri tiap dapat uang,
  /// saldo kantong terus berjalan (tidak di-reset per periode).
  irregular,
}

/// Siklus pemasukan otomatis (gaji selalu bulanan).
enum IncomeFrequency { daily, weekly, monthly }
