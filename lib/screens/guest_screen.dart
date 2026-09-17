import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/guest.dart';
import '../providers/access_provider.dart';
import '../providers/category_provider.dart';
import '../providers/guest_provider.dart';
import '../utils/file_export.dart';
import '../widgets/form_sheet.dart';
import '../widgets/request_access_banner.dart';
import '../widgets/root_scaffold_key.dart';
import 'history_screen.dart';

String _rsvpLabel(RsvpStatus status) {
  switch (status) {
    case RsvpStatus.attending:
      return 'Attending';
    case RsvpStatus.declined:
      return 'Declined';
    case RsvpStatus.pending:
      return 'Pending';
  }
}

String _timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

Color _rsvpColor(RsvpStatus status) {
  switch (status) {
    case RsvpStatus.attending:
      return Colors.green;
    case RsvpStatus.declined:
      return Colors.red;
    case RsvpStatus.pending:
      return Colors.orange;
  }
}

class GuestScreen extends StatelessWidget {
  const GuestScreen({super.key});

  Future<void> _openForm(BuildContext context, {Guest? existing}) async {
    final provider = context.read<GuestProvider>();
    final eventTypes = context.read<CategoryProvider>().categoriesFor('guests');
    await showFormSheet<void>(
      context,
      _GuestForm(provider: provider, existing: existing, eventTypes: eventTypes),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final provider = context.read<GuestProvider>();
    final csv = provider.toCsv();
    await shareTextAsFile(
      content: csv,
      fileName: 'guest_list.csv',
      subject: 'Guest List',
    );
  }

  Future<void> _addEventType(BuildContext context) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Event'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Event name'),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, ctrl.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    if (context.mounted) {
      try {
        await context.read<CategoryProvider>().addCategory('guests', name);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not add "$name": $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuestProvider>();
    final guests = provider.guests;
    final access = context.watch<AccessProvider>();
    final hasAccess = access.cloudWeddingId == null || access.hasApprovedAccess('guests');
    final eventTypes = context.watch<CategoryProvider>().categoriesFor('guests');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => rootScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Guests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export CSV',
            onPressed: guests.isEmpty ? null : () => _exportCsv(context),
          ),
        ],
      ),
      body: !hasAccess
          ? const RequestAccessBanner(section: 'guests')
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _EventCountChip(
                    label: 'Total (w/ +1s)',
                    count: provider.totalHeadcount,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  ...eventTypes.map((event) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _EventCountChip(
                          label: '$event ✓',
                          count: provider.attendingHeadcountForEvent(event),
                          color: Colors.pink,
                        ),
                      )),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('Add Event'),
                    onPressed: () => _addEventType(context),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: guests.isEmpty
                ? const Center(child: Text('No guests yet. Tap + to add one.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: guests.length,
                    itemBuilder: (context, index) {
                      final guest = guests[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(guest.gender == Gender.male ? Icons.male : Icons.female),
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(guest.name)),
                              if (guest.plusOnes > 0)
                                Text('+${guest.plusOnes}',
                                    style: Theme.of(context).textTheme.labelSmall),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [
                                  guest.category,
                                  if (guest.phone.isNotEmpty) guest.phone,
                                ].join(' • '),
                              ),
                              if (guest.events.isNotEmpty)
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: guest.events.map((event) {
                                    final status = guest.rsvpFor(event);
                                    return Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text('$event: ${_rsvpLabel(status)}',
                                          style: const TextStyle(fontSize: 10)),
                                      backgroundColor:
                                          _rsvpColor(status).withValues(alpha: 0.12),
                                      labelStyle: TextStyle(color: _rsvpColor(status)),
                                      padding: EdgeInsets.zero,
                                    );
                                  }).toList(),
                                ),
                              if (guest.lastEditedBy != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Edited by ${access.displayNameFor(guest.lastEditedBy)}'
                                    '${guest.lastEditedAt != null ? ' • ${_timeAgo(guest.lastEditedAt!)}' : ''}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.outline,
                                        ),
                                  ),
                                ),
                              if (guest.invitationSent || guest.giftReceived.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Wrap(
                                    spacing: 6,
                                    children: [
                                      if (guest.invitationSent)
                                        const Icon(Icons.mail_outline, size: 14, color: Colors.blue),
                                      if (guest.giftReceived.isNotEmpty)
                                        Icon(Icons.card_giftcard,
                                            size: 14,
                                            color: guest.thankYouSent
                                                ? Colors.green
                                                : Colors.orange),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          isThreeLine: guest.events.isNotEmpty,
                          onTap: () => _openForm(context, existing: guest),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: !hasAccess
          ? null
          : FloatingActionButton(
              heroTag: 'guest_fab',
              onPressed: () => _openForm(context),
              child: const Icon(Icons.person_add),
            ),
    );
  }
}

