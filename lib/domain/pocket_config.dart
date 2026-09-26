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
    PocketType? type,
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
    type: type ?? this.type,
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
      other.type == type &&
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
    type,
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

/// Batas jumlah kantong (keputusan 27 Sep 2026): cukup fleksibel tapi
/// Beranda & laporan tetap ringkas.
const minPockets = 2;
const maxPockets = 6;

/// Kantong baru (layar 20/43 "Tambah kantong"): jatah 0, ikon & warna yang
/// belum dipakai kantong lain supaya gampang dibedakan.
PocketConfig newPocket(
  String id,
  List<PocketConfig> existing, {
  required List<String> icons,
  required List<int> colors,
}) {
  final usedIcons = {for (final p in existing) p.iconKey};
  final usedColors = {for (final p in existing) p.color};
  final allNominal =
      existing.isNotEmpty &&
      existing.every((p) => p.mode == AllocationMode.nominal);
  return PocketConfig(
    id: id,
    type: PocketType.keinginan,
    name: 'Kantong ${existing.length + 1}',
    iconKey: icons.firstWhere(
      (i) => !usedIcons.contains(i),
      orElse: () => icons.first,
    ),
    color: colors.firstWhere(
      (c) => !usedColors.contains(c),
      orElse: () => colors.first,
    ),
    mode: allNominal ? AllocationMode.nominal : AllocationMode.percent,
  );
}

/// Hapus kantong [removedId] dari daftar; jatahnya pindah ke [targetId]
/// supaya total tetap pas (layar 45). [base] dipakai kalau satuannya beda.
List<PocketConfig> withoutPocket(
  List<PocketConfig> pockets,
  String removedId,
  String targetId,
  int base,
) {
  if (removedId == targetId) {
    throw ArgumentError.value(targetId, 'targetId', 'kantong sama');
  }
  final removed = pockets.firstWhere((p) => p.id == removedId);
  return [
    for (final p in pockets)
      if (p.id == targetId)
        p.mode == AllocationMode.nominal
            ? p.copyWith(nominal: p.nominal + removed.amountOf(base))
            : p.copyWith(
                percent: (p.percent + removed.percentOf(base)).clamp(0, 100),
              )
      else if (p.id != removedId)
        p,
  ];
}

/// Data layar Atur Kantong (20).
class PocketSetup {
  const PocketSetup({
    required this.incomeMode,
    required this.base,
    required this.perNoun,
    required this.pockets,
    this.fromOpening = false,
  });

  final IncomeMode incomeMode;

  /// [base] = saldo awal periode pertama (layar 42), bukan gaji / uang jajan.
  final bool fromOpening;

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

  bool get canAdd => pockets.length < maxPockets;
  bool get canRemove => pockets.length > minPockets;

  PocketSetup copyWith({List<PocketConfig>? pockets}) => PocketSetup(
    incomeMode: incomeMode,
    base: base,
    perNoun: perNoun,
    pockets: pockets ?? this.pockets,
    fromOpening: fromOpening,
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
