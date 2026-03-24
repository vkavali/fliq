import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/tip_model.dart';
import '../../data/tips_repository.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _historyPageProvider = StateProvider.autoDispose<int>((ref) => 1);

final _historySearchProvider = StateProvider.autoDispose<String>((ref) => '');

final _historyTipsProvider =
    FutureProvider.autoDispose<_PaginatedTips>((ref) async {
  final page = ref.watch(_historyPageProvider);
  final repo = ref.read(tipsRepositoryProvider);
  final data = await repo.getCustomerTips(page: 1, limit: page * 20);
  final tips = (data['tips'] as List)
      .map((e) => TipModel.fromJson(e as Map<String, dynamic>))
      .toList();
  final total = data['total'] as int? ?? tips.length;
  return _PaginatedTips(tips: tips, total: total);
});

class _PaginatedTips {
  final List<TipModel> tips;
  final int total;
  const _PaginatedTips({required this.tips, required this.total});
  bool get hasMore => tips.length < total;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  final _searchController = TextEditingController();
  DateTime? _filterDate;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primary,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _filterDate = picked);
    }
  }

  void _clearDateFilter() {
    setState(() => _filterDate = null);
  }

  @override
  Widget build(BuildContext context) {
    final tipsAsync = ref.watch(_historyTipsProvider);
    final searchQuery = ref.watch(_historySearchProvider).toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tip History'),
        actions: [
          IconButton(
            onPressed: _pickDate,
            icon: Icon(
              _filterDate != null
                  ? Icons.calendar_today
                  : Icons.calendar_today_outlined,
              color: _filterDate != null ? AppColors.primary : null,
            ),
            tooltip: 'Filter by date',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: TextField(
              controller: _searchController,
              onChanged: (v) =>
                  ref.read(_historySearchProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: 'Search by provider name...',
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(_historySearchProvider.notifier).state = '';
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // ── Active date filter chip ────────────────────────────────
          if (_filterDate != null)
            Padding(
              padding: const EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Chip(
                    label: Text(DateFormat('MMM d, yyyy').format(_filterDate!)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: _clearDateFilter,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    labelStyle: const TextStyle(color: AppColors.primary),
                    deleteIconColor: AppColors.primary,
                    side: BorderSide.none,
                  ),
                ],
              ),
            ),

          // ── List ───────────────────────────────────────────────────
          Expanded(
            child: tipsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: AppSpacing.md),
                    Text('Failed to load tips',
                        style:
                            TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(_historyTipsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (paginated) {
                var tips = paginated.tips;

                // Apply search filter
                if (searchQuery.isNotEmpty) {
                  tips = tips
                      .where((t) =>
                          (t.providerName ?? '')
                              .toLowerCase()
                              .contains(searchQuery))
                      .toList();
                }

                // Apply date filter
                if (_filterDate != null) {
                  tips = tips.where((t) {
                    return t.createdAt.year == _filterDate!.year &&
                        t.createdAt.month == _filterDate!.month &&
                        t.createdAt.day == _filterDate!.day;
                  }).toList();
                }

                if (tips.isEmpty) {
                  return _EmptyState(
                    hasFilters: searchQuery.isNotEmpty || _filterDate != null,
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    ref.read(_historyPageProvider.notifier).state = 1;
                    ref.invalidate(_historyTipsProvider);
                    await ref.read(_historyTipsProvider.future);
                  },
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (scroll) {
                      if (scroll is ScrollEndNotification &&
                          scroll.metrics.extentAfter < 200 &&
                          paginated.hasMore) {
                        ref.read(_historyPageProvider.notifier).state++;
                      }
                      return false;
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm),
                      itemCount: tips.length + (paginated.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == tips.length) {
                          return const Padding(
                            padding: EdgeInsets.all(AppSpacing.lg),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        return _TipCard(tip: tips[index]);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tip card
// ---------------------------------------------------------------------------

class _TipCard extends StatelessWidget {
  final TipModel tip;
  const _TipCard({required this.tip});

  static Color _statusColor(String status) => switch (status) {
        'SETTLED' => AppColors.success,
        'PAID' => const Color(0xFFF9A825), // amber-ish
        'FAILED' => AppColors.error,
        'INITIATED' => Colors.grey,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(tip.status);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              (tip.providerName ?? 'P')[0].toUpperCase(),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Name + time + rating
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip.providerName ?? 'Provider',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  _timeAgo(tip.createdAt),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                if (tip.rating != null && tip.rating! > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(5, (i) {
                      return Icon(
                        i < tip.rating!
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 14,
                        color:
                            i < tip.rating! ? Colors.amber : Colors.grey.shade300,
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),

          // Amount + status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\u20B9${tip.amountRupees}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tip.status,
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  const _EmptyState({this.hasFilters = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilters ? Icons.search_off : Icons.receipt_long_outlined,
              size: 72,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              hasFilters ? 'No tips match your search' : 'No tips yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hasFilters
                  ? 'Try a different search term or clear filters'
                  : 'Once you send a tip, it will show up here',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Utility
// ---------------------------------------------------------------------------

String _timeAgo(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  return DateFormat('MMM d, yyyy').format(dateTime);
}
