import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/onboarding_provider.dart';
import 'provider_registration_screen.dart' show OnboardingProgress;

class KycStatusScreen extends ConsumerWidget {
  const KycStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final theme = Theme.of(context);
    final kycStatus = state.kycStatus;

    final (statusIcon, statusColor, statusTitle, statusDesc) = switch (kycStatus) {
      'FULL' => (
          Icons.verified,
          AppColors.success,
          'Fully Verified',
          'Your identity has been fully verified. You can receive tips without any limits.',
        ),
      'BASIC' => (
          Icons.verified_user_outlined,
          AppColors.warning,
          'Basic Verification',
          'Basic verification is complete. Submit additional documents to unlock higher tip limits.',
        ),
      _ => (
          Icons.hourglass_top,
          AppColors.primary,
          'Verification Pending',
          'Your documents are under review. This usually takes 1–2 business days. You can still receive tips while we verify your account.',
        ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('KYC Verification'),
        leading: BackButton(onPressed: () => context.go('/onboarding/bank-details')),
      ),
      body: Padding(
        padding: AppSpacing.horizontalLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.lg),
            OnboardingProgress(step: 3, total: 4),
            const SizedBox(height: AppSpacing.xl),

            Text(
              'Verification Status',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Status card
            Container(
              width: double.infinity,
              padding: AppSpacing.paddingLg,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                children: [
                  Icon(statusIcon, color: statusColor, size: 56),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    statusTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    statusDesc,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // What happens next
            Text(
              'What happens next?',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.md),
            _StepRow(
              icon: Icons.qr_code,
              text: 'Generate your QR code to start receiving tips',
            ),
            _StepRow(
              icon: Icons.share,
              text: 'Share your QR code or payment link with customers',
            ),
            _StepRow(
              icon: Icons.account_balance,
              text: 'Request payouts once your wallet balance builds up',
            ),

            const Spacer(),

            ElevatedButton(
              onPressed: () {
                ref.read(onboardingProvider.notifier).proceedFromKyc();
                context.go('/onboarding/qr');
              },
              child: const Text('Generate My QR Code'),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StepRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
