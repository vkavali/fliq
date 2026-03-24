import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/tips_repository.dart';

class TipAmountScreen extends ConsumerStatefulWidget {
  final String providerId;
  final String providerName;
  final String category;

  const TipAmountScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.category,
  });

  @override
  ConsumerState<TipAmountScreen> createState() => _TipAmountScreenState();
}

class _TipAmountScreenState extends ConsumerState<TipAmountScreen> {
  int _selectedAmountRupees = 50;
  final _customController = TextEditingController();
  bool _isCustom = false;
  bool _isLoading = false;
  final _messageController = TextEditingController();
  int _rating = 0;
  late Razorpay _razorpay;
  String? _currentTipId;
  String? _providerUpiVpa;
  bool _loadingVpa = true;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _fetchProviderVpa();
  }

  Future<void> _fetchProviderVpa() async {
    try {
      final repo = ref.read(tipsRepositoryProvider);
      final data = await repo.getProviderPublic(widget.providerId);
      if (mounted) {
        setState(() {
          _providerUpiVpa = data['upiVpa'] as String?;
          _loadingVpa = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingVpa = false);
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    _customController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  int get _amountPaise {
    if (_isCustom) {
      final rupees = int.tryParse(_customController.text) ?? 0;
      return rupees * 100;
    }
    return _selectedAmountRupees * 100;
  }

  int get _amountRupees => (_amountPaise / 100).round();

  // Commission: 0% for <= Rs 100, 5% for > Rs 100
  double get _commissionPercent => _amountRupees > 100 ? 5.0 : 0.0;
  int get _feePaise => (_amountPaise * _commissionPercent / 100).round();
  int get _feeRupees => (_feePaise / 100).round();

  // ---------- Payment flow ----------

  Future<void> _startPayment() async {
    if (_amountPaise < AppConstants.minTipPaise ||
        _amountPaise > AppConstants.maxTipPaise) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Amount must be between \u20B910 and \u20B910,000')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(tipsRepositoryProvider);
      final result = await repo.createTip(
        providerId: widget.providerId,
        amountPaise: _amountPaise,
        source: 'QR_CODE',
        message:
            _messageController.text.isEmpty ? null : _messageController.text,
        rating: _rating > 0 ? _rating : null,
      );

      _currentTipId = result.tipId;

      final options = {
        'key': result.razorpayKeyId,
        'amount': result.amount,
        'currency': result.currency,
        'order_id': result.orderId,
        'name': 'Fliq',
        'description': 'Tip for ${widget.providerName}',
        'prefill': {
          'contact': '',
          'email': '',
        },
        'theme': {'color': '#6C63FF'},
      };

      _razorpay.open(options);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create tip: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
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
          'providerName': widget.providerName,
          'rating': _rating,
          'message': _messageController.text,
          'fee': _feePaise,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e')),
        );
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('Payment failed: ${response.message ?? "Unknown error"}')),
    );
  }

  // ---------- UPI Intent flow ----------

  Future<void> _launchUpiApp(String appPackage) async {
    if (_amountPaise < AppConstants.minTipPaise ||
        _amountPaise > AppConstants.maxTipPaise) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Amount must be between \u20B910 and \u20B910,000')),
      );
      return;
    }

    if (_providerUpiVpa == null || _providerUpiVpa!.isEmpty) {
      // Fallback to Razorpay checkout
      _startPayment();
      return;
    }

    final amountStr = (_amountPaise / 100).toStringAsFixed(2);
    final upiUrl = Uri.parse(
      'upi://pay?pa=${Uri.encodeComponent(_providerUpiVpa!)}'
      '&pn=${Uri.encodeComponent(widget.providerName)}'
      '&am=$amountStr'
      '&cu=INR'
      '&tn=${Uri.encodeComponent('Tip via Fliq')}',
    );

    try {
      final launched = await launchUrl(
        upiUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open UPI app. Using Razorpay instead.')),
        );
        _startPayment();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('UPI app not available. Using Razorpay instead.')),
        );
        _startPayment();
      }
    }
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final rupeeDisplay = _amountRupees;

    return Scaffold(
      appBar: AppBar(title: const Text('Send Tip')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.md),

                  // ── Provider info card ─────────────────────────────────
                  _ProviderInfoCard(
                    name: widget.providerName,
                    category: widget.category,
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Amount display ─────────────────────────────────────
                  Center(
                    child: Text(
                      '\u20B9$rupeeDisplay',
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ── Preset amount chips ────────────────────────────────
                  Center(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        ...AppConstants.presetTipAmounts.map(
                          (amount) => _AmountChip(
                            label: '\u20B9$amount',
                            isSelected:
                                !_isCustom && _selectedAmountRupees == amount,
                            onTap: () => setState(() {
                              _isCustom = false;
                              _selectedAmountRupees = amount;
                            }),
                          ),
                        ),
                        _AmountChip(
                          label: 'Custom',
                          isSelected: _isCustom,
                          onTap: () => setState(() => _isCustom = true),
                        ),
                      ],
                    ),
                  ),

                  // ── Custom amount input ────────────────────────────────
                  if (_isCustom) ...[
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _customController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        prefixText: '\u20B9 ',
                        hintText: 'Enter amount',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // ── Commission breakdown ───────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: _commissionPercent > 0
                          ? AppColors.warning.withValues(alpha: 0.08)
                          : AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _commissionPercent > 0
                              ? Icons.info_outline
                              : Icons.check_circle_outline,
                          size: 18,
                          color: _commissionPercent > 0
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _commissionPercent > 0
                              ? 'Fee: \u20B9$_feeRupees (${_commissionPercent.toStringAsFixed(0)}%)'
                              : 'Fee: \u20B90 (0%)',
                          style: TextStyle(
                            color: _commissionPercent > 0
                                ? AppColors.warning
                                : AppColors.success,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Star rating ────────────────────────────────────────
                  Text('Rate your experience',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          )),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final isSelected = i < _rating;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = i + 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                            color: isSelected ? Colors.amber : Colors.grey.shade400,
                            size: 40,
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ── Message ────────────────────────────────────────────
                  TextFormField(
                    controller: _messageController,
                    maxLength: 500,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Add a message (optional)',
                      counterText: '',
                      prefixIcon: Icon(Icons.message_outlined, size: 20),
                    ),
                  ),

                  // ── UPI quick-pay icons ────────────────────────────────
                  if (!_loadingVpa && _providerUpiVpa != null && _providerUpiVpa!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text('Pay directly with UPI',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            )),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _UpiAppButton(
                          label: 'GPay',
                          icon: Icons.g_mobiledata,
                          color: const Color(0xFF4285F4),
                          onTap: () => _launchUpiApp('com.google.android.apps.nbu.paisa.user'),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _UpiAppButton(
                          label: 'PhonePe',
                          icon: Icons.phone_android,
                          color: const Color(0xFF5F259F),
                          onTap: () => _launchUpiApp('com.phonepe.app'),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _UpiAppButton(
                          label: 'Paytm',
                          icon: Icons.account_balance_wallet,
                          color: const Color(0xFF00BAF2),
                          onTap: () => _launchUpiApp('net.one97.paytm'),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _UpiAppButton(
                          label: 'Other',
                          icon: Icons.open_in_new,
                          color: AppColors.textSecondary,
                          onTap: () => _launchUpiApp(''),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),

          // ── Pay button (sticky bottom) ─────────────────────────────
          Container(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.md,
              bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _startPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(
                          'Pay \u20B9$rupeeDisplay',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider Info Card
// ---------------------------------------------------------------------------

class _ProviderInfoCard extends StatelessWidget {
  final String name;
  final String category;

  const _ProviderInfoCard({required this.name, required this.category});

  IconData get _categoryIcon => switch (category.toUpperCase()) {
        'DELIVERY' => Icons.delivery_dining,
        'SALON' => Icons.content_cut,
        'RESTAURANT' => Icons.restaurant,
        'HOTEL' => Icons.hotel,
        'HOUSEHOLD' => Icons.home_repair_service,
        _ => Icons.person,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Icon(_categoryIcon, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified, color: AppColors.success, size: 22),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pill-shaped amount chip with animated selection
// ---------------------------------------------------------------------------

class _AmountChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AmountChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// UPI App Button
// ---------------------------------------------------------------------------

class _UpiAppButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _UpiAppButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
