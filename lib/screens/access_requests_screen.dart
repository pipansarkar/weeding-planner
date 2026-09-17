import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/access_provider.dart';

const _allSections = [
  'guests', 'vendors', 'budget', 'menu', 'checklist',
  'timeline', 'emergency_contacts', 'seating', 'mood_board', 'custom_lists', 'planning',
];

const _sectionLabels = {
  'guests': 'Guests',
  'vendors': 'Vendors',
  'budget': 'Budget',
  'menu': 'Menu',
  'checklist': 'Checklist',
  'timeline': 'Timeline',
  'emergency_contacts': 'Emergency Contacts',
  'seating': 'Seating',
  'mood_board': 'Mood Board',
  'custom_lists': 'Custom Lists',
  'planning': 'Planning',
};

String _sectionLabel(String section) => _sectionLabels[section] ?? section;

Color _statusColor(BuildContext context, String status) {
  final scheme = Theme.of(context).colorScheme;
  switch (status) {
    case 'approved':
      return Colors.green;
    case 'pending':
      return Colors.orange;
    case 'rejected':
    case 'revoked':
      return scheme.error;
    default:
      return scheme.outline;
  }
}

class AccessRequestsScreen extends StatelessWidget {
  const AccessRequestsScreen({super.key});

  Future<void> _confirmRemove(BuildContext context, String userId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove $name?'),
        content: const Text(
          'This removes them from the wedding entirely and revokes all their section access. '
          'They can rejoin later with a new invite code.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AccessProvider>().removeMember(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessProvider>();
    final pending = access.sectionAccess.where((r) => r['status'] == 'pending').toList()
      ..sort((a, b) => (a['requested_at'] as String).compareTo(b['requested_at'] as String));
    final nonOwnerMembers = access.members.where((m) => m['role'] != 'owner').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Access')),
      body: !access.isOwner
          ? const Center(child: Text('Only the wedding owner can manage access.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (pending.isNotEmpty) ...[
                  Row(
                    children: [
                      Text('Pending requests', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${pending.length}',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...pending.map((row) {
                    final userId = row['user_id'] as String;
                    final requestedAt = DateTime.tryParse(row['requested_at'] as String? ?? '');
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0,
                      color: Colors.orange.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.orange.withValues(alpha: 0.2),
                              child: Text(
                                access.displayNameFor(userId).isNotEmpty
                                    ? access.displayNameFor(userId)[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(access.displayNameFor(userId),
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                    'Wants access to ${_sectionLabel(row['section'] as String)}'
                                    '${requestedAt != null ? ' • ${DateFormat('MMM d, h:mm a').format(requestedAt.toLocal())}' : ''}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green),
                              tooltip: 'Approve',
                              onPressed: () => context
                                  .read<AccessProvider>()
                                  .decideSectionAccess(row['id'] as String, 'approved'),
                            ),
                            IconButton(
                              icon: Icon(Icons.cancel, color: Theme.of(context).colorScheme.error),
                              tooltip: 'Reject',
                              onPressed: () => context
                                  .read<AccessProvider>()
                                  .decideSectionAccess(row['id'] as String, 'rejected'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                ],
                Text('Members', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                if (nonOwnerMembers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No one has joined yet. Share an invite code from Collaborators.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ...nonOwnerMembers.map((m) {
                  final userId = m['user_id'] as String;
                  final name = access.displayNameFor(userId);
                  final theirAccess = {
                    for (final row in access.sectionAccess)
                      if (row['user_id'] == userId) row['section'] as String: row,
                  };
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              ),
                              IconButton(
                                icon: Icon(Icons.person_remove, color: Theme.of(context).colorScheme.error),
                                tooltip: 'Remove member',
                                onPressed: () => _confirmRemove(context, userId, name),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Text(
                            'Section access',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _allSections.map((section) {
                              final row = theirAccess[section];
                              final status = row?['status'] as String?;
                              final approved = status == 'approved';
                              return FilterChip(
                                label: Text(_sectionLabel(section)),
                                selected: approved,
                                selectedColor: Colors.green.withValues(alpha: 0.18),
                                checkmarkColor: Colors.green,
                                avatar: status != null && !approved
                                    ? Icon(Icons.circle, size: 8, color: _statusColor(context, status))
                                    : null,
                                onSelected: (selected) {
                                  final accessProvider = context.read<AccessProvider>();
                                  if (selected) {
                                    accessProvider.grantSectionAccess(userId, section);
                                  } else if (row != null) {
                                    accessProvider.decideSectionAccess(row['id'] as String, 'revoked');
                                  }
                                },
                              );
                            }).toList(),
                          ),
                          Builder(builder: (context) {
                            final history = theirAccess.values.where((r) => r['decided_at'] != null).toList()
                              ..sort((a, b) => (b['decided_at'] as String).compareTo(a['decided_at'] as String));
                            if (history.isEmpty) return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 12),
                                Text('History', style: Theme.of(context).textTheme.labelLarge),
                                const SizedBox(height: 4),
                                ...history.take(5).map((row) {
                                  final decidedAt = DateTime.tryParse(row['decided_at'] as String);
                                  final status = row['status'] as String;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.circle, size: 6, color: _statusColor(context, status)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '${_sectionLabel(row['section'] as String)}: $status'
                                            '${decidedAt != null ? ' • ${DateFormat('MMM d, h:mm a').format(decidedAt.toLocal())}' : ''}',
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
