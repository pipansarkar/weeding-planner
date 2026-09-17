import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/emergency_contact.dart';
import '../providers/access_provider.dart';
import '../providers/emergency_contact_provider.dart';
import '../widgets/form_sheet.dart';
import '../widgets/request_access_banner.dart';
import 'history_screen.dart';

class EmergencyContactsScreen extends StatelessWidget {
  const EmergencyContactsScreen({super.key});

  Future<void> _openForm(BuildContext context, {EmergencyContact? existing}) async {
    final provider = context.read<EmergencyContactProvider>();
    await showFormSheet<void>(context, _EmergencyContactForm(provider: provider, existing: existing));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmergencyContactProvider>();
    final contacts = provider.contacts;
    final access = context.watch<AccessProvider>();
    final hasAccess = access.cloudWeddingId == null || access.hasApprovedAccess('emergency_contacts');

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      body: !hasAccess
          ? const RequestAccessBanner(section: 'emergency_contacts')
          : contacts.isEmpty
          ? const Center(child: Text('No emergency contacts yet. Tap + to add one.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.phone)),
                    title: Text(contact.name),
                    subtitle: Text(
                      [
                        if (contact.role.isNotEmpty) contact.role,
                        if (contact.phone.isNotEmpty) contact.phone,
                      ].join(' • '),
                    ),
                    onTap: () => _openForm(context, existing: contact),
                  ),
                );
              },
            ),
      floatingActionButton: !hasAccess
          ? null
          : FloatingActionButton(
              heroTag: 'emergency_contacts_fab',
              onPressed: () => _openForm(context),
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _EmergencyContactForm extends StatefulWidget {
  final EmergencyContactProvider provider;
  final EmergencyContact? existing;

  const _EmergencyContactForm({required this.provider, required this.existing});

  @override
  State<_EmergencyContactForm> createState() => _EmergencyContactFormState();
}

class _EmergencyContactFormState extends State<_EmergencyContactForm> {
  late final TextEditingController nameCtrl;
  late final TextEditingController roleCtrl;
  late final TextEditingController phoneCtrl;
  bool saving = false;

  EmergencyContact? get existing => widget.existing;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: existing?.name ?? '');
    roleCtrl = TextEditingController(text: existing?.role ?? '');
    phoneCtrl = TextEditingController(text: existing?.phone ?? '');
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    roleCtrl.dispose();
    phoneCtrl.dispose();
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
    final itemName = nameCtrl.text.trim();
    setState(() => saving = true);
    try {
      if (existing == null) {
        await widget.provider.add(
          weddingId: context.read<AccessProvider>().cloudWeddingId!,
          name: itemName,
          role: roleCtrl.text.trim(),
          phone: phoneCtrl.text.trim(),
        );
      } else {
        await widget.provider.update(existing!.copyWith(
          name: itemName,
          role: roleCtrl.text.trim(),
          phone: phoneCtrl.text.trim(),
        ));
      }
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(existing == null ? 'Added "$itemName"' : 'Saved "$itemName"')),
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
      title: existing == null ? 'Add Emergency Contact' : 'Edit Contact',
      saving: saving,
      onSave: _save,
      onDelete: existing == null ? null : _delete,
      onHistory: existing == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      HistoryScreen(tableName: 'emergency_contacts', rowId: existing!.id),
                ),
              ),
      children: [
        FormSection(
          title: 'Details',
          icon: Icons.emergency_outlined,
          margin: EdgeInsets.zero,
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
            TextField(
              controller: roleCtrl,
              decoration: const InputDecoration(
                labelText: 'Role',
                hintText: 'Coordinator, venue manager, etc.',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ],
    );
  }
}
