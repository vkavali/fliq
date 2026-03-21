import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/amount_display.dart';
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
    if (_isCustom) {
      final rupees = int.tryParse(_customController.text) ?? 0;
      return rupees * 100;
    }
    return _selectedAmountRupees * 100;
  }

  Future<void> _startPayment() async {
    if (_amountPaise < AppConstants.minTipPaise || _amountPaise > AppConstants.maxTipPaise) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be between \u20B910 and \u20B910,000')),
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
        message: _messageController.text.isEmpty ? null : _messageController.text,
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
      SnackBar(content: Text('Payment failed: ${response.message ?? "Unknown error"}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Tip')),
      body: SingleChildScrollView(
        padding: AppSpacing.horizontalLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            // Provider info
            Card(
              child: Padding(
                padding: AppSpacing.paddingMd,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        widget.providerName.isNotEmpty ? widget.providerName[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.providerName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            )),
                        Text(widget.category,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Amount display
            Center(child: AmountDisplay(amountPaise: _amountPaise, fontSize: 40)),
            const SizedBox(height: AppSpacing.lg),

            // Preset amounts
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ...AppConstants.presetTipAmounts.map((amount) => ChoiceChip(
                  label: Text('\u20B9$amount'),
                  selected: !_isCustom && _selectedAmountRupees == amount,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _isCustom = false;
                        _selectedAmountRupees = amount;
                      });
                    }
                  },
                )),
                ChoiceChip(
                  label: const Text('Custom'),
                  selected: _isCustom,
                  onSelected: (selected) {
                    setState(() => _isCustom = selected);
                  },
                ),
              ],
            ),

            if (_isCustom) ...[
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _customController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  prefixText: '\u20B9 ',
                  hintText: 'Enter amount',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

            // Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return IconButton(
                  onPressed: () => setState(() => _rating = i + 1),
                  icon: Icon(
                    i < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.md),

            // Message
            TextFormField(
              controller: _messageController,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Add a message (optional)',
                counterText: '',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Pay button
            ElevatedButton(
              onPressed: _isLoading ? null : _startPayment,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Pay \u20B9${(_amountPaise / 100).toStringAsFixed(0)}'),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
