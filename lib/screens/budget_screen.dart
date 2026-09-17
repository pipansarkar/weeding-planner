import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/budget_item.dart';
import '../models/currency.dart';
import '../providers/access_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../services/notification_service.dart';
import '../widgets/form_sheet.dart';
import '../widgets/request_access_banner.dart';
import '../widgets/root_scaffold_key.dart';
import 'history_screen.dart';

String _paymentStatusLabel(PaymentStatus status) {
  switch (status) {
    case PaymentStatus.unpaid:
      return 'Unpaid';
    case PaymentStatus.partiallyPaid:
      return 'Partially Paid';
    case PaymentStatus.paidInFull:
      return 'Paid in Full';
  }
}

Color _paymentStatusColor(PaymentStatus status) {
  switch (status) {
    case PaymentStatus.unpaid:
      return Colors.red;
    case PaymentStatus.partiallyPaid:
      return Colors.orange;
    case PaymentStatus.paidInFull:
      return Colors.green;
  }
}

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  Future<void> _openForm(BuildContext context, {BudgetItem? existing}) async {
    final provider = context.read<BudgetProvider>();
    final categories = context.read<CategoryProvider>().categoriesFor('budget');
    if (existing != null && !categories.contains(existing.category)) {
      categories.add(existing.category);
    }
    await showFormSheet<void>(
      context,
      _BudgetForm(provider: provider, categories: categories, existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BudgetProvider>();
    final items = provider.items;
    final currencyCode = context.watch<AccessProvider>().currencyCode;
    final currency = NumberFormat.currency(
      symbol: Currency.byCode(currencyCode).symbol,
      decimalDigits: 0,
    );
    final overdue = provider.overduePayments;
    final access = context.watch<AccessProvider>();
    final hasAccess = access.cloudWeddingId == null || access.hasApprovedAccess('budget');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => rootScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Budget'),
      ),
      body: !hasAccess
          ? const RequestAccessBanner(section: 'budget')
          : items.isEmpty && overdue.isEmpty
          ? const Center(child: Text('No budget items yet. Tap + to add one.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SummaryBox(
                        label: 'Estimated',
                        value: currency.format(provider.totalEstimated),
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryBox(
                        label: 'Actual Spent',
                        value: currency.format(provider.totalActual),
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                if (overdue.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${overdue.length} payment${overdue.length == 1 ? '' : 's'} overdue',
                            style: const TextStyle(
                                color: Colors.red, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ...items.map((item) {
                  final overdueItem = item.dueDate != null &&
                      item.paymentStatus != PaymentStatus.paidInFull &&
                      item.dueDate!.isBefore(DateTime.now());
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => _openForm(context, existing: item),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text([
                                    item.category,
                                    if (item.note.isNotEmpty) item.note,
                                  ].join(' • ')),
                                  if (item.dueDate != null)
                                    Text(
                                      'Due ${DateFormat('MMM d, yyyy').format(item.dueDate!)}',
                                      style: TextStyle(
                                        color: overdueItem ? Colors.red : null,
                                        fontWeight: overdueItem ? FontWeight.bold : null,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  currency.format(item.actualAmount),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'est. ${currency.format(item.estimatedAmount)}',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                                const SizedBox(height: 4),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(_paymentStatusLabel(item.paymentStatus),
                                      style: const TextStyle(fontSize: 10)),
                                  backgroundColor: _paymentStatusColor(item.paymentStatus)
                                      .withValues(alpha: 0.15),
                                  labelStyle:
                                      TextStyle(color: _paymentStatusColor(item.paymentStatus)),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
      floatingActionButton: !hasAccess
          ? null
          : FloatingActionButton(
              heroTag: 'budget_fab',
              onPressed: () => _openForm(context),
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _BudgetForm extends StatefulWidget {
  final BudgetProvider provider;
  final List<String> categories;
  final BudgetItem? existing;

  const _BudgetForm({
    required this.provider,
    required this.categories,
    required this.existing,
  });

  @override
  State<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<_BudgetForm> {
  late final TextEditingController nameCtrl;
  late final TextEditingController estCtrl;
  late final TextEditingController actCtrl;
  late final TextEditingController noteCtrl;
  late final TextEditingController methodCtrl;
  late final TextEditingController paidByCtrl;
  late String category;
  DateTime? dueDate;
  late PaymentStatus status;
  bool saving = false;

  BudgetItem? get existing => widget.existing;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: existing?.name ?? '');
    estCtrl = TextEditingController(
        text: existing != null && existing!.estimatedAmount != 0
            ? existing!.estimatedAmount.toString()
            : '');
    actCtrl = TextEditingController(
        text: existing != null && existing!.actualAmount != 0
            ? existing!.actualAmount.toString()
            : '');
    noteCtrl = TextEditingController(text: existing?.note ?? '');
    methodCtrl = TextEditingController(text: existing?.paymentMethod ?? '');
    paidByCtrl = TextEditingController(text: existing?.paidBy ?? '');
    category = existing?.category ?? widget.categories.first;
    dueDate = existing?.dueDate;
    status = existing?.paymentStatus ?? PaymentStatus.unpaid;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    estCtrl.dispose();
    actCtrl.dispose();
    noteCtrl.dispose();
    methodCtrl.dispose();
    paidByCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => dueDate = picked);
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
    final est = double.tryParse(estCtrl.text.trim()) ?? 0;
    final act = double.tryParse(actCtrl.text.trim()) ?? 0;
    setState(() => saving = true);
    try {
      String itemId;
      if (existing == null) {
        itemId = await widget.provider.add(
          weddingId: context.read<AccessProvider>().cloudWeddingId!,
          name: itemName,
          category: category,
          estimatedAmount: est,
          actualAmount: act,
          note: noteCtrl.text.trim(),
          dueDate: dueDate,
          paymentMethod: methodCtrl.text.trim(),
          paidBy: paidByCtrl.text.trim(),
          paymentStatus: status,
        );
      } else {
        itemId = existing!.id;
        await widget.provider.update(existing!.copyWith(
          name: itemName,
          category: category,
          estimatedAmount: est,
          actualAmount: act,
          note: noteCtrl.text.trim(),
          dueDate: dueDate,
          paymentMethod: methodCtrl.text.trim(),
          paidBy: paidByCtrl.text.trim(),
          paymentStatus: status,
        ));
      }
      await NotificationService.instance.cancelReminder(itemId);
      if (dueDate != null && status != PaymentStatus.paidInFull) {
        await NotificationService.instance.scheduleReminder(
          sourceId: itemId,
          title: 'Payment due: $itemName',
          body: '$category payment is due today',
          dateTime: DateTime(dueDate!.year, dueDate!.month, dueDate!.day, 9),
        );
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
      title: existing == null ? 'Add Budget Item' : 'Edit Item',
      saving: saving,
      onSave: _save,
      onDelete: existing == null ? null : _delete,
      onHistory: existing == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HistoryScreen(tableName: 'budget_items', rowId: existing!.id),
                ),
              ),
      children: [
        FormSection(
          title: 'Details',
          icon: Icons.receipt_long_outlined,
          children: [
            TextField(
              controller: nameCtrl,
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
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: widget.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => category = v!),
            ),
          ],
        ),
        FormSection(
          title: 'Cost',
          icon: Icons.payments_outlined,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: estCtrl,
                    decoration: const InputDecoration(labelText: 'Estimated'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: actCtrl,
                    decoration: const InputDecoration(labelText: 'Actual'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            DropdownButtonFormField<PaymentStatus>(
              initialValue: status,
              decoration: const InputDecoration(
                labelText: 'Payment Status',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: PaymentStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(_paymentStatusLabel(s))))
                  .toList(),
              onChanged: (v) => setState(() => status = v!),
            ),
            FormPickerField(
              label: 'Payment due date',
              value: dueDate == null ? 'Pick a date' : DateFormat('MMM d, yyyy').format(dueDate!),
              icon: Icons.event,
              onTap: _pickDate,
            ),
          ],
        ),
        FormSection(
          title: 'Payment Info',
          icon: Icons.credit_card_outlined,
          children: [
            TextField(
              controller: methodCtrl,
              decoration: const InputDecoration(
                labelText: 'Payment method',
                hintText: 'Cash, card, transfer',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
            ),
            TextField(
              controller: paidByCtrl,
              decoration: const InputDecoration(
                labelText: 'Paid by',
                prefixIcon: Icon(Icons.person_outline),
              ),
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

class _SummaryBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
