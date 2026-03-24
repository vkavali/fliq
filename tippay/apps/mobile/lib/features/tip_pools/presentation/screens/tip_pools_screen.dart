import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/tip_pool_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/tip_pools_repository.dart';

final tipPoolsDataProvider =
    FutureProvider.autoDispose<_TipPoolsData>((ref) async {
  final repo = ref.read(tipPoolsRepositoryProvider);
  final data = await repo.getMyPools();

  final owned = ((data['owned'] as List?) ?? [])
      .map((e) => TipPoolModel.fromJson(e as Map<String, dynamic>))
      .toList();
  final memberOf = ((data['memberOf'] as List?) ?? [])
      .map((e) => TipPoolModel.fromJson(e as Map<String, dynamic>))
      .toList();

  return _TipPoolsData(owned: owned, memberOf: memberOf);
});

class _TipPoolsData {
  final List<TipPoolModel> owned;
  final List<TipPoolModel> memberOf;

  _TipPoolsData({required this.owned, required this.memberOf});

  bool get isEmpty => owned.isEmpty && memberOf.isEmpty;
  List<TipPoolModel> get all => [...owned, ...memberOf];
}

class TipPoolsScreen extends ConsumerWidget {
  const TipPoolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poolsAsync = ref.watch(tipPoolsDataProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tip Pools'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/tip-pools/create'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Pool'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(tipPoolsDataProvider);
        },
        child: poolsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: AppSpacing.md),
                  Text('Error: $err', textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(tipPoolsDataProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (data) {
            if (data.isEmpty) {
              return _buildEmptyState(context);
            }
            return _buildPoolsList(context, ref, data);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.groups_outlined,
                  size: 80, color: Colors.grey.shade400),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No Tip Pools Yet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Create a pool to split tips among your team members automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPoolsList(
      BuildContext context, WidgetRef ref, _TipPoolsData data) {
    final userId =
        ref.watch(authProvider).user?.id ?? '';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.horizontalLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),

          if (data.owned.isNotEmpty) ...[
            Text(
              'My Pools',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...data.owned
                .map((pool) => _PoolCard(pool: pool, isOwner: true)),
            const SizedBox(height: AppSpacing.lg),
          ],

          if (data.memberOf.isNotEmpty) ...[
            Text(
              'Member Of',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...data.memberOf
                .map((pool) => _PoolCard(pool: pool, isOwner: false)),
          ],

          const SizedBox(height: 80), // space for FAB
        ],
      ),
    );
  }
}

class _PoolCard extends StatelessWidget {
  final TipPoolModel pool;
  final bool isOwner;

  const _PoolCard({required this.pool, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        elevation: 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/tip-pools/${pool.id}'),
          child: Padding(
            padding: AppSpacing.paddingMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.groups,
                          color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pool.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (pool.description != null &&
                              pool.description!.isNotEmpty)
                            Text(
                              pool.description!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (isOwner)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Owner',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.people_outline,
                      label: '${pool.memberCount} members',
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _InfoChip(
                      icon: Icons.pie_chart_outline,
                      label: pool.splitMethodLabel,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _InfoChip(
                      icon: Icons.receipt_long_outlined,
                      label: '${pool.tipCount} tips',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
