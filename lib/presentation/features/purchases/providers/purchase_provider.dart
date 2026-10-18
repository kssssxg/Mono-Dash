import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/storage_service.dart';
import '../../../../core/utils/app_logger.dart';

/// Provider that replaces the former RevenueCat-backed purchase controller.
///
/// In-app purchases have been removed from this build: every feature that was
/// previously gated behind the "Mono Dash Unlimited" entitlement is now
/// unlocked unconditionally, and the free-tier server limit no longer applies.
final purchaseControllerProvider =
    AsyncNotifierProvider<PurchaseController, PurchaseState>(
      PurchaseController.new,
    );

enum PurchaseVerificationStatus { localOnly, verified, unverified, unavailable }

class PurchaseState {
  const PurchaseState({
    this.isConfigured = true,
    this.isUnlocked = true,
    this.freeServerLimit = 0,
    this.entitlementId = '',
    this.verificationStatus = PurchaseVerificationStatus.verified,
    this.priceText,
    this.hasPackage = true,
    this.message,
    this.lastVerifiedAt,
  });

  final bool isConfigured;
  final bool isUnlocked;

  /// Legacy free-tier limit kept for API compatibility. `0` means unlimited.
  final int freeServerLimit;
  final String entitlementId;
  final PurchaseVerificationStatus verificationStatus;
  final String? priceText;
  final bool hasPackage;
  final String? message;
  final DateTime? lastVerifiedAt;

  /// Unlimited: adding servers is always allowed.
  bool canAddServer(int serverCount) => true;

  PurchaseState copyWith({
    bool? isConfigured,
    bool? isUnlocked,
    int? freeServerLimit,
    String? entitlementId,
    PurchaseVerificationStatus? verificationStatus,
    String? priceText,
    bool? hasPackage,
    String? message,
    DateTime? lastVerifiedAt,
    bool clearPriceText = false,
    bool clearMessage = false,
  }) {
    return PurchaseState(
      isConfigured: isConfigured ?? this.isConfigured,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      freeServerLimit: freeServerLimit ?? this.freeServerLimit,
      entitlementId: entitlementId ?? this.entitlementId,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      priceText: clearPriceText ? null : priceText ?? this.priceText,
      hasPackage: hasPackage ?? this.hasPackage,
      message: clearMessage ? null : message ?? this.message,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
    );
  }
}

/// Kept for API compatibility with call sites that referenced the old
/// server-limit exception; it is never thrown anymore.
class ServerLimitReachedException implements Exception {
  const ServerLimitReachedException({
    required this.serverCount,
    required this.freeServerLimit,
    required this.message,
  });

  final int serverCount;
  final int freeServerLimit;
  final String message;

  @override
  String toString() => message;
}

/// Kept for API compatibility; never thrown anymore.
class PurchaseUnavailableException implements Exception {
  const PurchaseUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PurchaseController extends AsyncNotifier<PurchaseState> {
  static const _tag = 'purchase';

  /// Legacy secure-storage flag used by previous versions to cache the local
  /// unlock state. Kept so an old install stays unlocked after upgrading.
  static const _localUnlockKey = 'purchase.unlimited_servers.unlocked';

  @override
  Future<PurchaseState> build() => _loadLocalState();

  static Future<bool> isLocallyUnlocked(WidgetRef ref) async {
    return (await ref.read(purchaseControllerProvider.future)).isUnlocked;
  }

  Future<PurchaseState> _loadLocalState() async {
    final storage = ref.read(storageServiceProvider);
    // Persist a local unlock flag so upgrades from a paywalled build keep
    // reporting an unlocked state in any code path that still reads it.
    await storage.setSecureString(_localUnlockKey, 'true');
    return const PurchaseState();
  }

  Future<PurchaseState> maybeRefreshEntitlementAfterFirstFrame() async {
    final current = state.valueOrNull ?? const PurchaseState();
    if (state.valueOrNull == null) {
      state = AsyncValue.data(current);
    }
    return current;
  }

  Future<PurchaseState> refresh() => refreshEntitlement();

  Future<PurchaseState> refreshEntitlement({bool force = true}) async {
    return state.valueOrNull ?? await _loadLocalState();
  }

  Future<PurchaseState> loadOfferings({bool force = false}) async {
    return state.valueOrNull ?? await _loadLocalState();
  }

  Future<PurchaseState> restorePurchases() async {
    return state.valueOrNull ?? await _loadLocalState();
  }

  Future<PurchaseState> purchaseUnlimitedServers() async {
    AppLogger.w(
      _tag,
      'purchaseUnlimitedServers called but purchases are disabled; '
      'all features are unlocked.',
    );
    return state.valueOrNull ?? await _loadLocalState();
  }

  Future<String> revenueCatCustomerIdForTestFlight() async {
    return 'local-user';
  }
}
