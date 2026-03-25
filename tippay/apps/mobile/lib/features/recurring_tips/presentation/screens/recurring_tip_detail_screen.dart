import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/recurring_tips_repository.dart';
import '../providers/recurring_tips_provider.dart';

class RecurringTipDetailScreen extends ConsumerWidget {
  final RecurringTip tip;

  const RecurringTipDetailScreen({super.key, required this.tip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recurringTipsProvider);
    // Use the latest version from state if available
    final current = state.tips.firstWhere(
      (t) => t.id == tip.id,
      orElse: () => tip,
    );

    final rupees = '₹${(current.amountPaise / 100).toStringAsFixed(0)}';
    final notifier = ref.read(recurringTipsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Tip'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.autorenew_rounded,
                          color: AppColors.primary, size: 40),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      current.providerName ?? 'Service Provider',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$rupees / ${current.frequencyLabel.toLowerCase()}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _StatusBadge(status: current.status),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Details card ────────────────────────────────────────────
              _DetailsCard(tip: current),

              const SizedBox(height: AppSpacing.xl),

              // ── Actions ─────────────────────────────────────────────────
              if (current.isManageable) ...[
                Text('Manage',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),

                if (current.status == RecurringTipStatus.active)
                  _ActionButton(
                    icon: Icons.pause_circle_outline_rounded,
                    label: 'Pause',
                    color: Colors.orange,
                    onTap: () async {
                      final ok = await notifier.pause(current.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok
                              ? 'Recurring tip paused'
                              : 'Failed to pause'),
                          backgroundColor:
                              ok ? AppColors.success : AppColors.error,
                        ),
                      );
                    },
                  ),

                if (current.status == RecurringTipStatus.paused)
                  _ActionButton(
                    icon: Icons.play_circle_outline_rounded,
                    label: 'Resume',
                    color: AppColors.success,
                    onTap: () async {
                      final ok = await notifier.resume(current.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok
                              ? 'Recurring tip resumed'
                              : 'Failed to resume'),
                          backgroundColor:
                              ok ? AppColors.success : AppColors.error,
                        ),
                      );
                    },
                  ),

                const SizedBox(height: AppSpacing.sm),

                _ActionButton(
                  icon: Icons.cancel_outlined,
                  label: 'Cancel Recurring Tip',
                  color: AppColors.error,
                  onTap: () => _confirmCancel(context, current, notifier),
                ),
              ],

              SizedBox(
                  height: MediaQuery.of(context).padding.bottom +
                      AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    RecurringTip tip,
    RecurringTipsNotifier notifier,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel recurring tip?'),
        content: const Text(
            'This will permanently cancel the UPI Autopay mandate. '
            'No further charges will be made.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel mandate'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final ok = await notifier.cancel(tip.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(ok ? 'Recurring tip cancelled' : 'Failed to cancel'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
    if (ok) context.pop();
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final RecurringTipStatus status;
  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case RecurringTipStatus.active:
        return AppColors.success;
      case RecurringTipStatus.paused:
        return Colors.orange;
      case RecurringTipStatus.pendingAuthorization:
        return Colors.blue;
      default:
        return AppColors.textSecondary;
    }
  }

  String get _label {
    switch (status) {
      case RecurringTipStatus.active:
        return 'Active';
      case RecurringTipStatus.paused:
        return 'Paused';
      case RecurringTipStatus.pendingAuthorization:
        return 'Awaiting Authorization';
      case RecurringTipStatus.cancelled:
        return 'Cancelled';
      case RecurringTipStatus.halted:
        return 'Halted';
      case RecurringTipStatus.completed:
        return 'Completed';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label,
        style: TextStyle(
            color: _color, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

// ── Details card ──────────────────────────────────────────────────────────────

class _DetailsCard extends StatelessWidget {
  final RecurringTip tip;
  const _DetailsCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          _DetailRow(
            label: 'Frequency',
            value: tip.frequencyLabel,
          ),
          const Divider(height: 20),
          _DetailRow(
            label: 'Started',
            value: dateFormat.format(tip.createdAt),
          ),
          if (tip.nextChargeDate != null &&
              tip.status == RecurringTipStatus.active) ...[
            const Divider(height: 20),
            _DetailRow(
              label: 'Next charge',
              value: dateFormat.format(tip.nextChargeDate!),
            ),
          ],
          const Divider(height: 20),
          _DetailRow(
            label: 'Total payments',
            value: tip.totalCharges.toString(),
          ),
          const Divider(height: 20),
          _DetailRow(
            label: 'Total sent',
            value:
                '₹${((tip.amountPaise * tip.totalCharges) / 100).toStringAsFixed(0)}',
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 14)),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 20),
        label: Text(label, style: TextStyle(color: color)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