class _GuestForm extends StatefulWidget {
  final GuestProvider provider;
  final Guest? existing;
  final List<String> eventTypes;

  const _GuestForm({required this.provider, required this.existing, required this.eventTypes});

  @override
  State<_GuestForm> createState() => _GuestFormState();
}

class _GuestFormState extends State<_GuestForm> {
  late final TextEditingController nameCtrl;
  late final TextEditingController phoneCtrl;
  late final TextEditingController addressCtrl;
  late final TextEditingController noteCtrl;
  late final TextEditingController mealCtrl;
  late final TextEditingController giftCtrl;
  late final TextEditingController plusOnesCtrl;
  late String category;
  late Gender gender;
  late Set<String> events;
  late Map<String, RsvpStatus> rsvpByEvent;
  late bool invitationSent;
  late bool thankYouSent;
  late List<String> eventTypes;
  bool saving = false;

  Guest? get existing => widget.existing;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: existing?.name ?? '');
    phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    addressCtrl = TextEditingController(text: existing?.address ?? '');
    noteCtrl = TextEditingController(text: existing?.note ?? '');
    mealCtrl = TextEditingController(text: existing?.mealPreference ?? '');
    giftCtrl = TextEditingController(text: existing?.giftReceived ?? '');
    plusOnesCtrl = TextEditingController(text: existing?.plusOnes.toString() ?? '0');
    category = existing?.category ?? Guest.categories.first;
    gender = existing?.gender ?? Gender.male;
    events = {...(existing?.events ?? {})};
    rsvpByEvent = {...(existing?.rsvpByEvent ?? {})};
    invitationSent = existing?.invitationSent ?? false;
    thankYouSent = existing?.thankYouSent ?? false;
    eventTypes = [
      ...widget.eventTypes,
      for (final e in events)
        if (!widget.eventTypes.contains(e)) e,
    ];
  }

  Future<void> _addEventType() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Event'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Event name'),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, ctrl.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    if (!mounted) return;
    try {
      await context.read<CategoryProvider>().addCategory('guests', trimmed);
      if (!mounted) return;
      setState(() {
        if (!eventTypes.any((e) => e.toLowerCase() == trimmed.toLowerCase())) {
          eventTypes = [...eventTypes, trimmed];
        }
        events.add(trimmed);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add "$trimmed": $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
    noteCtrl.dispose();
    mealCtrl.dispose();
    giftCtrl.dispose();
    plusOnesCtrl.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    await widget.provider.delete(existing!.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    if (nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }
    final guestName = nameCtrl.text.trim();
    final plusOnes = int.tryParse(plusOnesCtrl.text.trim()) ?? 0;
    setState(() => saving = true);
    try {
      if (existing == null) {
        await widget.provider.add(
          weddingId: context.read<AccessProvider>().cloudWeddingId!,
          name: guestName,
          gender: gender,
          phone: phoneCtrl.text.trim(),
          address: addressCtrl.text.trim(),
          note: noteCtrl.text.trim(),
          category: category,
          events: events,
          rsvpByEvent: rsvpByEvent,
          plusOnes: plusOnes,
          mealPreference: mealCtrl.text.trim(),
          invitationSent: invitationSent,
          giftReceived: giftCtrl.text.trim(),
          thankYouSent: thankYouSent,
        );
      } else {
        await widget.provider.update(existing!.copyWith(
          name: guestName,
          gender: gender,
          phone: phoneCtrl.text.trim(),
          address: addressCtrl.text.trim(),
          note: noteCtrl.text.trim(),
          category: category,
          events: events,
          rsvpByEvent: rsvpByEvent,
          plusOnes: plusOnes,
          mealPreference: mealCtrl.text.trim(),
          invitationSent: invitationSent,
          giftReceived: giftCtrl.text.trim(),
          thankYouSent: thankYouSent,
        ));
      }
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(existing == null ? 'Added "$guestName"' : 'Saved "$guestName"')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: existing == null ? 'Add Guest' : 'Edit Guest',
      saving: saving,
      onSave: _save,
      onDelete: existing == null ? null : _delete,
      onHistory: existing == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HistoryScreen(tableName: 'guests', rowId: existing!.id),
                ),
              ),
      children: [
        FormSection(
          title: 'Details',
          icon: Icons.person_outline,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: existing == null,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.drive_file_rename_outline),
              ),
            ),
            RadioGroup<Gender>(
              groupValue: gender,
              onChanged: (v) => setState(() => gender = v!),
              child: Row(
                children: const [
                  Expanded(
                    child: RadioListTile<Gender>(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Male'),
                      value: Gender.male,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<Gender>(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Female'),
                      value: Gender.female,
                    ),
                  ),
                ],
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: Guest.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => category = v!),
            ),
            TextField(
              controller: plusOnesCtrl,
              decoration: const InputDecoration(
                labelText: 'Plus ones',
                prefixIcon: Icon(Icons.group_add_outlined),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        FormSection(
          title: 'Contact',
          icon: Icons.contact_phone_outlined,
          children: [
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
          ],
        ),
        FormSection(
          title: 'Events & RSVP',
          icon: Icons.event_available_outlined,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _addEventType,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Event'),
              ),
            ),
            ...eventTypes.map((event) {
              final selected = events.contains(event);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: FilterChip(
                        label: Text(event),
                        selected: selected,
                        onSelected: (v) => setState(() {
                          if (v) {
                            events.add(event);
                          } else {
                            events.remove(event);
                            rsvpByEvent.remove(event);
                          }
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (selected)
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<RsvpStatus>(
                          initialValue: rsvpByEvent[event] ?? RsvpStatus.pending,
                          isDense: true,
                          decoration: const InputDecoration(labelText: 'RSVP', isDense: true),
                          items: RsvpStatus.values
                              .map((s) => DropdownMenuItem(value: s, child: Text(_rsvpLabel(s))))
                              .toList(),
                          onChanged: (v) => setState(() => rsvpByEvent[event] = v!),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
        FormSection(
          title: 'Meal & Gifts',
          icon: Icons.card_giftcard_outlined,
          children: [
            TextField(
              controller: mealCtrl,
              decoration: const InputDecoration(
                labelText: 'Meal preference / dietary note',
                prefixIcon: Icon(Icons.restaurant_outlined),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Invitation Sent'),
              secondary: const Icon(Icons.mail_outline),
              value: invitationSent,
              onChanged: (v) => setState(() => invitationSent = v),
            ),
            TextField(
              controller: giftCtrl,
              decoration: const InputDecoration(
                labelText: 'Gift received',
                prefixIcon: Icon(Icons.card_giftcard),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Thank You Sent'),
              secondary: const Icon(Icons.favorite_outline),
              value: thankYouSent,
              onChanged: (v) => setState(() => thankYouSent = v),
            ),
          ],
        ),
        FormSection(
          title: 'Notes',
          icon: Icons.notes_outlined,
          margin: EdgeInsets.zero,
          children: [
            TextField(
              controller: noteCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
              maxLines: 3,
              minLines: 2,
            ),
          ],
        ),
      ],
    );
  }
}

class _EventCountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _EventCountChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$label: $count',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
