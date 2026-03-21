import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/amount_display.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final int amount;
  final String providerName;

  const PaymentSuccessScreen({
    super.key,
    required this.amount,
    required this.providerName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.horizontalLg,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 96,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Tip Sent!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(child: AmountDisplay(amountPaise: amount, fontSize: 36)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'to $providerName',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Done'),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: () => context.push('/history'),
                child: const Text('View History'),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
