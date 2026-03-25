import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/scan_history_local_datasource.dart';
import '../providers/history_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final historyAsync = ref.watch(scanHistoryProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(l10n.scanHistory),
        backgroundColor: Colors.transparent,
      ),
      body: historyAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.colors.primary),
        ),
        error: (error, _) => Center(
          child: Text(
            'Gecmis yuklenemedi',
            style: TextStyle(color: context.colors.textMuted),
          ),
        ),
        data: (history) {
          if (history.isEmpty) {
            return _buildEmpty(context, l10n);
          }
          return _buildList(context, history);
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, dynamic l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: context.colors.surfaceCard,
              shape: BoxShape.circle,
              border: Border.all(color: context.colors.border),
            ),
            child: Icon(
              Icons.history_rounded,
              size: 44,
              color: context.colors.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.noHistoryYet,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.productsWillAppearHere,
            style: TextStyle(
              fontSize: 14,
              color: context.colors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<ScanHistoryWithProduct> history,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = history[index];
        return _HistoryTile(item: item);
      },
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  final ScanHistoryWithProduct item;

  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'tr');
    final displayName = item.productName ?? item.barcode;
    final subtitle = item.brands ?? item.barcode;

    return GestureDetector(
      onLongPress: () => _showContextMenu(context, ref),
      onTap: () => context.push('/product/${item.barcode}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.colors.border.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Product image or placeholder
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: context.colors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: item.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.inventory_2_outlined,
                          color: context.colors.textMuted,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.inventory_2_outlined,
                      color: context.colors.textMuted,
                    ),
            ),
            const SizedBox(width: 12),

            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(item.scannedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textMuted.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            // HP Score badge
            if (item.hpScoreAtScan != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      _scoreColor(item.hpScoreAtScan!).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.hpScoreAtScan!.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _scoreColor(item.hpScoreAtScan!),
                  ),
                ),
              ),
            ],

            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: context.colors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Delete
              ListTile(
                leading: Icon(Icons.delete_outline_rounded,
                    color: context.colors.error),
                title: Text(
                  l10n.delete,
                  style: TextStyle(color: context.colors.error),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleDelete(context, ref);
                },
              ),

              // Add to Favorites
              ListTile(
                leading: const Icon(Icons.favorite_rounded,
                    color: Color(0xFFE91E63)),
                title: Text(l10n.addToFavorites),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleAddToFavorites(context, ref);
                },
              ),

              // Edit
              ListTile(
                leading: Icon(Icons.edit_rounded,
                    color: context.colors.primary),
                title: Text(l10n.edit),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleEdit(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleDelete(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    deleteScanFromHistory(ref, item.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.deletedFromHistory),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleAddToFavorites(
      BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;

    // Check if already in favorites
    final isFav = await ref.read(isFavoriteProvider(item.barcode).future);
    if (!context.mounted) return;

    if (isFav) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.alreadyInFavorites),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final success = await addToFavorites(ref, barcode: item.barcode);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? l10n.addedToFavorites : l10n.saveFailed),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleEdit(BuildContext context) {
    context.push('/product/${item.barcode}/edit');
  }

  Color _scoreColor(double score) {
    if (score >= 70) return const Color(0xFF4CAF50);
    if (score >= 40) return const Color(0xFFFFC107);
    return const Color(0xFFF44336);
  }
}
