import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;

  const OtpScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();

  static const _resendCooldown = 30;
  static const _otpExpiry = 5 * 60; // 5 minutes in seconds

  int _resendSeconds = _resendCooldown;
  int _expirySeconds = _otpExpiry;

  Timer? _resendTimer;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _startTimers();
  }

  void _startTimers() {
    _resendSeconds = _resendCooldown;
    _expirySeconds = _otpExpiry;
    _resendTimer?.cancel();
    _expiryTimer?.cancel();

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });

    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_expirySeconds <= 1) {
        t.cancel();
        setState(() => _expirySeconds = 0);
      } else {
        setState(() => _expirySeconds--);
      }
    });
  }

  void _resendOtp() {
    ref.read(authProvider.notifier).sendOtp(widget.phone);
    _startTimers();
  }

  String _formatExpiry(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _otpController.dispose();
    _resendTimer?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    ref.listen(authProvider, (prev, next) async {
      if (next.status == AuthStatus.authenticated) {
        // Register FCM token after successful login
        final notifService = ref.read(notificationServiceProvider);
        await notifService.registerToken();

        final user = next.user;
        if (user != null && user.isProvider) {
          context.go('/dashboard');
        } else {
          context.go('/home');
        }
      } else if (next.status == AuthStatus.error && next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: AppSpacing.horizontalLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Enter the 6-digit code sent to',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.phone,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(
                hintText: '------',
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.xs),
            // OTP expiry countdown
            if (_expirySeconds > 0)
              Text(
                'OTP expires in ${_formatExpiry(_expirySeconds)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _expirySeconds <= 60
                      ? colorScheme.error
                      : theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              )
            else
              Text(
                'OTP has expired',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: authState.status == AuthStatus.loading ||
                      _otpController.text.length < 6
                  ? null
                  : () {
                      ref.read(authProvider.notifier).verifyOtp(
                            widget.phone,
                            _otpController.text,
                          );
                    },
              child: authState.status == AuthStatus.loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Verify'),
            ),
            const SizedBox(height: AppSpacing.md),
            // Resend section
            if (_resendSeconds > 0)
              Text(
                'Resend OTP in ${_resendSeconds}s',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              )
            else
              TextButton(
                onPressed: authState.status == AuthStatus.loading
                    ? null
                    : _resendOtp,
                child: const Text('Resend OTP'),
              ),
          ],
        ),
      ),
    );
  }
}
