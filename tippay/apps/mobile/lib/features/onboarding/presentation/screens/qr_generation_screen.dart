import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/onboarding_provider.dart';
import 'provider_registration_screen.dart' show _OnboardingProgress;

class QrGenerationScreen extends ConsumerStatefulWidget {
  const QrGenerationScreen({super.key});

  @override
  ConsumerState<QrGenerationScreen> createState() => _QrGenerationScreenState();
}

class _QrGenerationScreenState extends ConsumerState<QrGenerationScreen> {
  final _locationCtrl = TextEditingController();
  bool _generated = false;

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  void _generate() {
    ref.read(onboardingProvider.notifier).generateQrCode(
          locationLabel: _locationCtrl.text.trim().isEmpty
              ? null
              : _locationCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final theme = Theme.of(context);

    ref.listen(onboardingProvider, (_, next) {
      if (next.status == OnboardingStatus.success &&
          next.step == OnboardingStep.success) {
        setState(() => _generated = true);
      } else if (next.status == OnboardingStatus.error && next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your QR Code'),
        leading: BackButton(onPressed: () => context.go('/onboarding/kyc')),
      ),
      body: Padding(
        padding: AppSpacing.horizontalLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.lg),
            _OnboardingProgress(step: 4, total: 4),
            const SizedBox(height: AppSpacing.xl),

            Text(
              'Generate Your QR Code',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Customers scan this QR to tip you instantly.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),

            if (!_generated) ...[
              // Location label input
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Location Label (optional)',
                  hintText: 'e.g. Table 5, Front Desk…',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              ElevatedButton.icon(
                onPressed:
                    state.status == OnboardingStatus.loading ? null : _generate,
                icon: state.status == OnboardingStatus.loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.qr_code),
                label: Text(state.status == OnboardingStatus.loading
                    ? 'Generating…'
                    : 'Generate QR Code'),
              ),
            ] else ...[
              // Show generated QR
              Center(
                child: Column(
                  children: [
                    if (state.qrImageUrl != null &&
                        state.qrImageUrl!.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: QrImageView(
                          data: state.qrImageUrl!,
                          version: QrVersions.auto,
                          size: 200,
                        ),
                      )
                    else
                      Container(
                        padding: AppSpacing.paddingLg,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                          size: 72,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'QR Code Ready!',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: () => context.go('/onboarding/success'),
                child: const Text('Continue'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
