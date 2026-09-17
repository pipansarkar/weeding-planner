import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/currency.dart';
import '../models/planning_item.dart';
import '../providers/access_provider.dart';
import '../providers/guest_provider.dart';
import '../providers/planning_provider.dart';
import '../providers/vendor_provider.dart';
import '../widgets/request_access_banner.dart';

const planningCategoryIcons = {
  PlanningCategory.accommodation: Icons.hotel_outlined,
  PlanningCategory.transportation: Icons.directions_car_outlined,
  PlanningCategory.jewelry: Icons.diamond_outlined,
  PlanningCategory.food: Icons.restaurant_outlined,
  PlanningCategory.ceremonyVenue: Icons.location_city_outlined,
  PlanningCategory.decorationFlower: Icons.local_florist_outlined,
};

/// Six standalone drawer screens (Accommodation, Transportation, Jewelry,
/// Food, Ceremony & Venue, Decoration & Flower), each just a thin Scaffold
/// wrapper around the shared [_PlanningCategoryView] -- same fields and
/// save/error behavior per category, but reachable directly from the
/// drawer instead of behind a single tabbed "Planning" screen.

class AccommodationScreen extends StatelessWidget {
  const AccommodationScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const _PlanningCategoryView(category: PlanningCategory.accommodation);
}

class TransportationScreen extends StatelessWidget {
  const TransportationScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const _PlanningCategoryView(category: PlanningCategory.transportation);
}

class JewelryScreen extends StatelessWidget {
  const JewelryScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const _PlanningCategoryView(category: PlanningCategory.jewelry);
}

class FoodPlanningScreen extends StatelessWidget {
  const FoodPlanningScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const _PlanningCategoryView(category: PlanningCategory.food);
}

class CeremonyVenueScreen extends StatelessWidget {
  const CeremonyVenueScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const _PlanningCategoryView(category: PlanningCategory.ceremonyVenue);
}

class DecorationFlowerScreen extends StatelessWidget {
  const DecorationFlowerScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const _PlanningCategoryView(category: PlanningCategory.decorationFlower);
}

class _PlanningCategoryView extends StatelessWidget {
  final PlanningCategory category;

  const _PlanningCategoryView({required this.category});

