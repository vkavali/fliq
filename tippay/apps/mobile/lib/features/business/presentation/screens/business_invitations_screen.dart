import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/business_repository.dart';

class BusinessInvitationsScreen extends ConsumerStatefulWidget {
  const BusinessInvitationsScreen({super.key});

  @override
  ConsumerState<BusinessInvitationsScreen> createState() =>
      _BusinessInvitationsScreenState();
}

class _BusinessInvitationsScreenState
    extends ConsumerState<BusinessInvitationsScreen> {
  List<dynamic> _invitations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final repo = ref.read(businessRepositoryProvider);
      final data = await repo.getMyInvitations();
      if (mounted) setState(() { _invitations = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _respond(String invitationId, String response, String businessName) async {
    try {
      final repo = ref.read(businessRepositoryProvider);
      await repo.respondToInvitation(invitationId, response);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response == 'ACCEPT'
                  ? 'Joined $businessName!'
                  : 'Invitation declined',
            ),
          ),
        );
        // Refresh and navigate on accept
        await _loadInvitations();
        if (response == 'ACCEPT' && mounted) {
          context.go('/business/dashboard');
        }
      }
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
    final typeEmojis = {
      'HOTEL': '🏨', 'SALON': '💇', 'RESTAURANT': '🍽️',
      'SPA': '🧖', 'CAFE': '☕', 'RETAIL': '🛍️', 'OTHER': '🏢',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Invitations'),
        backgroundColor: AppTheme.primaryPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : RefreshIndicator(
                  onRefresh: _loadInvitations,
                  child: _invitations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.mail_outline, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text('No pending invitations',
                                  style: theme.textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Text(
                                'When a business owner invites you, it will appear here.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: AppSpacing.pagePadding,
                          itemCount: _invitations.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final inv = _invitations[i] as Map<String, dynamic>;
                            final business = inv['business'] as Map<String, dynamic>? ?? {};
                            final sender = inv['sender'] as Map<String, dynamic>? ?? {};
                            final businessName = business['name'] as String? ?? 'Unknown Business';
                            final businessType = business['type'] as String? ?? 'OTHER';
                            final senderName = sender['name'] as String? ?? 'Someone';
                            final role = inv['role'] as String? ?? 'STAFF';

                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(typeEmojis[businessType] ?? '🏢',
                                            style: const TextStyle(fontSize: 32)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                businessName,
                                                style: theme.textTheme.titleMedium
                                                    ?.copyWith(fontWeight: FontWeight.bold),
                                              ),
                                              Text(
                                                'Invited by $senderName • Role: $role',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () => _respond(
                                                inv['id'] as String, 'DECLINE', businessName),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: const BorderSide(color: Colors.red),
                                            ),
                                            child: const Text('Decline'),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () => _respond(
                                                inv['id'] as String, 'ACCEPT', businessName),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primaryPurple,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Accept'),
                                          ),
                                        ),
                                      ],
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
}
