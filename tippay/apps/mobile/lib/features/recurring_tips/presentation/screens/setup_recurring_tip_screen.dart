import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/recurring_tips_repository.dart';

class SetupRecurringTipScreen extends ConsumerStatefulWidget {
  final String providerId;
  final String providerName;
  final int initialAmountPaise;

  const SetupRecurringTipScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    this.initialAmountPaise = 10000,
  });

  @override
  ConsumerState<SetupRecurringTipScreen> createState() =>
      _SetupRecurringTipScreenState();
}

class _SetupRecurringTipScreenState
    extends ConsumerState<SetupRecurringTipScreen> {
  RecurringTipFrequency _frequency = RecurringTipFrequency.monthly;
  int _selectedAmountPaise = 10000;
  bool _isLoading = false;

  static const List<int> _presetAmounts = [5000, 10000, 20000, 50000, 100000];

  String _rupees(int paise) => '₹${(paise / 100).toStringAsFixed(0)}';

  @override
  void initState() {
    super.initState();
    _selectedAmountPaise = widget.initialAmountPaise;
  }

  Future<void> _setup() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(recurringTipsRepositoryProvider);
      final result = await repo.createRecurringTip(
        providerId: widget.providerId,
        amountPaise: _selectedAmountPaise,
        frequency: _frequency,
      );

      // Open Razorpay authorization URL for UPI Autopay mandate
      final uri = Uri.parse(result.authorizationUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      if (!mounted) return;
      context.push('/recurring-tips/success', extra: {
        'providerName': widget.providerName,
        'amountPaise': _selectedAmountPaise,
        'frequency': _frequency == RecurringTipFrequency.monthly ? 'Monthly' : 'Weekly',
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('already exists')
                ? 'You already have an active recurring tip for this provider.'
                : 'Failed to set up recurring tip. Please try again.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _frequency == RecurringTipFrequency.monthly
        ? _rupees(_selectedAmountPaise)
        : _rupees(_selectedAmountPaise);
    final periodLabel =
        _frequency == RecurringTipFrequency.monthly ? 'month' : 'week';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Up Recurring Tip'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),

              // ── Provider name ───────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.autorenew_rounded,
                        size: 48, color: AppColors.primary),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Auto-tip ${widget.providerName}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Set up a recurring UPI Autopay mandate.\nYou can pause or cancel anytime.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Frequency selector ──────────────────────────────────────
              Text('Frequency',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _FrequencyChip(
                      label: 'Monthly',
                      icon: Icons.calendar_month_rounded,
                      selected: _frequency == RecurringTipFrequency.monthly,
                      onTap: () => setState(
                          () => _frequency = RecurringTipFrequency.monthly),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _FrequencyChip(
                      label: 'Weekly',
                      icon: Icons.calendar_view_week_rounded,
                      selected: _frequency == RecurringTipFrequency.weekly,
                      onTap: () => setState(
                          () => _frequency = RecurringTipFrequency.weekly),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Amount selector ─────────────────────────────────────────
              Text('Amount per $periodLabel',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _presetAmounts.map((amount) {
                  final selected = _selectedAmountPaise == amount;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedAmountPaise = amount),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.divider,
                        ),
                      ),
                      child: Text(
                        _rupees(amount),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Summary card ────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Summary',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: AppColors.primary)),
                    const SizedBox(height: AppSpacing.sm),
                    _SummaryRow(
                      label: 'Provider',
                      value: widget.providerName,
                    ),
                    _SummaryRow(
                      label: 'Amount',
                      value: '$total / $periodLabel',
                    ),
                    _SummaryRow(
                      label: 'Frequency',
                      value: _frequency == RecurringTipFrequency.monthly
                          ? 'Monthly'
                          : 'Weekly',
                    ),
                    _SummaryRow(
                      label: 'Payment',
                      value: 'UPI Autopay',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Info text ───────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'You will be redirected to authorize the UPI Autopay mandate. '
                      'The tip will be sent automatically every $periodLabel. '
                      'Cancel anytime from "My Recurring Tips".',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── CTA button ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _setup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Authorize $total / $periodLabel',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ),

              SizedBox(
                  height:
                      MediaQuery.of(context).padding.bottom + AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _FrequencyChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FrequencyChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? Colors.white : AppColors.textSecondary,
                size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
