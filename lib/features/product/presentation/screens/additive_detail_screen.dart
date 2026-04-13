import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/additive/domain/entities/additive_entity.dart';
import '../../../../features/additive/presentation/providers/additive_provider.dart';

class AdditiveDetailScreen extends ConsumerWidget {
  final String eCode;

  const AdditiveDetailScreen({super.key, required this.eCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final additiveAsync = ref.watch(additiveByCodeProvider(eCode));

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          eCode.toUpperCase(),
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: additiveAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => _NotFoundBody(eCode: eCode),
        data: (additive) {
          if (additive == null) return _NotFoundBody(eCode: eCode);
          return _AdditiveBody(additive: additive);
        },
      ),
    );
  }
}

class _AdditiveBody extends StatelessWidget {
  final AdditiveEntity additive;

  const _AdditiveBody({required this.additive});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final riskColor = additive.riskColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero Card ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: riskColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.science_outlined,
                    size: 32,
                    color: riskColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  additive.eNumber,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  additive.nameTr ?? additive.nameEn,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                if (additive.nameTr != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    additive.nameEn,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _RiskBadge(
                  riskLevel: additive.riskLevel,
                  riskLabel: additive.riskLabel,
                  color: riskColor,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Description ───────────────────────────────────────────
          if (additive.descriptionTr != null ||
              additive.descriptionEn != null) ...[
            _SectionCard(
              icon: Icons.info_outline,
              title: l10n.description,
              color: colors.primary,
              child: Text(
                additive.descriptionTr ?? additive.descriptionEn ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Category + Status Row ─────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  icon: Icons.category_outlined,
                  label: l10n.category,
                  value: _categoryLabel(additive.category),
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoTile(
                  icon: Icons.shield_outlined,
                  label: 'EFSA',
                  value: _statusLabel(additive.efsaStatus),
                  color: _statusColor(additive.efsaStatus, colors),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  icon: Icons.flag_outlined,
                  label: l10n.turkishCodex,
                  value: _statusLabel(additive.turkishCodexStatus),
                  color: _statusColor(additive.turkishCodexStatus, colors),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoTile(
                  icon: Icons.science,
                  label: l10n.riskLevel,
                  value: '${additive.riskLevel}/5',
                  color: riskColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Dietary Suitability ───────────────────────────────────
          _SectionCard(
            icon: Icons.restaurant_menu_outlined,
            title: l10n.dietarySuitability,
            color: colors.primary,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _DietBadge(
                  label: l10n.vegan,
                  isOk: additive.isVegan,
                  colors: colors,
                ),
                _DietBadge(
                  label: l10n.vegetarian,
                  isOk: additive.isVegetarian,
                  colors: colors,
                ),
                _DietBadge(
                  label: l10n.halal,
                  isOk: additive.isHalal,
                  colors: colors,
                ),
              ],
            ),
          ),

          if (additive.isBanned) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.error.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.block, color: colors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.bannedAdditive,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _categoryLabel(String? category) {
    return switch (category) {
      'colorant' => 'Renklendirici',
      'preservative' => 'Koruyucu',
      'antioxidant' => 'Antioksidan',
      'emulsifier' => 'Emülgatör',
      'thickener' => 'Koyulaştırıcı',
      'sweetener' => 'Tatlandırıcı',
      'flavor_enhancer' => 'Lezzet Artırıcı',
      'acidity_regulator' => 'Asitlik Düzenleyici',
      'anti_caking' => 'Topaklanma Önleyici',
      'bulking_agent' => 'Hacim Artırıcı',
      'modified_starch' => 'Modifiye Nişasta',
      'gelling_agent' => 'Jelleştirici',
      'humectant' => 'Nemlendirici',
      'leavening_agent' => 'Kabartıcı',
      'flour_treatment' => 'Un İyileştirici',
      'glazing_agent' => 'Parlatıcı',
      'packaging_gas' => 'Ambalaj Gazı',
      'firming_agent' => 'Sertleştirici',
      'anti_foaming' => 'Köpük Önleyici',
      'enzyme' => 'Enzim',
      _ => category ?? 'Diğer',
    };
  }

  String _statusLabel(String? status) {
    return switch (status) {
      'approved' => 'Onaylı',
      'restricted' => 'Kısıtlı',
      'banned' => 'Yasaklı',
      'under_review' => 'İnceleniyor',
      _ => 'Bilinmiyor',
    };
  }

  Color _statusColor(String? status, AppColorsExtension colors) {
    return switch (status) {
      'approved' => colors.riskSafe,
      'restricted' => colors.warning,
      'banned' => colors.error,
      _ => colors.textMuted,
    };
  }
}

class _RiskBadge extends StatelessWidget {
  final int riskLevel;
  final String? riskLabel;
  final Color color;

  const _RiskBadge({
    required this.riskLevel,
    required this.riskLabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(
            5,
            (i) => Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Icon(
                Icons.circle,
                size: 8,
                color: i < riskLevel ? color : color.withValues(alpha: 0.25),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            riskLabel ?? 'Risk $riskLevel',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DietBadge extends StatelessWidget {
  final String label;
  final bool isOk;
  final AppColorsExtension colors;

  const _DietBadge({
    required this.label,
    required this.isOk,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOk ? colors.riskSafe : colors.error;
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isOk ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: color,
            size: 22,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _NotFoundBody extends StatelessWidget {
  final String eCode;

  const _NotFoundBody({required this.eCode});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.science_outlined, size: 64, color: colors.textMuted),
          const SizedBox(height: 16),
          Text(
            eCode.toUpperCase(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bu katkı maddesi hakkında bilgi bulunamadı.',
            style: TextStyle(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}
