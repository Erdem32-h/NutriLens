import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

enum SubscriptionTier { free, premium }

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
  Future<bool> purchase(Package package);
  Future<bool> restorePurchases();
  Stream<SubscriptionStatus> get statusStream;
}

final class RevenueCatSubscriptionService implements SubscriptionService {
  static const _apiKeyAndroid = String.fromEnvironment('RC_API_KEY_ANDROID');
  static const _apiKeyIos = String.fromEnvironment('RC_API_KEY_IOS');
  static const _entitlementId = 'premium';

  @override
  Future<void> initialize() async {
    final apiKey = defaultTargetPlatform == TargetPlatform.android
        ? _apiKeyAndroid
        : _apiKeyIos;

    if (apiKey.isEmpty) {
      debugPrint('[RevenueCat] No API key — running in mock mode');
      return;
    }

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
  Future<bool> purchase(Package package) async {
    try {
      final result = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      return result.customerInfo.entitlements
          .all[_entitlementId]?.isActive ?? false;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) return false;
      debugPrint('[RevenueCat] Purchase error: $e');
      return false;
    } catch (e) {
      debugPrint('[RevenueCat] Purchase error: $e');
      return false;
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
    final controller = StreamController<SubscriptionStatus>.broadcast();
    Purchases.addCustomerInfoUpdateListener((info) {
      controller.add(_mapCustomerInfo(info));
    });
    return controller.stream;
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
