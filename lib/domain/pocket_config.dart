import 'allocation.dart';
import 'types.dart';

/// Nama tampilan tipe kantong ("Tipe: Keinginan").
String pocketTypeLabel(PocketType type) => switch (type) {
  PocketType.wajib => 'Wajib',
  PocketType.darurat => 'Darurat',
  PocketType.keinginan => 'Keinginan',
};

/// Pengaturan satu kantong yang bisa diubah user (layar 20–22).
class PocketConfig {
  const PocketConfig({
    required this.id,
    required this.type,
    required this.name,
    required this.iconKey,
    required this.color,
    this.mode = AllocationMode.percent,
    this.percent = 0,
    this.nominal = 0,
    this.rangeMin,
    this.rangeMax,
    this.lowThresholdPercent = 20,
    this.rolloverToEmergency = false,
  });

  final String id;
  final PocketType type;
  final String name;
  final String iconKey;
  final int color;
  final AllocationMode mode;
  final int percent;
  final int nominal;
  final int? rangeMin;
  final int? rangeMax;

  /// 0 = peringatan hampir habis dimatikan.
  final int lowThresholdPercent;
  final bool rolloverToEmergency;

  PocketRule get rule => PocketRule(
    pocketId: id,
    mode: mode,
    percent: percent,
    nominal: nominal,
    rangeMin: rangeMin,
    rangeMax: rangeMax,
  );

  /// Jatah rupiah dari [base] (tanpa rentang), untuk tampilan.
  int amountOf(int base) =>
      mode == AllocationMode.percent ? (base * percent / 100).round() : nominal;

  /// Persen dari [base] (mode nominal dikonversi), untuk tampilan.
  int percentOf(int base) => mode == AllocationMode.percent
      ? percent
      : base <= 0
      ? 0
      : (nominal * 100 / base).round();

  PocketConfig copyWith({
    String? name,
    String? iconKey,
    int? color,
    AllocationMode? mode,
    int? percent,
    int? nominal,
    int? Function()? rangeMin,
    int? Function()? rangeMax,
    int? lowThresholdPercent,
    bool? rolloverToEmergency,
  }) => PocketConfig(
    id: id,
    type: type,
    name: name ?? this.name,
    iconKey: iconKey ?? this.iconKey,
    color: color ?? this.color,
    mode: mode ?? this.mode,
    percent: percent ?? this.percent,
    nominal: nominal ?? this.nominal,
    rangeMin: rangeMin == null ? this.rangeMin : rangeMin(),
    rangeMax: rangeMax == null ? this.rangeMax : rangeMax(),
    lowThresholdPercent: lowThresholdPercent ?? this.lowThresholdPercent,
    rolloverToEmergency: rolloverToEmergency ?? this.rolloverToEmergency,
  );

  /// Ganti satuan jatah dengan nilai setara dari [base].
  PocketConfig withMode(AllocationMode next, int base) {
    if (next == mode) return this;
    return next == AllocationMode.nominal
        ? copyWith(mode: next, nominal: amountOf(base))
        : copyWith(mode: next, percent: percentOf(base));
  }

  @override
  bool operator ==(Object other) =>
      other is PocketConfig &&
      other.id == id &&
      other.name == name &&
      other.iconKey == iconKey &&
      other.color == color &&
      other.mode == mode &&
      other.percent == percent &&
      other.nominal == nominal &&
      other.rangeMin == rangeMin &&
      other.rangeMax == rangeMax &&
      other.lowThresholdPercent == lowThresholdPercent &&
      other.rolloverToEmergency == rolloverToEmergency;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    iconKey,
    color,
    mode,
    percent,
    nominal,
    rangeMin,
    rangeMax,
    lowThresholdPercent,
    rolloverToEmergency,
  );
}

/// Data layar Atur Kantong (20).
class PocketSetup {
  const PocketSetup({
    required this.incomeMode,
    required this.base,
    required this.perNoun,
    required this.pockets,
  });

  final IncomeMode incomeMode;

