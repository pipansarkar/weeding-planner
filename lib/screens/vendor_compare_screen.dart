import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/currency.dart';
import '../models/vendor.dart';
import '../providers/access_provider.dart';
import '../providers/vendor_provider.dart';

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

class VendorCompareScreen extends StatelessWidget {
  const VendorCompareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VendorProvider>();
    final grouped = provider.vendorsByCategory;
    final currencyCode = context.watch<AccessProvider>().currencyCode;
    final currency = NumberFormat.currency(
      symbol: Currency.byCode(currencyCode).symbol,
      decimalDigits: 0,
    );
    final categories = grouped.keys.toList()..sort();
    final multiVendorCategories =
        categories.where((c) => grouped[c]!.length > 1).toList();
    final singleVendorCategories =
        categories.where((c) => grouped[c]!.length <= 1).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Compare Vendors')),
      body: categories.isEmpty
          ? const Center(child: Text('No vendors to compare yet.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (multiVendorCategories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Add more than one vendor in the same category to compare them side by side.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                for (final category in multiVendorCategories) ...[
                  Text(category, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Amount')),
                        DataColumn(label: Text('Phone')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Note')),
                      ],
                      rows: (grouped[category]!..sort((a, b) => a.amount.compareTo(b.amount)))
                          .map((v) => DataRow(cells: [
                                DataCell(Text(v.name)),
                                DataCell(Text(
                                    v.amount == 0 ? '-' : currency.format(v.amount))),
                                DataCell(Text(v.phone.isEmpty ? '-' : v.phone)),
                                DataCell(Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(_statusLabel(v.status),
                                      style: const TextStyle(fontSize: 11)),
                                  backgroundColor:
                                      _statusColor(v.status).withValues(alpha: 0.15),
                                  labelStyle: TextStyle(color: _statusColor(v.status)),
                                )),
                                DataCell(Text(v.note.isEmpty ? '-' : v.note)),
                              ]))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                if (singleVendorCategories.isNotEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Other Categories', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  for (final category in singleVendorCategories)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(grouped[category]!.first.name),
                      subtitle: Text(category),
                      trailing: Text(grouped[category]!.first.amount == 0
                          ? '-'
                          : currency.format(grouped[category]!.first.amount)),
                    ),
                ],
              ],
            ),
    );
  }
}
