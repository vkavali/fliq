import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/deferred_tip_model.dart';
import '../../../customer/data/tips_repository.dart';
import '../../data/tip_later_repository.dart';

final _myPromisesProvider = FutureProvider.autoDispose<List<DeferredTipModel>>((ref) async {
  return ref.read(tipLaterRepositoryProvider).getMyDeferredTips();
});

class MyPromisesScreen extends ConsumerStatefulWidget {
  const MyPromisesScreen({super.key});

  @override
  ConsumerState<MyPromisesScreen> createState() => _MyPromisesScreenState();
}

class _MyPromisesScreenState extends ConsumerState<MyPromisesScreen> {
  Razorpay? _razorpay;
  String? _pendingPaymentTipId;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    }
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  Future<void> _payNow(DeferredTipModel deferred) async {
    if (kIsWeb) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payments are not available on web. Please use the mobile app.')));
      return;
    }
    try {
      final result = await ref.read(tipLaterRepositoryProvider).payDeferredTip(deferred.id);

      _pendingPaymentTipId = result['tipId'] as String?;

      final options = {
        'key': result['razorpayKeyId'],
        'amount': result['amountPaise'],
        'currency': 'INR',
        'order_id': result['orderId'],
        'name': 'Fliq',
        'description': 'Tip for ${deferred.providerName ?? "provider"}',
        'prefill': {'contact': '', 'email': ''},
        'theme': {'color': '#6C63FF'},
      };

      _razorpay!.open(options);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      await ref.read(tipsRepositoryProvider).verifyPayment(
            tipId: _pendingPaymentTipId!,
            razorpayOrderId: response.orderId!,
            razorpayPaymentId: response.paymentId!,
            razorpaySignature: response.signature!,
          );
      if (mounted) {
        ref.invalidate(_myPromisesProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tip paid successfully!')));
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

  Future<void> _cancel(DeferredTipModel deferred) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Promise?'),
        content: Text('Cancel your promise of ₹${(deferred.amountPaise / 100).round()} to ${deferred.providerName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Promise', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await ref.read(tipLaterRepositoryProvider).cancelDeferredTip(deferred.id);
        ref.invalidate(_myPromisesProvider);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final promisesAsync = ref.watch(_myPromisesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Promises')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_myPromisesProvider),
        child: promisesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (promises) {
            if (promises.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.handshake_outlined, size: 72, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                    const SizedBox(height: AppSpacing.lg),
                    Text('No Promises Yet', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('Use "Tip Later" to make a payment promise.', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              );
            }

            final pending = promises.where((p) => p.isPending).toList();
            final others = promises.where((p) => !p.isPending).toList();

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (pending.isNotEmpty) ...[
                  _SectionHeader(title: 'Pending (${pending.length})'),
                  ...pending.map((p) => _PromiseCard(
                        promise: p,
                        onPayNow: () => _payNow(p),
                        onCancel: () => _cancel(p),
                      )),
                ],
                if (others.isNotEmpty) ...[
                  _SectionHeader(title: 'Past Promises'),
                  ...others.map((p) => _PromiseCard(promise: p)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
    );
  }
}

class _PromiseCard extends StatelessWidget {
  final DeferredTipModel promise;
  final VoidCallback? onPayNow;
  final VoidCallback? onCancel;

  const _PromiseCard({required this.promise, this.onPayNow, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final amountRupees = (promise.amountPaise / 100).round();
    final isPending = promise.isPending;
    final isCollected = promise.isCollected;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _statusColor(promise.status).withValues(alpha: 0.1),
                  child: Icon(_statusIcon(promise.status), color: _statusColor(promise.status), size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(promise.providerName ?? 'Provider',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(promise.timeRemainingLabel,
                          style: TextStyle(fontSize: 12, color: _statusColor(promise.status))),
                    ],
                  ),
                ),
                Text(
                  '₹$amountRupees',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isPending ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            if (promise.message != null) ...[
              const SizedBox(height: 8),
              Text('"${promise.message}"',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
            ],

            if (isPending) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: onPayNow,
                        child: const Text('Pay Now', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onCancel,
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) => switch (status) {
        'PROMISED' => AppColors.primary,
        'COLLECTED' => AppColors.success,
        'EXPIRED' => AppColors.textSecondary,
        _ => AppColors.textSecondary,
      };

  IconData _statusIcon(String status) => switch (status) {
        'PROMISED' => Icons.handshake_outlined,
        'COLLECTED' => Icons.check_circle_outline,
        'EXPIRED' => Icons.timer_off_outlined,
        _ => Icons.cancel_outlined,
      };
}