  /// Pemasukan per periode yang dibagi (gaji / uang jajan). Penghasilan tidak
  /// tetap: perkiraan sebulan (boleh 0), hanya untuk tampilan.
  final int base;

  /// "bulan" / "minggu" / "hari".
  final String perNoun;
  final List<PocketConfig> pockets;

  bool get isRunning => incomeMode == IncomeMode.irregular;

  AllocationCheck get check => isRunning
      ? AllocationCheck(
          salary: 100,
          totalAllocated: pockets.fold<int>(0, (s, p) => s + p.percent),
          percentSum: pockets.fold<int>(0, (s, p) => s + p.percent),
          allPercent: true,
        )
      : AllocationCheck.of(base, [
          // Rentang tidak ikut divalidasi: itu penyesuaian saat gaji berubah.
          for (final p in pockets)
            PocketRule(
              pocketId: p.id,
              mode: p.mode,
              percent: p.percent,
              nominal: p.nominal,
            ),
        ]);

  PocketSetup copyWith({List<PocketConfig>? pockets}) => PocketSetup(
    incomeMode: incomeMode,
    base: base,
    perNoun: perNoun,
    pockets: pockets ?? this.pockets,
  );
}

/// "Rapiin otomatis" (layar 23): skala semua jatah supaya pas 100% / pas
/// sebesar [base], perbandingan antar kantong tetap. Sisa pembulatan masuk
/// ke kantong terbesar.
List<PocketConfig> balancePockets(List<PocketConfig> pockets, int base) {
  if (pockets.isEmpty) return pockets;
  final allPercent = pockets.every((p) => p.mode == AllocationMode.percent);
  if (allPercent || base <= 0) {
    final values = _scaleTo(100, [for (final p in pockets) p.percentOf(base)]);
    return [
      for (final (i, p) in pockets.indexed)
        p.copyWith(mode: AllocationMode.percent, percent: values[i]),
    ];
  }
  final amounts = _scaleTo(base, [for (final p in pockets) p.amountOf(base)]);
  final result = [
    for (final (i, p) in pockets.indexed)
      p.mode == AllocationMode.nominal
          ? p.copyWith(nominal: amounts[i])
          : p.copyWith(percent: (amounts[i] * 100 / base).round()),
  ];
  // Kantong persen dibulatkan → selisihnya ditutup kantong nominal terbesar.
  final check = AllocationCheck.of(base, [
    for (final p in result)
      PocketRule(
        pocketId: p.id,
        mode: p.mode,
        percent: p.percent,
        nominal: p.nominal,
      ),
  ]);
  if (check.difference != 0) {
    var target = -1;
    for (final (i, p) in result.indexed) {
      if (p.mode == AllocationMode.nominal &&
          (target < 0 || p.nominal > result[target].nominal)) {
        target = i;
      }
    }
    if (target >= 0) {
      result[target] = result[target].copyWith(
        nominal: result[target].nominal - check.difference,
      );
    }
  }
  return result;
}

/// Skala [values] supaya jumlahnya [total] (metode sisa terbesar).
List<int> _scaleTo(int total, List<int> values) {
  final sum = values.fold<int>(0, (s, v) => s + v);
  if (sum <= 0) {
    // Semua 0 → bagi rata.
    final each = total ~/ values.length;
    return [
      for (var i = 0; i < values.length; i++)
        i == 0 ? total - each * (values.length - 1) : each,
    ];
  }
  final exact = [for (final v in values) v * total / sum];
  final result = [for (final e in exact) e.floor()];
  var left = total - result.fold<int>(0, (s, v) => s + v);
  final order = List.generate(values.length, (i) => i)
    ..sort((a, b) {
      final byFraction = (exact[b] - result[b]).compareTo(exact[a] - result[a]);
      return byFraction != 0 ? byFraction : values[b].compareTo(values[a]);
    });
  for (final i in order) {
    if (left == 0) break;
    result[i]++;
    left--;
  }
  return result;
}
