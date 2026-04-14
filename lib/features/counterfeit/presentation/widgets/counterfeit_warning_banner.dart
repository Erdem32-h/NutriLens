import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/counterfeit_entity.dart';
import '../providers/counterfeit_provider.dart';

/// Shows a prominent red warning banner when the scanned product appears on
/// the Turkish Ministry of Agriculture's counterfeit/adulterated products list.
class CounterfeitWarningBanner extends ConsumerWidget {
  final String barcode;
  final String? brand;

  const CounterfeitWarningBanner({
    super.key,
    required this.barcode,
    this.brand,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkAsync = ref.watch(
      counterfeitCheckProvider((barcode: barcode, brand: brand)),
    );

    return checkAsync.maybeWhen(
      data: (entity) {
        if (entity == null) return const SizedBox.shrink();
        return _CounterfeitBanner(entity: entity);
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _CounterfeitBanner extends StatelessWidget {
  final CounterfeitEntity entity;

  const _CounterfeitBanner({required this.entity});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFD32F2F).withValues(alpha: 0.12),
              const Color(0xFFB71C1C).withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD32F2F).withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                const Icon(
                  Icons.gpp_bad_rounded,
                  color: Color(0xFFD32F2F),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.counterfeitWarningTitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD32F2F),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Brand + violation
            Text(
              '${entity.brandName} — ${entity.violationType}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),

            if (entity.violationDetail != null) ...[
              const SizedBox(height: 4),
              Text(
                entity.violationDetail!,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],

            if (entity.province != null || entity.detectionDate != null) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  if (entity.province != null)
                    _InfoChip(
                      icon: Icons.location_on_outlined,
                      label: entity.province!,
                    ),
                  if (entity.detectionDate != null)
                    _InfoChip(
                      icon: Icons.calendar_today_outlined,
                      label: _formatDate(entity.detectionDate!),
                    ),
                ],
              ),
            ],

            // Source link
            if (entity.sourceUrl != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _openSource(entity.sourceUrl!),
                child: Text(
                  l10n.counterfeitViewSource,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFD32F2F),
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  Future<void> _openSource(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFFD32F2F)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFD32F2F),
            ),
          ),
        ],
      ),
    );
  }
}
