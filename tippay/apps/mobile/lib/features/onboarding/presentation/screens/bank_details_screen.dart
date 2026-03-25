import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/onboarding_provider.dart';
import 'provider_registration_screen.dart' show _OnboardingProgress;

class BankDetailsScreen extends ConsumerStatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  ConsumerState<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends ConsumerState<BankDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _upiVpaCtrl = TextEditingController();
  final _bankAccountCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  bool _obscureBankAccount = true;
  bool _obscurePan = true;

  @override
  void dispose() {
    _upiVpaCtrl.dispose();
    _bankAccountCtrl.dispose();
    _ifscCtrl.dispose();
    _panCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(onboardingProvider.notifier).submitBankDetails(
          upiVpa: _upiVpaCtrl.text.trim(),
          bankAccountNumber: _bankAccountCtrl.text.trim(),
          ifscCode: _ifscCtrl.text.trim().toUpperCase(),
          pan: _panCtrl.text.trim().toUpperCase(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final theme = Theme.of(context);

    ref.listen(onboardingProvider, (_, next) {
      if (next.status == OnboardingStatus.success &&
          next.step == OnboardingStep.kycStatus) {
        context.go('/onboarding/kyc');
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
        title: const Text('Bank Details'),
        leading: BackButton(onPressed: () => context.go('/onboarding/registration')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.horizontalLg,
          children: [
            const SizedBox(height: AppSpacing.lg),
            _OnboardingProgress(step: 2, total: 4),
            const SizedBox(height: AppSpacing.xl),

            Text(
              'Payment Details',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your bank details are encrypted and stored securely.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // UPI VPA
            TextFormField(
              controller: _upiVpaCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'UPI ID (VPA) *',
                hintText: 'e.g. yourname@okicici',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'UPI ID is required';
                final regex = RegExp(r'^[\w.\-]+@[\w]+$');
                if (!regex.hasMatch(v.trim())) return 'Invalid UPI ID format';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Bank account number
            TextFormField(
              controller: _bankAccountCtrl,
              keyboardType: TextInputType.number,
              obscureText: _obscureBankAccount,
              decoration: InputDecoration(
                labelText: 'Bank Account Number *',
                hintText: 'e.g. 1234567890123456',
                prefixIcon: const Icon(Icons.account_balance_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscureBankAccount
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscureBankAccount = !_obscureBankAccount),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Bank account number is required';
                }
                if (v.trim().length < 9 || v.trim().length > 18) {
                  return 'Account number must be 9–18 digits';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // IFSC code
            TextFormField(
              controller: _ifscCtrl,
              textCapitalization: TextCapitalization.characters,
              maxLength: 11,
              decoration: const InputDecoration(
                labelText: 'IFSC Code *',
                hintText: 'e.g. SBIN0001234',
                prefixIcon: Icon(Icons.code_outlined),
                counterText: '',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'IFSC code is required';
                final regex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
                if (!regex.hasMatch(v.trim().toUpperCase())) {
                  return 'Invalid IFSC code (e.g. SBIN0001234)';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // PAN number
            TextFormField(
              controller: _panCtrl,
              textCapitalization: TextCapitalization.characters,
              maxLength: 10,
              obscureText: _obscurePan,
              decoration: InputDecoration(
                labelText: 'PAN Number *',
                hintText: 'e.g. ABCDE1234F',
                prefixIcon: const Icon(Icons.badge_outlined),
                counterText: '',
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscurePan ? Icons.visibility_off : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscurePan = !_obscurePan),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'PAN number is required';
                final regex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
                if (!regex.hasMatch(v.trim().toUpperCase())) {
                  return 'Invalid PAN (e.g. ABCDE1234F)';
                }
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.md),

            // Security note
            Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Bank account number and PAN are encrypted with AES-256 before storage.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            ElevatedButton(
              onPressed: state.status == OnboardingStatus.loading ? null : _submit,
              child: state.status == OnboardingStatus.loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Continue'),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
