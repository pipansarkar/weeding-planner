import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../data/schedule_presets.dart';
import '../models/timeline_event.dart';
import '../providers/access_provider.dart';
import '../providers/category_provider.dart';
import '../providers/timeline_provider.dart';
import '../widgets/form_sheet.dart';
import '../widgets/request_access_banner.dart';
import 'history_screen.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _openTemplatePicker(BuildContext context) async {
    final timelineProvider = context.read<TimelineProvider>();
    final access = context.read<AccessProvider>();
    final cloudWeddingId = access.cloudWeddingId;
    if (cloudWeddingId == null) return;
    final baseDate = access.weddingDate ?? DateTime.now();

    final selected = {for (final preset in kSchedulePresets) preset.title: true};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Add Preset Schedule'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: kSchedulePresets.map((preset) {
                    final time = TimeOfDay(hour: preset.hour, minute: preset.minute);
                    return CheckboxListTile(
                      value: selected[preset.title],
                      title: Text(preset.title),
                      subtitle: Text(time.format(dialogContext)),
                      onChanged: (value) {
                        setDialogState(() => selected[preset.title] = value ?? false);
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Add Selected'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final events = kSchedulePresets.where((preset) => selected[preset.title] == true).map((preset) {
      return TimelineEvent(
        id: const Uuid().v4(),
        weddingId: cloudWeddingId,
        title: preset.title,
        category: preset.category,
        time: DateTime(baseDate.year, baseDate.month, baseDate.day, preset.hour, preset.minute),
      );
    }).toList();

    await timelineProvider.addAll(events);
  }

  Future<void> _openForm(BuildContext context, {TimelineEvent? existing}) async {
    final provider = context.read<TimelineProvider>();
    final categories = context.read<CategoryProvider>().categoriesFor('timeline');
    if (existing != null && !categories.contains(existing.category)) {
      categories.add(existing.category);
    }
    await showFormSheet<void>(
      context,
      _TimelineForm(provider: provider, categories: categories, existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimelineProvider>();
    final events = provider.events;
    final access = context.watch<AccessProvider>();
    final hasAccess = access.cloudWeddingId == null || access.hasApprovedAccess('timeline');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wedding Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Add preset schedule',
            onPressed: () => _openTemplatePicker(context),
          ),
        ],
      ),
      body: !hasAccess
          ? const RequestAccessBanner(section: 'timeline')
          : events.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No schedule items yet.'),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _openTemplatePicker(context),
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Use preset schedule'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                final showDateHeader = index == 0 ||
                    !_isSameDay(events[index - 1].time, event.time);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showDateHeader)
                      Padding(
                        padding: EdgeInsets.only(bottom: 8, top: index == 0 ? 0 : 8),
                        child: Text(
                          DateFormat('EEEE, MMM d, yyyy').format(event.time),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: SizedBox(
                          width: 56,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('h:mm').format(event.time),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                DateFormat('a').format(event.time),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        title: Text(event.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              event.category,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            if (event.note.isNotEmpty) Text(event.note),
                          ],
                        ),
                        onTap: () => _openForm(context, existing: event),
                      ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: !hasAccess
          ? null
          : FloatingActionButton(
              heroTag: 'timeline_fab',
              onPressed: () => _openForm(context),
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _TimelineForm extends StatefulWidget {
  final TimelineProvider provider;
  final List<String> categories;
  final TimelineEvent? existing;

  const _TimelineForm({
    required this.provider,
    required this.categories,
    required this.existing,
  });

  @override
  State<_TimelineForm> createState() => _TimelineFormState();
}

class _TimelineFormState extends State<_TimelineForm> {
  late final TextEditingController titleCtrl;
  late final TextEditingController noteCtrl;
  late DateTime time;
  late String category;
  bool saving = false;

  TimelineEvent? get existing => widget.existing;

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: existing?.title ?? '');
    noteCtrl = TextEditingController(text: existing?.note ?? '');
    time = existing?.time ?? DateTime.now();
    category = existing?.category ?? widget.categories.last;
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: time,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(time),
    );
    setState(() {
      time = DateTime(
        date.year,
        date.month,
        date.day,
        pickedTime?.hour ?? time.hour,
        pickedTime?.minute ?? time.minute,
      );
    });
  }

  Future<void> _delete() async {
    await widget.provider.delete(existing!.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    if (titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }
    final eventTitle = titleCtrl.text.trim();
    setState(() => saving = true);
    try {
      if (existing == null) {
        await widget.provider.add(
          weddingId: context.read<AccessProvider>().cloudWeddingId!,
          title: eventTitle,
          category: category,
          time: time,
          note: noteCtrl.text.trim(),
        );
      } else {
        await widget.provider.update(existing!.copyWith(
          title: eventTitle,
          category: category,
          time: time,
          note: noteCtrl.text.trim(),
        ));
      }
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(existing == null ? 'Added "$eventTitle"' : 'Saved "$eventTitle"')),
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
      title: existing == null ? 'Add Schedule Item' : 'Edit Schedule Item',
      saving: saving,
      onSave: _save,
      onDelete: existing == null ? null : _delete,
      onHistory: existing == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HistoryScreen(tableName: 'timeline_events', rowId: existing!.id),
                ),
              ),
      children: [
        FormSection(
          title: 'Details',
          icon: Icons.event_note_outlined,
          children: [
            TextField(
              controller: titleCtrl,
              autofocus: existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.drive_file_rename_outline),
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: category,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Event Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: widget.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => category = value);
              },
            ),
          ],
        ),
        FormSection(
          title: 'Schedule',
          icon: Icons.schedule,
          children: [
            FormPickerField(
              label: 'Date & time',
              value: DateFormat('MMM d, yyyy – h:mm a').format(time),
              icon: Icons.schedule,
              onTap: _pickTime,
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
