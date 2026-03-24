import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final int amount;
  final String providerName;
  final int rating;
  final String message;
  final int fee;

  const PaymentSuccessScreen({
    super.key,
    required this.amount,
    required this.providerName,
    this.rating = 0,
    this.message = '',
    this.fee = 0,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen>
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

  String get _rupees => (widget.amount / 100).toStringAsFixed(0);
  String get _feeRupees => (widget.fee / 100).toStringAsFixed(0);

  Future<void> _share() async {
    final text = Uri.encodeComponent(
        'I just tipped \u20B9$_rupees on Fliq! Reward great service easily. Check it out: https://fliq.in');
    final uri = Uri.parse('https://wa.me/?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Animated checkmark ─────────────────────────────────────
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 56),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Title ──────────────────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    Text(
                      '\u20B9$_rupees sent to',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.providerName,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Details card ───────────────────────────────────────────
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
                    children: [
                      _DetailRow(label: 'Amount', value: '\u20B9$_rupees'),
                      if (widget.fee > 0) ...[
                        const Divider(height: 20),
                        _DetailRow(
                            label: 'Platform Fee',
                            value: '\u20B9$_feeRupees'),
                      ],
                      if (widget.rating > 0) ...[
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Rating',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14)),
                            Row(
                              children: List.generate(5, (i) {
                                return Icon(
                                  i < widget.rating
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  size: 20,
                                  color: i < widget.rating
                                      ? Colors.amber
                                      : Colors.grey.shade300,
                                );
                              }),
                            ),
                          ],
                        ),
                      ],
                      if (widget.message.isNotEmpty) ...[
                        const Divider(height: 20),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Message',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(widget.message,
                                  style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // ── Share button ────────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Tell a friend about Fliq'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: AppColors.divider),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Back to Home ────────────────────────────────────────────
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
                    onPressed: () => context.go('/home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Back to Home',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              TextButton(
                onPressed: () => context.push('/history'),
                child: const Text('View History'),
              ),

              SizedBox(
                  height: MediaQuery.of(context).padding.bottom + AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail row helper
// ---------------------------------------------------------------------------

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
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      ],
    );
  }
}
