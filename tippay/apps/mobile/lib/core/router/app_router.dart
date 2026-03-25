import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/customer/presentation/screens/home_screen.dart';
import '../../features/customer/presentation/screens/scan_qr_screen.dart';
import '../../features/customer/presentation/screens/tip_amount_screen.dart';
import '../../features/customer/presentation/screens/provider_search_screen.dart';
import '../../features/customer/presentation/screens/payment_success_screen.dart';
import '../../features/customer/presentation/screens/transaction_history_screen.dart';
import '../../features/provider_dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/provider_dashboard/presentation/screens/earnings_screen.dart';
import '../../features/provider_dashboard/presentation/screens/qr_display_screen.dart';
import '../../features/provider_dashboard/presentation/screens/payout_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/gamification/presentation/screens/badges_screen.dart';
import '../../features/gamification/presentation/screens/leaderboard_screen.dart';
import '../../features/gamification/presentation/screens/streak_screen.dart';
import '../../features/tip_pools/presentation/screens/tip_pools_screen.dart';
import '../../features/tip_pools/presentation/screens/pool_detail_screen.dart';
import '../../features/tip_pools/presentation/screens/create_pool_screen.dart';
import '../../features/business/presentation/screens/business_registration_screen.dart';
import '../../features/business/presentation/screens/business_dashboard_screen.dart';
import '../../features/business/presentation/screens/business_staff_screen.dart';
import '../../features/business/presentation/screens/business_qr_screen.dart';
import '../../features/business/presentation/screens/business_invitations_screen.dart';
import '../navigation/customer_shell.dart';
import '../navigation/provider_shell.dart';

// Root navigator key for full-screen routes that sit above the shell
final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      // ── Splash (auth check) ───────────────────────────────────────────
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Auth routes ───────────────────────────────────────────────────
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

      // ── Customer shell (bottom nav) ───────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return CustomerShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (context, state) =>
                    const TransactionHistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Customer full-screen routes (no bottom nav) ───────────────────
      GoRoute(
        path: '/scan',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ScanQrScreen(),
      ),
      GoRoute(
        path: '/search',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>?;
          return ProviderSearchScreen(
            initialCategory: data?['category'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/tip',
        parentNavigatorKey: _rootNavigatorKey,
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
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>? ?? {};
          return PaymentSuccessScreen(
            amount: data['amount'] as int? ?? 0,
            providerName: data['providerName'] as String? ?? '',
            rating: data['rating'] as int? ?? 0,
            message: data['message'] as String? ?? '',
            fee: data['fee'] as int? ?? 0,
          );
        },
      ),

      // ── Gamification routes ──────────────────────────────────────────
      GoRoute(
        path: '/badges',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BadgesScreen(),
      ),
      GoRoute(
        path: '/leaderboard',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: '/streak',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const StreakScreen(),
      ),

      // ── Tip Pools routes ──────────────────────────────────────────────
      GoRoute(
        path: '/tip-pools',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TipPoolsScreen(),
      ),
      GoRoute(
        path: '/tip-pools/create',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreatePoolScreen(),
      ),
      GoRoute(
        path: '/tip-pools/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final poolId = state.pathParameters['id'] ?? '';
          return PoolDetailScreen(poolId: poolId);
        },
      ),

      // ── Business (B2B) routes ─────────────────────────────────────────
      GoRoute(
        path: '/business/register',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BusinessRegistrationScreen(),
      ),
      GoRoute(
        path: '/business/dashboard',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BusinessDashboardScreen(),
      ),
      GoRoute(
        path: '/business/invitations',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BusinessInvitationsScreen(),
      ),
      GoRoute(
        path: '/business/staff',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final businessId = state.extra as String? ?? '';
          return BusinessStaffScreen(businessId: businessId);
        },
      ),
      GoRoute(
        path: '/business/qrcodes',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final businessId = state.extra as String? ?? '';
          return BusinessQrScreen(businessId: businessId);
        },
      ),

      // ── Provider shell (bottom nav) ───────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ProviderShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-qr',
                builder: (context, state) => const QrDisplayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/earnings',
                builder: (context, state) => const EarningsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/payouts',
                builder: (context, state) => const PayoutScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
