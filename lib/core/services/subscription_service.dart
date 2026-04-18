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
  final String? managementUrl;

  const SubscriptionStatus({
    required this.tier,
    this.expiresAt,
    this.managementUrl,
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
  Future<SubscriptionPurchaseResult> purchase(Package package);
  Future<bool> restorePurchases();
  Stream<SubscriptionStatus> get statusStream;
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

    await Purchases.setLogLevel(LogLevel.debug);

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
  Future<SubscriptionPurchaseResult> purchase(Package package) async {
    try {
      final result = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      final isActive = result.customerInfo.entitlements
          .all[_entitlementId]?.isActive ?? false;
      return isActive ? SubscriptionPurchaseResult.success : SubscriptionPurchaseResult.failed;
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
      return info.entitlements.all[_entitlementId]?.isActive ?? false;
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
      );
    }
    return SubscriptionStatus.free;
  }
}
