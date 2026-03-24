import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/tips_repository.dart';

class ProviderSearchScreen extends ConsumerStatefulWidget {
  final String? initialCategory;

  const ProviderSearchScreen({super.key, this.initialCategory});

  @override
  ConsumerState<ProviderSearchScreen> createState() =>
      _ProviderSearchScreenState();
}

class _ProviderSearchScreenState extends ConsumerState<ProviderSearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String? _selectedCategory;
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  int _total = 0;
  int _page = 1;

  static const _categories = [
    null, // "All"
    'DELIVERY',
    'SALON',
    'RESTAURANT',
    'HOTEL',
    'HOUSEHOLD',
  ];

  static const _categoryLabels = {
    null: 'All',
    'DELIVERY': 'Delivery',
    'SALON': 'Salon',
    'RESTAURANT': 'Restaurant',
    'HOTEL': 'Hotel',
    'HOUSEHOLD': 'Household',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!.toUpperCase();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.trim().length >= 2) {
        _page = 1;
        _performSearch();
      } else if (query.trim().isEmpty) {
        setState(() {
          _results = [];
          _hasSearched = false;
          _total = 0;
        });
      }
    });
  }

  void _onCategorySelected(String? category) {
    setState(() => _selectedCategory = category);
    if (_searchController.text.trim().length >= 2) {
      _page = 1;
      _performSearch();
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.length < 2) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(tipsRepositoryProvider);
      final data = await repo.searchProviders(
        query: query,
        category: _selectedCategory,
        page: _page,
        limit: 20,
      );

      if (mounted) {
        final providers = (data['providers'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        setState(() {
          _results = providers;
          _total = (data['total'] as num).toInt();
          _hasSearched = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasSearched = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  void _navigateToTip(Map<String, dynamic> provider) {
    context.push('/tip', extra: {
      'providerId': provider['id'] as String,
      'providerName': provider['name'] as String? ?? 'Provider',
      'category': provider['category'] as String? ?? 'OTHER',
    });
  }

  IconData _categoryIcon(String category) => switch (category.toUpperCase()) {
        'DELIVERY' => Icons.delivery_dining,
        'SALON' => Icons.content_cut,
        'RESTAURANT' => Icons.restaurant,
        'HOTEL' => Icons.hotel,
        'HOUSEHOLD' => Icons.home_repair_service,
        _ => Icons.person,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Provider')),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name or phone',
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _results = [];
                            _hasSearched = false;
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),

          // ── Category filter chips ───────────────────────────────────
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => _onCategorySelected(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isSelected ? AppColors.primary : AppColors.divider,
                      ),
                    ),
                    child: Text(
                      _categoryLabels[cat] ?? 'Other',
                      style: TextStyle(
                        color:
                            isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Results ─────────────────────────────────────────────────
          Expanded(
            child: _buildResultsBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Search for providers by name or phone',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No providers found',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different search term',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final provider = _results[index];
        return _ProviderSearchCard(
          name: provider['name'] as String? ?? 'Provider',
          phone: provider['phone'] as String? ?? '',
          category: provider['category'] as String? ?? 'OTHER',
          ratingAverage: (provider['ratingAverage'] as num?)?.toDouble(),
          totalTipsReceived: (provider['totalTipsReceived'] as num?)?.toInt() ?? 0,
          categoryIcon: _categoryIcon(provider['category'] as String? ?? ''),
          onTap: () => _navigateToTip(provider),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Provider Search Card
// ---------------------------------------------------------------------------

class _ProviderSearchCard extends StatelessWidget {
  final String name;
  final String phone;
  final String category;
  final double? ratingAverage;
  final int totalTipsReceived;
  final IconData categoryIcon;
  final VoidCallback onTap;

  const _ProviderSearchCard({
    required this.name,
    required this.phone,
    required this.category,
    this.ratingAverage,
    required this.totalTipsReceived,
    required this.categoryIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Icon(categoryIcon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          phone,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (ratingAverage != null) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Colors.amber, size: 16),
                      const SizedBox(width: 2),
                      Text(
                        ratingAverage!.toStringAsFixed(1),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  '$totalTipsReceived tips',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
