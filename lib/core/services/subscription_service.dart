import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

enum SubscriptionTier { free, premium }

enum SubscriptionPurchaseResult {
  /// Satın alma başarılı, entitlement aktif.
  success,

  /// Kullanıcı Play Billing ekranından iptal etti — hata gösterme.
  cancelled,

  /// Satın alma tamamlandı ama entitlement aktif görünmüyor (nadir).
  failed,
}

class SubscriptionStatus {
  final SubscriptionTier tier;
  final DateTime? expiresAt;

  /// Deep link to the store's own subscription page — the only place a
  /// subscription can actually be cancelled. Neither Play nor the App Store
  /// lets an app cancel on the user's behalf, so "cancel" in our UI can only
  /// ever mean "take me there".
  ///
  /// Null when the entitlement has no store subscription behind it (a
  /// RevenueCat promotional grant, or one of our own Supabase comp grants).
  final String? managementUrl;

  /// The product backing the entitlement, e.g. the monthly or the annual
  /// subscription. Lets the UI tell which plan the user is already on instead
  /// of offering it to them a second time.
  final String? productId;

  /// False once the store reports an unsubscribe. Access continues until
  /// [expiresAt] either way, so this is the difference between "renews on
  /// the 12th" and "ends on the 12th" — opposite messages to the user.
  final bool willRenew;

  const SubscriptionStatus({
    required this.tier,
    this.expiresAt,
    this.managementUrl,
    this.productId,
    this.willRenew = false,
  });

  bool get isPremium => tier == SubscriptionTier.premium;

  static const free = SubscriptionStatus(tier: SubscriptionTier.free);
}

abstract interface class SubscriptionService {
  Future<void> initialize();
  Future<void> logIn(String userId);
  Future<void> logOut();
  Future<SubscriptionStatus> getStatus();
  Future<List<Package>> getOfferings();

  /// Buys [package]. Pass [replacingProductId] when the user already holds a
  /// subscription and is moving to a different plan — Play rejects a plain
  /// purchase inside a subscription group the user is already in, and needs to
  /// be told which product is being replaced.
  Future<SubscriptionPurchaseResult> purchase(
    Package package, {
    String? replacingProductId,
  });
  Future<bool> restorePurchases();
  Stream<SubscriptionStatus> get statusStream;
}

@visibleForTesting
LogLevel revenueCatLogLevelFor({required bool releaseMode}) {
  return releaseMode ? LogLevel.warn : LogLevel.debug;
}

final class RevenueCatSubscriptionService implements SubscriptionService {
  // Must match the entitlement identifier in the RevenueCat dashboard:
  // NutriLens project → Product catalog → Entitlements.
  static const _entitlementId = 'NutriLens Pro';

  StreamController<SubscriptionStatus>? _statusController;

  @override
  Future<void> initialize() async {
    final apiKeyAndroid = dotenv.env['RC_API_KEY_ANDROID'] ?? '';
    final apiKeyIos = dotenv.env['RC_API_KEY_IOS'] ?? '';

    final apiKey = defaultTargetPlatform == TargetPlatform.android
        ? apiKeyAndroid
        : apiKeyIos;

    if (apiKey.isEmpty) {
      debugPrint('[RevenueCat] No API key — running in mock mode');
      return;
    }

    await Purchases.setLogLevel(
      revenueCatLogLevelFor(releaseMode: kReleaseMode),
    );

    final configuration = PurchasesConfiguration(apiKey);
    await Purchases.configure(configuration);
    debugPrint('[RevenueCat] Configured');
  }

  @override
  Future<void> logIn(String userId) async {
    try {
      await Purchases.logIn(userId);
      debugPrint('[RevenueCat] Logged in as $userId');
    } catch (e) {
      debugPrint('[RevenueCat] Login error: $e');
    }
  }

  @override
  Future<void> logOut() async {
    try {
      if (await Purchases.isAnonymous == false) {
        await Purchases.logOut();
      }
    } catch (e) {
      debugPrint('[RevenueCat] Logout error: $e');
    }
  }

  @override
  Future<SubscriptionStatus> getStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return _mapCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint('[RevenueCat] getStatus error: $e');
      return SubscriptionStatus.free;
    }
  }

  @override
  Future<List<Package>> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? [];
    } catch (e) {
      debugPrint('[RevenueCat] getOfferings error: $e');
      return [];
    }
  }

  @override
  Future<SubscriptionPurchaseResult> purchase(
    Package package, {
    String? replacingProductId,
  }) async {
    try {
      // Product-change info is a Play concept. StoreKit resolves a move
      // inside a subscription group by itself, and passing the field there
      // would be describing a flow the platform does not have.
      final isPlanChange =
          replacingProductId != null &&
          defaultTargetPlatform == TargetPlatform.android;
      final params = isPlanChange
          ? PurchaseParams.package(
              package,
              googleProductChangeInfo: GoogleProductChangeInfo(
                replacingProductId,
                // Credit the unused remainder of the old plan against the new
                // one. The SDK's default here is `immediateWithoutProration`,
                // which would charge for a year while the month the user has
                // already paid for is still running — an upgrade that reads
                // as a double charge, and a refund request.
                prorationMode: GoogleProrationMode.immediateWithTimeProration,
              ),
            )
          : PurchaseParams.package(package);
      final result = await Purchases.purchase(params);
      final status = _mapCustomerInfo(result.customerInfo);
      _statusController?.add(status);
      final isActive = status.isPremium;
      return isActive
          ? SubscriptionPurchaseResult.success
          : SubscriptionPurchaseResult.failed;
    } on PlatformException catch (e) {
      // purchases_flutter throws PlatformException — map to PurchasesErrorCode
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        // User tapped back / cancelled the Play Billing sheet — not an error.
        return SubscriptionPurchaseResult.cancelled;
      }
      debugPrint('[RevenueCat] Purchase error: $errorCode — ${e.message}');
      rethrow; // Let the caller (PaywallScreen) show the error to the user
    } catch (e) {
      debugPrint('[RevenueCat] Purchase unexpected error: $e');
      rethrow;
    }
  }

  @override
  Future<bool> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      final status = _mapCustomerInfo(info);
      _statusController?.add(status);
      return status.isPremium;
    } catch (e) {
      debugPrint('[RevenueCat] Restore error: $e');
      return false;
    }
  }

  @override
  Stream<SubscriptionStatus> get statusStream {
    if (_statusController == null) {
      _statusController = StreamController<SubscriptionStatus>.broadcast(
        onCancel: () {
          _statusController?.close();
          _statusController = null;
        },
      );
      Purchases.addCustomerInfoUpdateListener((info) {
        _statusController?.add(_mapCustomerInfo(info));
      });
    }
    return _statusController!.stream;
  }

  SubscriptionStatus _mapCustomerInfo(CustomerInfo info) {
    final entitlement = info.entitlements.all[_entitlementId];
    if (entitlement != null && entitlement.isActive) {
      return SubscriptionStatus(
        tier: SubscriptionTier.premium,
        expiresAt: entitlement.expirationDate != null
            ? DateTime.tryParse(entitlement.expirationDate!)
            : null,
        managementUrl: info.managementURL,
        productId: entitlement.productIdentifier,
        willRenew: entitlement.willRenew,
      );
    }
    return SubscriptionStatus.free;
  }
}
