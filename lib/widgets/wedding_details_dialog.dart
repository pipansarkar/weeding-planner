import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/currency.dart';
import '../providers/access_provider.dart';

/// Shows the bride/groom/date/time/currency editor dialog, pre-filled from
/// [access]'s current wedding info (empty fields for a freshly created
/// wedding), and saves via [AccessProvider.updateWeddingInfo] on confirm.
Future<void> showWeddingDetailsDialog(BuildContext context, AccessProvider access) async {
  final brideCtrl = TextEditingController(text: access.brideName);
  final groomCtrl = TextEditingController(text: access.groomName);
  DateTime? selectedDate = access.weddingDate;
  String currencyCode = access.currencyCode;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Wedding Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: brideCtrl,
                    decoration: const InputDecoration(labelText: "Bride's Name"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: groomCtrl,
                    decoration: const InputDecoration(labelText: "Groom's Name"),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      selectedDate == null
                          ? 'Pick wedding date'
                          : DateFormat('EEEE, MMM d, yyyy – h:mm a').format(selectedDate!),
                    ),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date == null) return;
                      if (!dialogContext.mounted) return;
                      final time = await showTimePicker(
                        context: dialogContext,
                        initialTime: selectedDate != null
                            ? TimeOfDay.fromDateTime(selectedDate!)
                            : const TimeOfDay(hour: 10, minute: 0),
                      );
                      setDialogState(() {
                        selectedDate = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time?.hour ?? 10,
                          time?.minute ?? 0,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: currencyCode,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: Currency.all
                        .map((c) => DropdownMenuItem(
                              value: c.code,
                              child: Text(
                                '${c.code} (${c.symbol}) — ${c.label}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setDialogState(() => currencyCode = v!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await access.updateWeddingInfo(
                    brideName: brideCtrl.text.trim(),
                    groomName: groomCtrl.text.trim(),
                    weddingDate: selectedDate,
                    currencyCode: currencyCode,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}
