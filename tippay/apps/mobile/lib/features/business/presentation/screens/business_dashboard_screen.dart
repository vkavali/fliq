import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/business_repository.dart';

final _businessProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.read(businessRepositoryProvider).getMyBusiness();
});

final _dashboardStatsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) {
  return ref.read(businessRepositoryProvider).getDashboardStats(id);
});

class BusinessDashboardScreen extends ConsumerWidget {
  const BusinessDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessAsync = ref.watch(_businessProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Dashboard'),
        backgroundColor: AppTheme.primaryPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Staff',
            onPressed: () => context.push('/business/staff'),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: 'Bulk QR',
            onPressed: () => context.push('/business/qrcodes'),
          ),
        ],
      ),
      body: businessAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRegister: () => context.push('/business/register'),
        ),
        data: (business) {
          final businessId = business['id'] as String;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(_businessProvider.future),
            child: ListView(
              padding: AppSpacing.pagePadding,
              children: [
                // Business header card
                _BusinessHeaderCard(business: business),
                const SizedBox(height: 16),

                // Stats
                _DashboardStatsSection(businessId: businessId),
                const SizedBox(height: 16),

                // Quick actions
                Text('Quick Actions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.people,
                        label: 'Staff',
                        subtitle: '${(business['_count'] as Map?)?['members'] ?? 0} members',
                        color: Colors.blue,
                        onTap: () => context.push('/business/staff', extra: businessId),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.qr_code_2,
                        label: 'QR Codes',
                        subtitle: 'Bulk generate',
                        color: Colors.green,
                        onTap: () => context.push('/business/qrcodes', extra: businessId),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.star,
                        label: 'Satisfaction',
                        subtitle: 'Ratings & reviews',
                        color: Colors.orange,
                        onTap: () => context.push('/business/satisfaction'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.download,
                        label: 'Export CSV',
                        subtitle: 'Download report',
                        color: Colors.purple,
                        onTap: () => _showExportMessage(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showExportMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export available via web dashboard at fliq.co.in'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}

class _BusinessHeaderCard extends StatelessWidget {
  final Map<String, dynamic> business;
  const _BusinessHeaderCard({required this.business});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeEmojis = {
      'HOTEL': '🏨', 'SALON': '💇', 'RESTAURANT': '🍽️',
      'SPA': '🧖', 'CAFE': '☕', 'RETAIL': '🛍️', 'OTHER': '🏢',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryPurple, AppTheme.primaryPurple.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                typeEmojis[business['type']] ?? '🏢',
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  business['name'] as String? ?? '',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  (business['type'] as String?)?.replaceAll('_', ' ') ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                if (business['address'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    business['address'] as String,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStatsSection extends ConsumerWidget {
  final String businessId;
  const _DashboardStatsSection({required this.businessId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_dashboardStatsProvider(businessId));
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,##,##0.00', 'en_IN');

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Stats unavailable', style: theme.textTheme.bodySmall),
      data: (stats) {
        final totalPaise = (stats['totalAmountPaise'] as num?)?.toInt() ?? 0;
        final netPaise = (stats['totalNetAmountPaise'] as num?)?.toInt() ?? 0;
        final count = stats['totalTipsCount'] as int? ?? 0;
        final rating = (stats['averageRating'] as num?)?.toDouble();
        final staffCount = stats['staffCount'] as int? ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overview', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total Tips',
                    value: '₹${fmt.format(totalPaise / 100)}',
                    icon: Icons.currency_rupee,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Net Earnings',
                    value: '₹${fmt.format(netPaise / 100)}',
                    icon: Icons.account_balance_wallet,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Transactions',
                    value: count.toString(),
                    icon: Icons.receipt,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: rating != null ? rating.toStringAsFixed(1) : 'N/A',
                    value: '★ Rating',
                    icon: Icons.star,
                    color: Colors.orange,
                    valueIsLabel: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StatCard(
              label: 'Active Staff',
              value: staffCount.toString(),
              icon: Icons.group,
              color: Colors.purple,
              fullWidth: true,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool fullWidth;
  final bool valueIsLabel;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.fullWidth = false,
    this.valueIsLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                valueIsLabel ? value : label,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
              Text(
                valueIsLabel ? label : value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRegister;
  const _ErrorView({required this.message, required this.onRegister});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: AppSpacing.pagePadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.business_center, size: 64, color: AppTheme.primaryPurple),
            const SizedBox(height: 16),
            Text('No Business Found', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Register your business to manage staff tips from one dashboard.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRegister,
              icon: const Icon(Icons.add_business),
              label: const Text('Register Business'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
