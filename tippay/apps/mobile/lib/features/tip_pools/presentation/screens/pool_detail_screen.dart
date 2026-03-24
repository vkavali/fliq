import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/tip_pool_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/tip_pools_repository.dart';
import 'tip_pools_screen.dart';

final poolDetailProvider = FutureProvider.autoDispose
    .family<TipPoolModel, String>((ref, poolId) async {
  final repo = ref.read(tipPoolsRepositoryProvider);
  final data = await repo.getPoolDetail(poolId);
  return TipPoolModel.fromJson(data);
});

final poolEarningsProvider = FutureProvider.autoDispose
    .family<TipPoolEarnings, String>((ref, poolId) async {
  final repo = ref.read(tipPoolsRepositoryProvider);
  final data = await repo.getPoolEarnings(poolId);
  return TipPoolEarnings.fromJson(data);
});

class PoolDetailScreen extends ConsumerStatefulWidget {
  final String poolId;

  const PoolDetailScreen({super.key, required this.poolId});

  @override
  ConsumerState<PoolDetailScreen> createState() => _PoolDetailScreenState();
}

class _PoolDetailScreenState extends ConsumerState<PoolDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final poolAsync = ref.watch(poolDetailProvider(widget.poolId));
    final earningsAsync = ref.watch(poolEarningsProvider(widget.poolId));
    final userId = ref.watch(authProvider).user?.id ?? '';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pool Details'),
      ),
      body: poolAsync.when(
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
                  onPressed: () =>
                      ref.invalidate(poolDetailProvider(widget.poolId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (pool) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(poolDetailProvider(widget.poolId));
            ref.invalidate(poolEarningsProvider(widget.poolId));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.horizontalLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.md),

                // Pool header
                _PoolHeader(pool: pool),

                const SizedBox(height: AppSpacing.lg),

                // Earnings summary
                earningsAsync.when(
                  loading: () => const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (earnings) =>
                      _EarningsSummary(earnings: earnings),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Members section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Members (${pool.memberCount})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (pool.isOwner(userId))
                      TextButton.icon(
                        onPressed: () => _showAddMemberDialog(context, ref),
                        icon:
                            const Icon(Icons.person_add_outlined, size: 18),
                        label: const Text('Add'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                ...pool.members.map((member) => _MemberTile(
                      member: member,
                      isOwner: pool.isOwner(userId),
                      isPoolOwner: member.userId == pool.ownerId,
                      onRemove: pool.isOwner(userId) &&
                              member.userId != pool.ownerId
                          ? () => _removeMember(context, ref, member)
                          : null,
                    )),

                const SizedBox(height: AppSpacing.lg),

                // Earnings breakdown
                earningsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (earnings) => earnings.members.isNotEmpty
                      ? _EarningsBreakdown(earnings: earnings)
                      : const SizedBox.shrink(),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Actions
                if (pool.isOwner(userId)) ...[
                  OutlinedButton.icon(
                    onPressed: () => _confirmDeactivate(context, ref, pool),
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.error),
                    label: const Text('Deactivate Pool',
                        style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      // Leave pool = remove self
                      // For now show a confirmation
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Contact the pool owner to leave')),
                      );
                    },
                    icon: const Icon(Icons.exit_to_app,
                        color: AppColors.warning),
                    label: const Text('Leave Pool'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context, WidgetRef ref) {
    final phoneController = TextEditingController();
    final roleController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '+919876543210',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: roleController,
              decoration: const InputDecoration(
                labelText: 'Role (optional)',
                hintText: 'e.g. waiter, chef, host',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (phoneController.text.trim().isEmpty) return;
              Navigator.pop(ctx);

              try {
                final repo = ref.read(tipPoolsRepositoryProvider);
                await repo.addMember(
                  widget.poolId,
                  phone: phoneController.text.trim(),
                  role: roleController.text.trim().isNotEmpty
                      ? roleController.text.trim()
                      : null,
                );
                ref.invalidate(poolDetailProvider(widget.poolId));
                ref.invalidate(tipPoolsDataProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Member added')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add member: $e')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(
      BuildContext context, WidgetRef ref, TipPoolMemberModel member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
            'Remove ${member.userName ?? member.userPhone ?? 'this member'} from the pool?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(tipPoolsRepositoryProvider);
      await repo.removeMember(widget.poolId, member.id);
      ref.invalidate(poolDetailProvider(widget.poolId));
      ref.invalidate(tipPoolsDataProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member removed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove member: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeactivate(
      BuildContext context, WidgetRef ref, TipPoolModel pool) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Pool'),
        content: Text(
            'Are you sure you want to deactivate "${pool.name}"? Tips will no longer be split among members.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(tipPoolsRepositoryProvider);
      await repo.deactivatePool(pool.id);
      ref.invalidate(tipPoolsDataProvider);
      if (context.mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pool deactivated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to deactivate: $e')),
        );
      }
    }
  }
}

class _PoolHeader extends StatelessWidget {
  final TipPoolModel pool;

  const _PoolHeader({required this.pool});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF8B83FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups, color: Colors.white, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  pool.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (pool.description != null && pool.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              pool.description!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _HeaderChip(
                icon: Icons.pie_chart_outline,
                label: pool.splitMethodLabel,
              ),
              const SizedBox(width: AppSpacing.md),
              _HeaderChip(
                icon: Icons.people_outline,
                label: '${pool.memberCount} members',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
              )),
        ],
      ),
    );
  }
}

class _EarningsSummary extends StatelessWidget {
  final TipPoolEarnings earnings;

  const _EarningsSummary({required this.earnings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_wallet,
                color: AppColors.success, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\u20B9${earnings.totalEarningsRupees}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  '${earnings.tipCount} tips pooled',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final TipPoolMemberModel member;
  final bool isOwner;
  final bool isPoolOwner;
  final VoidCallback? onRemove;

  const _MemberTile({
    required this.member,
    required this.isOwner,
    required this.isPoolOwner,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = member.userName ?? member.userPhone ?? 'Unknown';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                displayName.isNotEmpty
                    ? displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        displayName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isPoolOwner) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Owner',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (member.role != null && member.role!.isNotEmpty)
                    Text(
                      member.role!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (member.splitPercentage != null)
              Text(
                '${member.splitPercentage!.toStringAsFixed(0)}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            if (onRemove != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.remove_circle_outline,
                    color: AppColors.error, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EarningsBreakdown extends StatelessWidget {
  final TipPoolEarnings earnings;

  const _EarningsBreakdown({required this.earnings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Earnings Breakdown',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...earnings.members.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.userName ?? m.userPhone ?? 'Unknown',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${m.splitPercentage.toStringAsFixed(1)}% share'
                            '${m.role != null ? ' \u2022 ${m.role}' : ''}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '\u20B9${m.amountRupees}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}