  Future<void> _openForm(BuildContext context, {PlanningItem? existing, required String currencySymbol}) async {
    final provider = context.read<PlanningProvider>();
    final access = context.read<AccessProvider>();
    final weddingId = access.cloudWeddingId!;
    final guests = context.read<GuestProvider>().guests;
    final vendors = context.read<VendorProvider>().vendors
        .where((v) => v.category == category.budgetCategory || v.category == category.label)
        .toList();
    final brideName = access.brideName.trim().isEmpty ? 'Bride' : access.brideName.trim();
    final groomName = access.groomName.trim().isEmpty ? 'Groom' : access.groomName.trim();

    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final qtyCtrl = TextEditingController(text: (existing?.quantity ?? 1).toStringAsFixed(0));
    final priceCtrl = TextEditingController(
        text: existing != null && existing.unitPrice > 0 ? existing.unitPrice.toStringAsFixed(0) : '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    final eventNameCtrl = TextEditingController(text: existing?.eventName ?? '');
    final venueNameCtrl = TextEditingController(text: existing?.venueName ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final fromCtrl = TextEditingController(text: existing?.fromLocation ?? '');
    final toCtrl = TextEditingController(text: existing?.toLocation ?? '');

    // Combined "for whom" selection: null = unspecified, 'bride'/'groom' =
    // the couple themselves, 'guest:<id>' = a specific Guest row.
    String? forWhom = existing?.forCouple ??
        (existing?.guestId != null ? 'guest:${existing!.guestId}' : null);
    String? vendorId = existing?.vendorId;
    PlanningStatus status = existing?.status ?? PlanningStatus.planned;
    DateTime? eventDate = existing?.eventDate;
    DateTime? startDate = existing?.startDate;
    DateTime? endDate = existing?.endDate;
    String vehicleType = existing?.vehicleType.isNotEmpty == true ? existing!.vehicleType : PlanningItem.vehicleTypes.first;
    String occasion = existing?.occasion.isNotEmpty == true ? existing!.occasion : PlanningItem.occasions.first;
    String course = existing?.course.isNotEmpty == true ? existing!.course : PlanningItem.courses.first;
    final placementCtrl = TextEditingController(text: existing?.placement ?? '');

    Future<DateTime?> pickDate(BuildContext ctx, DateTime? initial) => showDatePicker(
          context: ctx,
          initialDate: initial ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              scrollable: true,
              title: Text(existing == null ? 'Add ${category.label} Item' : 'Edit Item'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: forWhom,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'For whom (optional)'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Not specific to anyone')),
                      DropdownMenuItem<String?>(value: 'bride', child: Text(brideName, overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem<String?>(value: 'groom', child: Text(groomName, overflow: TextOverflow.ellipsis)),
                      ...guests.map((g) => DropdownMenuItem<String?>(
                            value: 'guest:${g.id}',
                            child: Text(g.name, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => setDialogState(() => forWhom = v),
                  ),
                  const SizedBox(height: 12),
                  if (category == PlanningCategory.transportation) ...[
                    DropdownButtonFormField<String>(
                      initialValue: vehicleType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Vehicle type'),
                      items: PlanningItem.vehicleTypes
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => vehicleType = v!),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: fromCtrl,
                            decoration: const InputDecoration(labelText: 'From'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: toCtrl,
                            decoration: const InputDecoration(labelText: 'To'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(eventDate == null ? 'Pick date & time' : DateFormat('MMM d, yyyy').format(eventDate!)),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final picked = await pickDate(dialogContext, eventDate);
                        if (picked != null) setDialogState(() => eventDate = picked);
                      },
                    ),
                  ] else if (category == PlanningCategory.accommodation) ...[
                    TextField(
                      controller: venueNameCtrl,
                      decoration: const InputDecoration(labelText: 'Room / place name'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(startDate == null ? 'Check-in' : DateFormat('MMM d').format(startDate!)),
                            onTap: () async {
                              final picked = await pickDate(dialogContext, startDate);
                              if (picked != null) setDialogState(() => startDate = picked);
                            },
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(endDate == null ? 'Check-out' : DateFormat('MMM d').format(endDate!)),
                            onTap: () async {
                              final picked = await pickDate(dialogContext, endDate);
                              if (picked != null) setDialogState(() => endDate = picked);
                            },
                          ),
                        ),
                      ],
                    ),
                  ] else if (category == PlanningCategory.jewelry) ...[
                    DropdownButtonFormField<String>(
                      initialValue: occasion,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Occasion'),
                      items: PlanningItem.occasions
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => occasion = v!),
                    ),
                  ] else if (category == PlanningCategory.food) ...[
                    DropdownButtonFormField<String>(
                      initialValue: course,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Course'),
                      items: PlanningItem.courses
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => course = v!),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(eventDate == null ? 'Serving date' : DateFormat('MMM d, yyyy').format(eventDate!)),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final picked = await pickDate(dialogContext, eventDate);
                        if (picked != null) setDialogState(() => eventDate = picked);
                      },
                    ),
                  ] else if (category == PlanningCategory.ceremonyVenue) ...[
                    TextField(
                      controller: eventNameCtrl,
                      decoration: const InputDecoration(labelText: 'Event / ceremony name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: venueNameCtrl,
                      decoration: const InputDecoration(labelText: 'Venue name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(eventDate == null ? 'Pick date' : DateFormat('MMM d, yyyy').format(eventDate!)),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final picked = await pickDate(dialogContext, eventDate);
                        if (picked != null) setDialogState(() => eventDate = picked);
                      },
                    ),
                  ] else if (category == PlanningCategory.decorationFlower) ...[
                    TextField(
                      controller: placementCtrl,
                      decoration: const InputDecoration(labelText: 'Where to put them'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          decoration: const InputDecoration(labelText: 'Quantity'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          decoration: InputDecoration(labelText: 'Price per unit ($currencySymbol)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: vendorId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Vendor (optional)'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('No vendor linked')),
                      ...vendors.map((v) => DropdownMenuItem<String?>(
                            value: v.id,
                            child: Text(v.name, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => setDialogState(() => vendorId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PlanningStatus>(
                    initialValue: status,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: PlanningStatus.values
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => status = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: 'Note'),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                if (existing != null)
                  TextButton(
                    onPressed: () async {
                      await provider.delete(existing.id);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    final itemTitle = titleCtrl.text.trim();
                    final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1;
                    final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
                    final forCouple = forWhom == 'bride' || forWhom == 'groom' ? forWhom : null;
                    final guestId = forWhom != null && forWhom!.startsWith('guest:')
                        ? forWhom!.substring('guest:'.length)
                        : null;
                    final draft = PlanningItem(
                      id: existing?.id ?? '',
                      weddingId: weddingId,
                      category: category,
                      title: itemTitle,
                      guestId: guestId,
                      forCouple: forCouple,
                      vendorId: vendorId,
                      budgetItemId: existing?.budgetItemId,
                      quantity: qty,
                      unitPrice: price,
                      status: status,
                      note: noteCtrl.text.trim(),
                      eventName: eventNameCtrl.text.trim(),
                      venueName: venueNameCtrl.text.trim(),
                      address: addressCtrl.text.trim(),
                      eventDate: eventDate,
                      startDate: startDate,
                      endDate: endDate,
                      fromLocation: fromCtrl.text.trim(),
                      toLocation: toCtrl.text.trim(),
                      vehicleType: category == PlanningCategory.transportation ? vehicleType : '',
                      occasion: category == PlanningCategory.jewelry ? occasion : '',
                      course: category == PlanningCategory.food ? course : '',
                      placement: placementCtrl.text.trim(),
                    );
                    try {
                      if (existing == null) {
                        await provider.add(draft);
                      } else {
                        await provider.update(draft);
                      }
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(existing == null ? 'Added "$itemTitle"' : 'Saved "$itemTitle"')),
                        );
                      }
                    } catch (e) {
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not save: $e')),
                        );
                      }
                    }
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

  String _subtitleFor(PlanningItem item, GuestProvider guestProvider, VendorProvider vendorProvider, AccessProvider access) {
    final parts = <String>[];
    if (item.forCouple == 'bride') {
      parts.add('For ${access.brideName.trim().isEmpty ? 'Bride' : access.brideName.trim()}');
    } else if (item.forCouple == 'groom') {
      parts.add('For ${access.groomName.trim().isEmpty ? 'Groom' : access.groomName.trim()}');
    } else if (item.guestId != null) {
      final guest = guestProvider.guests.where((g) => g.id == item.guestId);
      if (guest.isNotEmpty) parts.add('For ${guest.first.name}');
    }
    switch (item.category) {
      case PlanningCategory.accommodation:
        if (item.venueName.isNotEmpty) parts.add(item.venueName);
        if (item.startDate != null && item.endDate != null) {
          parts.add('${DateFormat('MMM d').format(item.startDate!)} - ${DateFormat('MMM d').format(item.endDate!)}');
        }
        break;
      case PlanningCategory.transportation:
        if (item.vehicleType.isNotEmpty) parts.add(item.vehicleType);
        if (item.fromLocation.isNotEmpty || item.toLocation.isNotEmpty) {
          parts.add('${item.fromLocation} → ${item.toLocation}');
        }
        if (item.eventDate != null) parts.add(DateFormat('MMM d, yyyy').format(item.eventDate!));
        break;
      case PlanningCategory.jewelry:
        if (item.occasion.isNotEmpty) parts.add(item.occasion);
        break;
      case PlanningCategory.food:
        if (item.course.isNotEmpty) parts.add(item.course);
        if (item.eventDate != null) parts.add(DateFormat('MMM d, yyyy').format(item.eventDate!));
        break;
      case PlanningCategory.ceremonyVenue:
        if (item.eventName.isNotEmpty) parts.add(item.eventName);
        if (item.venueName.isNotEmpty) parts.add(item.venueName);
        if (item.eventDate != null) parts.add(DateFormat('MMM d, yyyy').format(item.eventDate!));
        break;
      case PlanningCategory.decorationFlower:
        if (item.placement.isNotEmpty) parts.add('at ${item.placement}');
        break;
    }
    parts.add('Qty ${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)}');
    if (item.vendorId != null) {
      final vendor = vendorProvider.vendors.where((v) => v.id == item.vendorId);
      if (vendor.isNotEmpty) parts.add('via ${vendor.first.name}');
    }
    return parts.join(' • ');
  }

  Color _statusColor(PlanningStatus status) {
    switch (status) {
      case PlanningStatus.planned:
        return Colors.grey;
      case PlanningStatus.booked:
        return Colors.blue;
      case PlanningStatus.purchased:
        return Colors.orange;
      case PlanningStatus.done:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final planningProvider = context.watch<PlanningProvider>();
    final guestProvider = context.watch<GuestProvider>();
    final vendorProvider = context.watch<VendorProvider>();
    final access = context.watch<AccessProvider>();
    final hasAccess = access.cloudWeddingId == null || access.hasApprovedAccess('planning');
    final currencySymbol = Currency.byCode(access.currencyCode).symbol;

    final items = planningProvider.forCategory(category);
    final total = planningProvider.totalForCategory(category);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(planningCategoryIcons[category], size: 22),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                category.label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: !hasAccess
          ? const RequestAccessBanner(section: 'planning')
          : Column(
              children: [
                if (items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Total: $currencySymbol${total.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Text('No ${category.label.toLowerCase()} items yet. Tap + to add one.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                title: Text(item.title),
                                subtitle: Text(_subtitleFor(item, guestProvider, vendorProvider, access)),
                                trailing: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (item.totalPrice > 0) ...[
                                      Text('$currencySymbol${item.totalPrice.toStringAsFixed(0)}',
                                          style: Theme.of(context).textTheme.labelLarge),
                                      const SizedBox(height: 4),
                                    ],
                                    Chip(
                                      label: Text(item.status.label),
                                      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                      padding: EdgeInsets.zero,
                                      backgroundColor: _statusColor(item.status).withValues(alpha: 0.15),
                                      labelStyle: TextStyle(
                                        color: _statusColor(item.status),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () => _openForm(context, existing: item, currencySymbol: currencySymbol),
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
              heroTag: 'planning_fab_${category.dbValue}',
              onPressed: () => _openForm(context, currencySymbol: currencySymbol),
              child: const Icon(Icons.add),
            ),
    );
  }
}
