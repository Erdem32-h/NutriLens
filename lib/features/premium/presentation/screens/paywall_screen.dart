import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../../core/providers/monetization_provider.dart';
import '../../../../core/theme/app_colors.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  List<Package> _packages = [];
  bool _loading = true;
  bool _purchasing = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final service = ref.read(subscriptionServiceProvider);
    final packages = await service.getOfferings();
    if (mounted) {
      setState(() {
        _packages = packages;
        _loading = false;
        // Default to annual if available
        final annualIdx = packages.indexWhere(
          (p) => p.packageType == PackageType.annual,
        );
        if (annualIdx >= 0) _selectedIndex = annualIdx;
      });
    }
  }

  Future<void> _purchase() async {
    if (_packages.isEmpty || _purchasing) return;
    setState(() => _purchasing = true);

    final service = ref.read(subscriptionServiceProvider);
    final success = await service.purchase(_packages[_selectedIndex]);

    if (mounted) {
      setState(() => _purchasing = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium aktif! 🎉')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _restore() async {
    final service = ref.read(subscriptionServiceProvider);
    final success = await service.restorePurchases();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Abonelik geri yüklendi!'
              : 'Aktif abonelik bulunamadı.'),
        ),
      );
      if (success) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium'),
        actions: [
          TextButton(
            onPressed: _restore,
            child: const Text('Geri Yükle'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Hero
                  Icon(Icons.star, size: 64, color: colors.warning),
                  const SizedBox(height: 16),
                  Text(
                    'NutriLens Premium',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // Features
                  const _FeatureTile(icon: Icons.all_inclusive, text: 'Sınırsız tarama'),
                  const _FeatureTile(icon: Icons.block, text: 'Reklamsız deneyim'),
                  const _FeatureTile(icon: Icons.smart_toy, text: 'Sınırsız AI tarama'),
                  const _FeatureTile(icon: Icons.support_agent, text: 'Öncelikli destek'),
                  const SizedBox(height: 32),

                  // Package cards
                  RadioGroup<int>(
                    groupValue: _selectedIndex,
                    onChanged: (v) => setState(() => _selectedIndex = v!),
                    child: Column(
                      children: _packages.asMap().entries.map((entry) {
                        final i = entry.key;
                        final pkg = entry.value;
                        final isSelected = i == _selectedIndex;
                        final isAnnual = pkg.packageType == PackageType.annual;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedIndex = i),
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected
                                    ? colors.primary
                                    : colors.textSecondary
                                        .withValues(alpha: 0.2),
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Radio<int>(value: i),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            isAnnual ? 'Yıllık' : 'Aylık',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          if (isAnnual) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: colors.success
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '%40 tasarruf',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: colors.success,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        pkg.storeProduct.priceString,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Purchase button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _purchasing ? null : _purchase,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _purchasing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Devam Et',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Legal
                  Text(
                    'Abonelik otomatik yenilenir. İstediğin zaman iptal edebilirsin.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureTile({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
          const SizedBox(width: 12),
          Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
