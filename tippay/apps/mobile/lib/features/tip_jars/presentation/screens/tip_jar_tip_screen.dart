import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/tip_jar_model.dart';
import '../../data/tip_jars_repository.dart';
import '../../../customer/data/tips_repository.dart'; // for verifyPayment

final _resolveJarProvider = FutureProvider.autoDispose.family<TipJarModel, String>((ref, shortCode) {
  return ref.read(tipJarsRepositoryProvider).resolveJar(shortCode);
});

class TipJarTipScreen extends ConsumerStatefulWidget {
  final String shortCode;

  const TipJarTipScreen({super.key, required this.shortCode});

  @override
  ConsumerState<TipJarTipScreen> createState() => _TipJarTipScreenState();
}

class _TipJarTipScreenState extends ConsumerState<TipJarTipScreen> {
  int _selectedAmountRupees = 50;
  bool _isCustom = false;
  final _customController = TextEditingController();
  final _messageController = TextEditingController();
  int _rating = 0;
  bool _isLoading = false;
  late Razorpay _razorpay;
  String? _currentTipId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _customController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  int get _amountPaise {
    if (_isCustom) return (int.tryParse(_customController.text) ?? 0) * 100;
    return _selectedAmountRupees * 100;
  }

  double get _commissionPercent => (_amountPaise / 100) > 100 ? 5.0 : 0.0;
  int get _feePaise => (_amountPaise * _commissionPercent / 100).round();

  Future<void> _startPayment(TipJarModel jar) async {
    if (_amountPaise < AppConstants.minTipPaise || _amountPaise > AppConstants.maxTipPaise) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Amount must be between ₹1 and ₹1,00,000')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final isLoggedIn = ref.read(authServiceProvider).isLoggedIn;
      final result = await ref.read(tipJarsRepositoryProvider).createJarTip(
            shortCode: widget.shortCode,
            amountPaise: _amountPaise,
            message: _messageController.text.isEmpty ? null : _messageController.text,
            rating: _rating > 0 ? _rating : null,
            authenticated: isLoggedIn,
          );

      _currentTipId = result['tipId'] as String?;

      final options = {
        'key': result['razorpayKeyId'],
        'amount': result['amount'],
        'currency': result['currency'] ?? 'INR',
        'order_id': result['orderId'],
        'name': 'Fliq',
        'description': 'Tip for ${jar.name}',
        'prefill': {'contact': '', 'email': ''},
        'theme': {'color': '#6C63FF'},
      };

      _razorpay.open(options);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start payment: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final repo = ref.read(tipsRepositoryProvider);
      await repo.verifyPayment(
        tipId: _currentTipId!,
        razorpayOrderId: response.orderId!,
        razorpayPaymentId: response.paymentId!,
        razorpaySignature: response.signature!,
      );
      if (mounted) {
        context.go('/payment-success', extra: {
          'amount': _amountPaise,
          'providerName': ref.read(_resolveJarProvider(widget.shortCode)).valueOrNull?.name ?? 'Tip Jar',
          'rating': _rating,
          'message': _messageController.text,
          'fee': _feePaise,
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification failed: $e')));
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Payment failed: ${response.message ?? "Unknown error"}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final jarAsync = ref.watch(_resolveJarProvider(widget.shortCode));

    return Scaffold(
      appBar: AppBar(title: const Text('Tip the Jar')),
      body: jarAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (jar) => Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Jar info card ────────────────────────────────
                    _JarInfoCard(jar: jar),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Amount display ───────────────────────────────
                    Center(
                      child: Text(
                        '₹${(_amountPaise / 100).round()}',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ── Preset chips ─────────────────────────────────
                    Center(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          ...AppConstants.presetTipAmounts.map((amt) => _AmountChip(
                                label: '₹$amt',
                                isSelected: !_isCustom && _selectedAmountRupees == amt,
                                onTap: () => setState(() {
                                  _isCustom = false;
                                  _selectedAmountRupees = amt;
                                }),
                              )),
                          _AmountChip(
                            label: 'Custom',
                            isSelected: _isCustom,
                            onTap: () => setState(() => _isCustom = true),
                          ),
                        ],
                      ),
                    ),

                    if (_isCustom) ...[
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _customController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Enter amount'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.md),

                    // ── Commission info ──────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _commissionPercent > 0
                            ? AppColors.warning.withValues(alpha: 0.08)
                            : AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _commissionPercent > 0
                            ? 'Platform fee: ₹${(_feePaise / 100).round()} (${_commissionPercent.toStringAsFixed(0)}%)'
                            : 'No platform fee (₹100 or less)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _commissionPercent > 0 ? AppColors.warning : AppColors.success,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ── Star rating ──────────────────────────────────
                    Text('Rate your experience', textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        return GestureDetector(
                          onTap: () => setState(() => _rating = i + 1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              i < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                              color: i < _rating ? Colors.amber : Colors.grey.shade400,
                              size: 38,
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // ── Message ──────────────────────────────────────
                    TextFormField(
                      controller: _messageController,
                      maxLines: 2,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        hintText: 'Add a message (optional)',
                        counterText: '',
                        prefixIcon: Icon(Icons.message_outlined, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Pay button ───────────────────────────────────────────
            Container(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.md,
                bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -4))],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _startPayment(jar),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Text(
                            'Tip ₹${(_amountPaise / 100).round()} to ${jar.name}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JarInfoCard extends StatelessWidget {
  final TipJarModel jar;
  const _JarInfoCard({required this.jar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Icon(_eventIcon(jar.eventType), color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(jar.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text(jar.eventTypeLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          if (jar.description != null) ...[
            const SizedBox(height: 8),
            Text(jar.description!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          Text('${jar.members.length} recipient${jar.members.length != 1 ? "s" : ""}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: jar.members.map((m) => _MemberChip(member: m)).toList(),
          ),
        ],
      ),
    );
  }

  IconData _eventIcon(String eventType) => switch (eventType) {
        'WEDDING' => Icons.favorite,
        'RESTAURANT' => Icons.restaurant,
        'SALON' => Icons.content_cut,
        'EVENT' => Icons.celebration,
        _ => Icons.inventory_2_outlined,
      };
}

class _MemberChip extends StatelessWidget {
  final TipJarMemberModel member;
  const _MemberChip({required this.member});

  @override
  Widget build(BuildContext context) {
    final name = member.providerName ?? 'Member';
    final pct = member.splitPercentage.toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$name · $pct%', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
    );
  }
}

class _AmountChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _AmountChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.divider, width: isSelected ? 2 : 1),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
      ),
    );
  }
}
