import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/ekyc_repository.dart';

class EkycOnboardingScreen extends ConsumerStatefulWidget {
  const EkycOnboardingScreen({super.key});

  @override
  ConsumerState<EkycOnboardingScreen> createState() =>
      _EkycOnboardingScreenState();
}

class _EkycOnboardingScreenState extends ConsumerState<EkycOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  String _stripSpaces(String s) => s.replaceAll(RegExp(r'\s+'), '');

  String? _validateId(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your Aadhaar or VID';
    final stripped = _stripSpaces(value);
    if (stripped.length != 12 && stripped.length != 16) {
      return 'Must be a 12-digit Aadhaar or 16-digit Virtual ID';
    }
    if (!RegExp(r'^\d+$').hasMatch(stripped)) {
      return 'Only digits are allowed';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(ekycRepositoryProvider);
      final result = await repo.initiateEkyc(_stripSpaces(_idController.text));

      if (mounted) {
        context.push('/onboarding/ekyc/otp', extra: {
          'sessionToken': result.sessionToken,
          'maskedPhone': result.maskedPhone,
        });
      }
    } catch (e) {
      setState(() => _error = _extractMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _extractMessage(Object e) {
    // DioException carries a server message in response data
    if (e.toString().contains('message')) {
      final msg = e.toString();
      final start = msg.indexOf('"message":"');
      if (start != -1) {
        final sub = msg.substring(start + 11);
        final end = sub.indexOf('"');
        if (end != -1) return sub.substring(0, end);
      }
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify with Aadhaar'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ────────────────────────────────────────────────
                const _KycHeaderCard(),
                const SizedBox(height: AppSpacing.xl),

                // ── Input field ───────────────────────────────────────────
                Text(
                  'Aadhaar Number or Virtual ID',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _idController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    // Allow digits and spaces; max 19 chars (16 digits + 3 spaces)
                    FilteringTextInputFormatter.allow(RegExp(r'[\d\s]')),
                    LengthLimitingTextInputFormatter(19),
                    _AadhaarInputFormatter(),
                  ],
                  validator: _validateId,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'XXXX XXXX XXXX',
                    prefixIcon: Icon(Icons.fingerprint),
                  ),
                  onFieldSubmitted: (_) => _submit(),
                ),

                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ],

                const SizedBox(height: AppSpacing.lg),

                // ── Privacy note ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.security, size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your Aadhaar number is never stored. Only your name and '
                          'address (from UIDAI) are saved to pre-fill your profile.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ── Submit button ─────────────────────────────────────────
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submit,
                    icon: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: Text(_isLoading ? 'Sending OTP…' : 'Send OTP'),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // ── Manual fallback ───────────────────────────────────────
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Enter details manually instead'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header card
// ---------------------------------------------------------------------------

class _KycHeaderCard extends StatelessWidget {
  const _KycHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user, color: Colors.white, size: 36),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Verify in 30 seconds',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Use your Aadhaar to instantly verify your identity. '
            'An OTP will be sent to your Aadhaar-linked mobile number.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Auto-formats 12-digit Aadhaar as "XXXX XXXX XXXX"
// ---------------------------------------------------------------------------

class _AadhaarInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 12 ? digits.substring(0, 12) : digits;

    final buffer = StringBuffer();
    for (int i = 0; i < capped.length; i++) {
      if (i == 4 || i == 8) buffer.write(' ');
      buffer.write(capped[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
