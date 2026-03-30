import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/auth_provider.dart';

const _countryCodes = [
  _CountryCode(code: '+91', label: '🇮🇳 +91', hint: '9876543210'),
  _CountryCode(code: '+1', label: '🇺🇸 +1', hint: '2125551234'),
];

class _CountryCode {
  final String code;
  final String label;
  final String hint;
  const _CountryCode({required this.code, required this.label, required this.hint});
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  _CountryCode _selectedCountry = _countryCodes[0];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String get _fullPhone => '${_selectedCountry.code}${_phoneController.text}';

  String? _validatePhone(String? value) {
    final digits = value ?? '';
    if (_selectedCountry.code == '+91') {
      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
        return 'Enter a valid 10-digit Indian mobile number';
      }
    } else if (_selectedCountry.code == '+1') {
      if (!RegExp(r'^[2-9]\d{9}$').hasMatch(digits)) {
        return 'Enter a valid 10-digit US phone number';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (prev, next) {
      if (next.status == AuthStatus.otpSent) {
        context.push('/otp', extra: _fullPhone);
      } else if (next.status == AuthStatus.error && next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.horizontalLg,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                Text(
                  'Fliq',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Reward great service, instantly',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonHideUnderline(
                      child: DropdownButton<_CountryCode>(
                        value: _selectedCountry,
                        items: _countryCodes
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c.label),
                                ))
                            .toList(),
                        onChanged: (c) {
                          if (c != null) {
                            setState(() {
                              _selectedCountry = c;
                              _phoneController.clear();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: InputDecoration(
                          labelText: 'Mobile Number',
                          hintText: _selectedCountry.hint,
                          prefixIcon: const Icon(Icons.phone),
                          counterText: '',
                        ),
                        validator: _validatePhone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: authState.status == AuthStatus.loading
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            ref.read(authProvider.notifier).sendOtp(_fullPhone);
                          }
                        },
                  child: authState.status == AuthStatus.loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Get OTP'),
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
