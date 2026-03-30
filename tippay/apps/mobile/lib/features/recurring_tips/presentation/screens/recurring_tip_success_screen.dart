import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

class RecurringTipSuccessScreen extends StatefulWidget {
  final String providerName;
  final int amountPaise;
  final String frequency;

  const RecurringTipSuccessScreen({
    super.key,
    required this.providerName,
    required this.amountPaise,
    required this.frequency,
  });

  @override
  State<RecurringTipSuccessScreen> createState() =>
      _RecurringTipSuccessScreenState();
}

class _RecurringTipSuccessScreenState extends State<RecurringTipSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String get _rupees =>
      '₹${(widget.amountPaise / 100).toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final periodLabel = widget.frequency.toLowerCase();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Animated icon ─────────────────────────────────────────
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.autorenew_rounded,
                      color: Colors.white, size: 56),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Title ─────────────────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    Text(
                      'Recurring tip set up!',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_rupees will be auto-tipped to ${widget.providerName} every $periodLabel.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Info card ─────────────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(
                          icon: Icons.check_circle_outline,
                          text:
                              'Mandate authorized via UPI Autopay'),
                      const SizedBox(height: 8),
                      _InfoRow(
                          icon: Icons.schedule_rounded,
                          text:
                              'First charge on your next $periodLabel cycle'),
                      const SizedBox(height: 8),
                      _InfoRow(
                          icon: Icons.tune_rounded,
                          text:
                              'Manage from "My Recurring Tips" anytime'),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // ── View my tips ──────────────────────────────────────────
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
                    onPressed: () => context.go('/recurring-tips'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('View My Recurring Tips',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Back to Home'),
              ),

              SizedBox(
                  height: MediaQuery.of(context).padding.bottom +
                      AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}
