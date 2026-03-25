import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// Shown after a successful Aadhaar eKYC verification.
/// Displays the pre-filled profile data so the user can confirm before
/// proceeding to the provider dashboard.
class EkycSuccessScreen extends StatelessWidget {
  final String name;
  final String dob;
  final String gender;
  final String address;

  const EkycSuccessScreen({
    super.key,
    required this.name,
    required this.dob,
    required this.gender,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // ── Success animation / icon ──────────────────────────────
              Container(
                width: 90,
                height: 90,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user_rounded,
                    size: 52, color: AppColors.success),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Identity Verified!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your profile has been pre-filled from Aadhaar.\n'
                'You can update these details anytime.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Pre-filled profile card ───────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    _ProfileRow(label: 'Name', value: name),
                    const Divider(height: AppSpacing.lg),
                    _ProfileRow(label: 'Date of Birth', value: dob),
                    const Divider(height: AppSpacing.lg),
                    _ProfileRow(
                      label: 'Gender',
                      value: switch (gender.toUpperCase()) {
                        'M' => 'Male',
                        'F' => 'Female',
                        'T' => 'Transgender',
                        _ => gender,
                      },
                    ),
                    const Divider(height: AppSpacing.lg),
                    _ProfileRow(label: 'Address', value: address),
                  ],
                ),
              ),

              const Spacer(),

              // ── Continue button ───────────────────────────────────────
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/dashboard'),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text(
                    'Continue to Dashboard',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              TextButton(
                onPressed: () => context.go('/dashboard'),
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
