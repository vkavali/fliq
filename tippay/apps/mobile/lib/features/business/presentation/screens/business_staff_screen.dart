import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/business_repository.dart';

class BusinessStaffScreen extends ConsumerStatefulWidget {
  final String businessId;
  const BusinessStaffScreen({super.key, required this.businessId});

  @override
  ConsumerState<BusinessStaffScreen> createState() => _BusinessStaffScreenState();
}

class _BusinessStaffScreenState extends ConsumerState<BusinessStaffScreen> {
  List<dynamic> _staff = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final repo = ref.read(businessRepositoryProvider);
      final staff = await repo.getStaffBreakdown(widget.businessId);
      if (mounted) setState(() { _staff = staff; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _showInviteDialog() async {
    final phoneCtrl = TextEditingController();
    String selectedRole = 'STAFF';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Invite Staff Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                  hintText: '+919876543210',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'STAFF', child: Text('Staff')),
                  DropdownMenuItem(value: 'MANAGER', child: Text('Manager')),
                  DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                ],
                onChanged: (v) => setState(() => selectedRole = v ?? 'STAFF'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                Navigator.pop(ctx);
                await _inviteMember(phoneCtrl.text.trim(), selectedRole);
              },
              child: const Text('Invite', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _inviteMember(String phone, String role) async {
    if (phone.isEmpty) return;
    try {
      final repo = ref.read(businessRepositoryProvider);
      await repo.inviteMember(widget.businessId, {'phone': phone, 'role': role});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitation sent to $phone')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _removeMember(String memberId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove $name from your business?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final repo = ref.read(businessRepositoryProvider);
      await repo.removeMember(widget.businessId, memberId);
      await _loadStaff();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,##,##0.00', 'en_IN');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showInviteDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Invite'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : RefreshIndicator(
                  onRefresh: _loadStaff,
                  child: _staff.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.group_add, size: 64, color: AppColors.primary),
                              const SizedBox(height: 16),
                              Text('No staff yet', style: theme.textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Text(
                                'Invite your team members to get started',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: AppSpacing.paddingLg,
                          itemCount: _staff.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final member = _staff[i] as Map<String, dynamic>;
                            final provider = member['provider'] as Map<String, dynamic>? ?? {};
                            final profile = provider['providerProfile'] as Map<String, dynamic>?;
                            final tips = member['tips'] as Map<String, dynamic>? ?? {};
                            final displayName = profile?['displayName'] as String? ??
                                provider['name'] as String? ??
                                'Unknown';
                            final phone = provider['phone'] as String? ?? '';
                            final count = tips['count'] as int? ?? 0;
                            final total = (tips['totalAmountPaise'] as num?)?.toInt() ?? 0;
                            final rating = (tips['averageRating'] as num?)?.toDouble();
                            final role = member['role'] as String? ?? 'STAFF';

                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: AppColors.primary.withOpacity(0.1),
                                      child: Text(
                                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
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
                                              Expanded(
                                                child: Text(
                                                  displayName,
                                                  style: theme.textTheme.titleSmall
                                                      ?.copyWith(fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _roleColor(role).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  role,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: _roleColor(role),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            phone.replaceRange(
                                                phone.length > 4 ? phone.length - 4 : 0,
                                                null,
                                                '****'),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(color: Colors.grey),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              _TipBadge(
                                                  icon: Icons.currency_rupee,
                                                  text: '₹${fmt.format(total / 100)}',
                                                  color: Colors.green),
                                              const SizedBox(width: 8),
                                              _TipBadge(
                                                  icon: Icons.receipt,
                                                  text: '$count tips',
                                                  color: Colors.blue),
                                              if (rating != null) ...[
                                                const SizedBox(width: 8),
                                                _TipBadge(
                                                    icon: Icons.star,
                                                    text: rating.toStringAsFixed(1),
                                                    color: Colors.orange),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline,
                                          color: Colors.red),
                                      onPressed: () => _removeMember(
                                          member['memberId'] as String, displayName),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'ADMIN':
        return Colors.red;
      case 'MANAGER':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

class _TipBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _TipBadge({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(text,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
