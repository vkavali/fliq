import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/customer/presentation/screens/home_screen.dart';
import '../../features/customer/presentation/screens/scan_qr_screen.dart';
import '../../features/customer/presentation/screens/tip_amount_screen.dart';
import '../../features/customer/presentation/screens/payment_success_screen.dart';
import '../../features/customer/presentation/screens/transaction_history_screen.dart';
import '../../features/provider_dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/provider_dashboard/presentation/screens/earnings_screen.dart';
import '../../features/provider_dashboard/presentation/screens/qr_display_screen.dart';
import '../../features/provider_dashboard/presentation/screens/payout_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final phone = state.extra as String? ?? '';
          return OtpScreen(phone: phone);
        },
      ),
      // Customer routes
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) => const ScanQrScreen(),
      ),
      GoRoute(
        path: '/tip',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>? ?? {};
          return TipAmountScreen(
            providerId: data['providerId'] as String? ?? '',
            providerName: data['providerName'] as String? ?? '',
            category: data['category'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: '/payment-success',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>? ?? {};
          return PaymentSuccessScreen(
            amount: data['amount'] as int? ?? 0,
            providerName: data['providerName'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const TransactionHistoryScreen(),
      ),
      // Provider routes
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/earnings',
        builder: (context, state) => const EarningsScreen(),
      ),
      GoRoute(
        path: '/my-qr',
        builder: (context, state) => const QrDisplayScreen(),
      ),
      GoRoute(
        path: '/payouts',
        builder: (context, state) => const PayoutScreen(),
      ),
    ],
  );
});
