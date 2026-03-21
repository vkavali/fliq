import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/tip_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/provider_repository.dart';

final dashboardTipsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.read(providerRepositoryProvider);
  return repo.getProviderTips(limit: 5);
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final tipsAsync = ref.watch(dashboardTipsProvider);
    final userName = authState.user?.name ?? 'Provider';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.horizontalLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hi, $userName!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    },
                    icon: const Icon(Icons.logout),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Quick stats
              tipsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Error loading: $err'),
                data: (data) {
                  final total = data['total'] as int? ?? 0;
                  final tips = (data['tips'] as List?) ?? [];
                  int totalEarnings = 0;
                  for (final t in tips) {
                    final tip = t as Map<String, dynamic>;
                    totalEarnings += (tip['netAmountPaise'] as int? ?? 0);
                  }

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'Total Tips',
                              value: total.toString(),
                              icon: Icons.volunteer_activism,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _StatCard(
                              title: 'Recent Earnings',
                              value: '\u20B9${(totalEarnings / 100).toStringAsFixed(0)}',
                              icon: Icons.account_balance_wallet,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Recent tips
                      if (tips.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Recent Tips',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                )),
                            TextButton(
                              onPressed: () => context.push('/earnings'),
                              child: const Text('See All'),
                            ),
                          ],
                        ),
                        ...tips.take(3).map((t) {
                          final tip = TipModel.fromJson(t as Map<String, dynamic>);
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              radius: 16,
                              child: Icon(Icons.person, size: 16),
                            ),
                            title: Text(tip.customerName ?? 'Anonymous'),
                            subtitle: Text('\u20B9${tip.amountRupees}'),
                            trailing: Text(
                              tip.status,
                              style: TextStyle(
                                color: tip.status == 'PAID' || tip.status == 'SETTLED'
                                    ? Colors.green
                                    : Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: AppSpacing.xl),

              // Action grid
              Text('Quick Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: AppSpacing.md),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _ActionCard(
                    icon: Icons.qr_code,
                    label: 'My QR Code',
                    onTap: () => context.push('/my-qr'),
                  ),
                  _ActionCard(
                    icon: Icons.bar_chart,
                    label: 'Earnings',
                    onTap: () => context.push('/earnings'),
                  ),
                  _ActionCard(
                    icon: Icons.account_balance,
                    label: 'Payouts',
                    onTap: () => context.push('/payouts'),
                  ),
                  _ActionCard(
                    icon: Icons.settings,
                    label: 'Settings',
                    onTap: () {
                      // TODO: settings screen
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: AppSpacing.sm),
            Text(value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
            Text(title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
