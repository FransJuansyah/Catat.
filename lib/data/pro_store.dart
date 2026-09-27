import 'dart:async';

import 'package:drift/drift.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../domain/pro.dart';
import 'local/database.dart';

/// Status Pro dari profil (ikut sinkron ke akun).
class ProRepository {
  ProRepository(this._db, this._now);

  final AppDatabase _db;
  final DateTime Function() _now;

  SimpleSelectStatement<$ProfilesTable, Profile> get _profile =>
      _db.select(_db.profiles)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
        ..limit(1);

  ProStatus _of(Profile? p) => ProStatus(
    trialStart: p?.trialStartedAt,
    purchasedAt: p?.proPurchasedAt,
    now: _now(),
  );

  Future<ProStatus> status() async => _of(await _profile.getSingleOrNull());

  Stream<ProStatus> watchStatus() => _profile.watchSingleOrNull().map(_of);

  /// Pembelian Google Play berhasil / dipulihkan.
  Future<void> markPurchased(String token) async {
    final now = _now();
    await (_db.update(
      _db.profiles,
    )..where((t) => t.proPurchasedAt.isNull())).write(
      ProfilesCompanion(
        proPurchasedAt: Value(now),
        proToken: Value(token),
        updatedAt: Value(now),
      ),
    );
  }
}

enum ProPurchaseState { purchased, pending, canceled, error }

class ProStoreEvent {
  const ProStoreEvent(this.state, {this.token, this.message});

  final ProPurchaseState state;

  /// Token pembelian (untuk verifikasi di server nanti).
  final String? token;
  final String? message;
}

/// Toko: Google Play Billing. Di-override di test.
abstract class ProStore {
  /// Harga dari Google Play (sudah terformat, mis. "Rp 49.000").
  /// null = toko belum tersedia (app bukan dari Play Store / offline).
  Future<String?> price();

  /// Buka lembar bayar Google Play. Hasil datang lewat [events].
  Future<void> buy();

  /// Cek pembelian lama (install ulang / HP baru, akun Google sama).
  Future<void> restore();

  Stream<ProStoreEvent> get events;
}

/// Toko belum tersedia (produk belum dibuat di Play Console, atau app tidak
/// diinstal dari Play Store).
class ProStoreUnavailable implements Exception {
  const ProStoreUnavailable();
}

/// Tanpa Google Play (test, desktop): harga desain, tombol bayar menjelaskan.
class NoProStore implements ProStore {
  const NoProStore();

  @override
  Future<String?> price() async => null;

  @override
  Future<void> buy() async => throw const ProStoreUnavailable();

  @override
  Future<void> restore() async {}

  @override
  Stream<ProStoreEvent> get events => const Stream.empty();
}

class PlayProStore implements ProStore {
  PlayProStore() {
    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) {
        _events.add(ProStoreEvent(ProPurchaseState.error, message: '$e'));
      },
    );
  }

  /// Produk sekali bayar di Play Console (Monetize → In-app products).
  static const productId = 'catat_pro';

  final _iap = InAppPurchase.instance;
  final _events = StreamController<ProStoreEvent>.broadcast();
  late final StreamSubscription<List<PurchaseDetails>> _sub;
  ProductDetails? _product;

  Future<ProductDetails?> _load() async {
    if (_product != null) return _product;
    if (!await _iap.isAvailable()) return null;
    final res = await _iap.queryProductDetails({productId});
    return _product = res.productDetails.firstOrNull;
  }

  @override
  Future<String?> price() async {
    try {
      return (await _load())?.price;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> buy() async {
    final product = await _load();
    if (product == null) throw const ProStoreUnavailable();
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  @override
  Future<void> restore() async {
    if (await _iap.isAvailable()) await _iap.restorePurchases();
  }

  @override
  Stream<ProStoreEvent> get events => _events.stream;

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.productID != productId) continue;
      switch (p.status) {
        case PurchaseStatus.pending:
          _events.add(const ProStoreEvent(ProPurchaseState.pending));
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          _events.add(
            ProStoreEvent(
              ProPurchaseState.purchased,
              token: p.verificationData.serverVerificationData,
            ),
          );
        case PurchaseStatus.canceled:
          _events.add(const ProStoreEvent(ProPurchaseState.canceled));
        case PurchaseStatus.error:
          _events.add(
            ProStoreEvent(ProPurchaseState.error, message: p.error?.message),
          );
      }
      // Wajib: tanpa ini Google Play mengembalikan uang setelah 3 hari.
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
  }

  void dispose() {
    _sub.cancel();
    _events.close();
  }
}
