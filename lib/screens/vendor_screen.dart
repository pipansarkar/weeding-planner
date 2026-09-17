import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/currency.dart';
import '../models/vendor.dart';
import '../providers/access_provider.dart';
import '../providers/category_provider.dart';
import '../providers/vendor_provider.dart';
import '../widgets/form_sheet.dart';
import '../widgets/request_access_banner.dart';
import '../widgets/root_scaffold_key.dart';
import 'history_screen.dart';
import 'vendor_compare_screen.dart';

Color _statusColor(VendorStatus status) {
  switch (status) {
    case VendorStatus.reserved:
      return Colors.green;
    case VendorStatus.pending:
      return Colors.orange;
    case VendorStatus.rejected:
      return Colors.red;
  }
}

String _statusLabel(VendorStatus status) {
  switch (status) {
    case VendorStatus.reserved:
      return 'Reserved';
    case VendorStatus.pending:
      return 'Pending';
    case VendorStatus.rejected:
      return 'Rejected';
  }
}

class VendorScreen extends StatelessWidget {
  const VendorScreen({super.key});

  Future<void> _openForm(BuildContext context, {Vendor? existing}) async {
    final provider = context.read<VendorProvider>();
    final categories = context.read<CategoryProvider>().categoriesFor('vendors');
    if (existing != null && !categories.contains(existing.category)) {
      categories.add(existing.category);
    }
    await showFormSheet<void>(
      context,
      _VendorForm(provider: provider, categories: categories, existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VendorProvider>();
    final vendors = provider.vendors;
    final currencyCode = context.watch<AccessProvider>().currencyCode;
    final currency = NumberFormat.currency(
      symbol: Currency.byCode(currencyCode).symbol,
      decimalDigits: 0,
    );
    final access = context.watch<AccessProvider>();
    final hasAccess = access.cloudWeddingId == null || access.hasApprovedAccess('vendors');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => rootScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Vendors'),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: 'Compare Vendors',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const VendorCompareScreen()),
            ),
          ),
        ],
      ),
      body: !hasAccess
          ? const RequestAccessBanner(section: 'vendors')
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: VendorStatus.values.map((status) {
                final count = provider.countForStatus(status);
                final color = _statusColor(status);
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        Text(
                          _statusLabel(status),
                          style: TextStyle(fontSize: 11, color: color),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: vendors.isEmpty
                ? const Center(child: Text('No vendors yet. Tap + to add one.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: vendors.length,
                    itemBuilder: (context, index) {
                      final vendor = vendors[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(vendor.name),
                          subtitle: Text(
                            [
                              vendor.category,
                              if (vendor.phone.isNotEmpty) vendor.phone,
                              if (vendor.amount != 0)
                                currency.format(vendor.amount),
                            ].join(' • '),
                          ),
                          trailing: Chip(
                            label: Text(_statusLabel(vendor.status)),
                            backgroundColor: _statusColor(
                              vendor.status,
                            ).withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: _statusColor(vendor.status),
                              fontSize: 12,
                            ),
                          ),
                          onTap: () => _openForm(context, existing: vendor),
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
              heroTag: 'vendor_fab',
              onPressed: () => _openForm(context),
              child: const Icon(Icons.add_business),
            ),
    );
  }
}

class _VendorForm extends StatefulWidget {
  final VendorProvider provider;
  final List<String> categories;
  final Vendor? existing;

  const _VendorForm({
    required this.provider,
    required this.categories,
    required this.existing,
  });

  @override
  State<_VendorForm> createState() => _VendorFormState();
}

class _VendorFormState extends State<_VendorForm> {
  late final TextEditingController nameCtrl;
  late final TextEditingController phoneCtrl;
  late final TextEditingController siteCtrl;
  late final TextEditingController addressCtrl;
  late final TextEditingController amountCtrl;
  late final TextEditingController noteCtrl;
  late final TextEditingController logNoteCtrl;
  late String category;
  late VendorStatus status;
  bool saving = false;

  Vendor? get existing => widget.existing;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: existing?.name ?? '');
    phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    siteCtrl = TextEditingController(text: existing?.site ?? '');
    addressCtrl = TextEditingController(text: existing?.address ?? '');
    amountCtrl = TextEditingController(
      text: existing != null && existing!.amount != 0 ? existing!.amount.toString() : '',
    );
    noteCtrl = TextEditingController(text: existing?.note ?? '');
    logNoteCtrl = TextEditingController();
    category = existing?.category ?? widget.categories.first;
    status = existing?.status ?? VendorStatus.pending;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    siteCtrl.dispose();
    addressCtrl.dispose();
    amountCtrl.dispose();
    noteCtrl.dispose();
    logNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _addLog() async {
    if (logNoteCtrl.text.trim().isEmpty) return;
    await widget.provider.addContactLog(
      weddingId: context.read<AccessProvider>().cloudWeddingId!,
      vendorId: existing!.id,
      date: DateTime.now(),
      note: logNoteCtrl.text.trim(),
    );
    logNoteCtrl.clear();
    setState(() {});
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
    final vendorName = nameCtrl.text.trim();
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    setState(() => saving = true);
    try {
      if (existing == null) {
        await widget.provider.add(
          weddingId: context.read<AccessProvider>().cloudWeddingId!,
          name: vendorName,
          category: category,
          phone: phoneCtrl.text.trim(),
          site: siteCtrl.text.trim(),
          address: addressCtrl.text.trim(),
          amount: amount,
          status: status,
          note: noteCtrl.text.trim(),
        );
      } else {
        await widget.provider.update(existing!.copyWith(
          name: vendorName,
          category: category,
          phone: phoneCtrl.text.trim(),
          site: siteCtrl.text.trim(),
          address: addressCtrl.text.trim(),
          amount: amount,
          status: status,
          note: noteCtrl.text.trim(),
        ));
      }
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(existing == null ? 'Added "$vendorName"' : 'Saved "$vendorName"')),
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
      title: existing == null ? 'Add Vendor' : 'Edit Vendor',
      saving: saving,
      onSave: _save,
      onDelete: existing == null ? null : _delete,
      onHistory: existing == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HistoryScreen(tableName: 'vendors', rowId: existing!.id),
                ),
              ),
      children: [
        FormSection(
          title: 'Details',
          icon: Icons.storefront_outlined,
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
            DropdownButtonFormField<String>(
              initialValue: category,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: widget.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => category = v!),
            ),
            DropdownButtonFormField<VendorStatus>(
              initialValue: status,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: VendorStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(_statusLabel(s))))
                  .toList(),
              onChanged: (v) => setState(() => status = v!),
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
              controller: siteCtrl,
              decoration: const InputDecoration(
                labelText: 'Website / Social',
                prefixIcon: Icon(Icons.link),
              ),
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
          title: 'Cost',
          icon: Icons.payments_outlined,
          children: [
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        FormSection(
          title: 'Notes',
          icon: Icons.notes_outlined,
          margin: existing == null ? EdgeInsets.zero : const EdgeInsets.only(bottom: 16),
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
        if (existing != null)
          FormSection(
            title: 'Contact Log',
            icon: Icons.chat_bubble_outline,
            margin: EdgeInsets.zero,
            children: [
              ...widget.provider.logsForVendor(existing!.id).map(
                    (log) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.chat_bubble_outline, size: 18),
                      title: Text(log.note.isEmpty ? '(no note)' : log.note),
                      subtitle: Text(DateFormat('MMM d, yyyy').format(log.date)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () async {
                          await widget.provider.deleteContactLog(log.id);
                          setState(() {});
                        },
                      ),
                    ),
                  ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: logNoteCtrl,
                      decoration: const InputDecoration(labelText: 'Log a call/message'),
                      onSubmitted: (_) => _addLog(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add),
                    onPressed: _addLog,
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}
