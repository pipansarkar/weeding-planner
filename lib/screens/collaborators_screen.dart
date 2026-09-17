import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/access_provider.dart';
import '../providers/auth_provider.dart';
import 'access_requests_screen.dart';

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

class CollaboratorsScreen extends StatefulWidget {
  const CollaboratorsScreen({super.key});

  @override
  State<CollaboratorsScreen> createState() => _CollaboratorsScreenState();
}

class _CollaboratorsScreenState extends State<CollaboratorsScreen> {
  final _joinCodeController = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _lastInviteCode;

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _createWedding() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AccessProvider>().createCloudWedding();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createInvite() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await context.read<AccessProvider>().createInvite();
      setState(() => _lastInviteCode = code);
      await SharePlus.instance.share(
        ShareParams(text: "Join our wedding planner! Use invite code: $code"),
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinWithCode() async {
    final code = _joinCodeController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AccessProvider>().acceptInvite(code);
      _joinCodeController.clear();
    } catch (e) {
      _error = 'Could not join: $e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessProvider>();
    final auth = context.watch<AuthProvider>();
    final hasCloudWedding = access.cloudWeddingId != null;

    if (access.isRestoring) {
      return Scaffold(
        appBar: AppBar(title: const Text('Collaborators')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Collaborators')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (!hasCloudWedding) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start collaborating', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text('Create a shared wedding so others can be invited to view and edit it.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy ? null : _createWedding,
                      child: const Text('Create shared wedding'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Have an invite code?', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _joinCodeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Invite code'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy ? null : _joinWithCode,
                      child: const Text('Join'),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            if (access.isOwner) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invite someone', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const Text('Generate a code to share with the bride, groom, or family.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _busy ? null : _createInvite,
                        icon: const Icon(Icons.share),
                        label: const Text('Generate & share invite'),
                      ),
                      if (_lastInviteCode != null) ...[
                        const SizedBox(height: 8),
                        SelectableText('Latest code: $_lastInviteCode'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text('Manage access requests'),
                  subtitle: Text(
                    '${access.sectionAccess.where((r) => r['status'] == 'pending').length} pending',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AccessRequestsScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Card(
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
                          Icon(Icons.vpn_key_outlined, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Request access', style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ask the wedding owner for permission to view and edit a section.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _allSections.map((section) {
                          final status = access.accessStatusFor(section);
                          return _RequestChip(
                            label: _sectionLabel(section),
                            status: status,
                            onTap: status == null || status == 'rejected' || status == 'revoked'
                                ? () => context.read<AccessProvider>().requestSectionAccess(section)
                                : null,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _MyRequestHistory(access: access, auth: auth),
              const SizedBox(height: 16),
            ],
            Text('Members', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...access.members.map((m) {
              final userId = m['user_id'] as String;
              final isYou = userId == auth.userId;
              final isOwnerRow = m['role'] == 'owner';
              final name = access.displayNameFor(userId);
              final sections = isOwnerRow ? const ['all sections'] : access.approvedSectionsFor(userId);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(isOwnerRow ? Icons.star : Icons.person),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$name${isYou ? ' (you)' : ''}',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              isOwnerRow ? 'Owner' : 'Member',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            sections.isEmpty
                                ? Text(
                                    'No section access yet',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.outline,
                                        ),
                                  )
                                : Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: sections
                                        .map((s) => Chip(
                                              visualDensity: VisualDensity.compact,
                                              label: Text(
                                                s == 'all sections' ? s : _sectionLabel(s),
                                                style: const TextStyle(fontSize: 11),
                                              ),
                                              padding: EdgeInsets.zero,
                                            ))
                                        .toList(),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// A pill-shaped status control for one section in the "Request access"
/// panel, visually matching the owner's Manage Access screen: neutral +
/// outlined when nothing has been requested yet, orange/clock while
/// pending, green/check once approved, red/x if rejected or revoked (both
/// of which can be tapped again to re-request).
class _RequestChip extends StatelessWidget {
  final String label;
  final String? status;
  final VoidCallback? onTap;

  const _RequestChip({required this.label, required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    late final Color color;
    late final IconData icon;
    late final String stateLabel;
    switch (status) {
      case 'approved':
        color = Colors.green;
        icon = Icons.check_circle;
        stateLabel = 'Approved';
        break;
      case 'pending':
        color = Colors.orange;
        icon = Icons.hourglass_top;
        stateLabel = 'Pending';
        break;
      case 'rejected':
        color = scheme.error;
        icon = Icons.cancel;
        stateLabel = 'Rejected — tap to ask again';
        break;
      case 'revoked':
        color = scheme.error;
        icon = Icons.block;
        stateLabel = 'Revoked — tap to ask again';
        break;
      default:
        color = scheme.outline;
        icon = Icons.add_circle_outline;
        stateLabel = 'Tap to request';
    }

    return Tooltip(
      message: stateLabel,
      child: Material(
        color: color.withValues(alpha: status == null ? 0.0 : 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color.withValues(alpha: 0.6)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the current (non-owner) user's own section_access history --
/// what they've requested, and whether each is pending, approved, rejected,
/// or revoked, with who decided it and when.
class _MyRequestHistory extends StatelessWidget {
  final AccessProvider access;
  final AuthProvider auth;

  const _MyRequestHistory({required this.access, required this.auth});

  @override
  Widget build(BuildContext context) {
    final mine = access.sectionAccess.where((r) => r['user_id'] == auth.userId).toList()
      ..sort((a, b) => (b['requested_at'] as String).compareTo(a['requested_at'] as String));
    if (mine.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My request history', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...mine.map((row) {
              final status = row['status'] as String;
              final requestedAt = DateTime.tryParse(row['requested_at'] as String? ?? '');
              final decidedAt = DateTime.tryParse(row['decided_at'] as String? ?? '');
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 8, color: _statusColor(context, status)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_sectionLabel(row['section'] as String)} — $status',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            decidedAt != null
                                ? 'Decided ${DateFormat('MMM d, h:mm a').format(decidedAt.toLocal())}'
                                : requestedAt != null
                                    ? 'Requested ${DateFormat('MMM d, h:mm a').format(requestedAt.toLocal())}'
                                    : '',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
