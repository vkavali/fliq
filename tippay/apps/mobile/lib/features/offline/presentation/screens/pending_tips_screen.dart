import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/offline_queue_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/pending_tip_model.dart';

final _pendingTipsProvider = FutureProvider.autoDispose<List<PendingTipModel>>((ref) async {
  return ref.read(offlineQueueServiceProvider).getPendingTips();
});

class PendingTipsScreen extends ConsumerWidget {
  const PendingTipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(_pendingTipsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Tips'),
        actions: [
          pendingAsync.maybeWhen(
            data: (tips) => tips.isNotEmpty
                ? TextButton(
                    onPressed: () => _clearAll(context, ref),
                    child: const Text('Clear All', style: TextStyle(color: Colors.red)),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (tips) {
          if (tips.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 72, color: AppColors.success.withValues(alpha: 0.5)),
                  const SizedBox(height: AppSpacing.lg),
                  Text('No Pending Tips', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('All tips have been processed!', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${tips.length} tip${tips.length != 1 ? "s" : ""} queued while offline. Connect to internet to complete payment.',
                        style: const TextStyle(color: AppColors.warning, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              ...tips.map((tip) => _PendingTipCard(
                    tip: tip,
                    onPayNow: () => _payNow(context, tip),
                    onRemove: () => _remove(context, ref, tip.id),
                  )),
            ],
          );
        },
      ),
    );
  }

  void _payNow(BuildContext context, PendingTipModel tip) {
    // Navigate to tip screen with pre-filled data
    context.push('/tip', extra: {
      'providerId': tip.providerId,
      'providerName': tip.providerName,
      'category': tip.category,
    });
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, String tipId) async {
    await ref.read(offlineQueueServiceProvider).removeTip(tipId);
    ref.invalidate(_pendingTipsProvider);
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Pending Tips?'),
        content: const Text('These queued tips will be discarded.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(offlineQueueServiceProvider).clearQueue();
      ref.invalidate(_pendingTipsProvider);
    }
  }
}

class _PendingTipCard extends StatelessWidget {
  final PendingTipModel tip;
  final VoidCallback onPayNow;
  final VoidCallback onRemove;

  const _PendingTipCard({required this.tip, required this.onPayNow, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.schedule, color: AppColors.warning, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(tip.providerName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Pending', style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${(tip.amountPaise / 100).toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  Text(
                    'Queued ${_timeAgo(tip.queuedAt)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                ElevatedButton(
                  onPressed: onPayNow,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Pay Now', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: onRemove,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Remove', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
