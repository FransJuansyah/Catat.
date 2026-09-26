/// Tipe kantong tetap (dipakai laporan). Nama/ikon/warna boleh dikustom user.
enum PocketType { wajib, darurat, keinginan }

/// Cara jatah kantong dihitung dari pemasukan.
enum AllocationMode { percent, nominal }

/// Asal pengeluaran.
enum ExpenseSource { manual, scan }

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
