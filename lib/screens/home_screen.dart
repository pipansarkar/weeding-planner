import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/vendor.dart';
import '../providers/access_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/checklist_provider.dart';
import '../providers/guest_provider.dart';
import '../providers/vendor_provider.dart';
import '../theme/palette.dart';
import '../widgets/stat_card.dart';
import '../widgets/root_scaffold_key.dart';
import '../widgets/wedding_details_dialog.dart';
import '../widgets/wedding_hero_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;
  bool _creatingWedding = false;
  String? _createError;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _editDetails(BuildContext context, AccessProvider access) =>
      showWeddingDetailsDialog(context, access);

  Future<void> _createWedding(BuildContext context) async {
    setState(() {
      _creatingWedding = true;
      _createError = null;
    });
    try {
      await context.read<AccessProvider>().createCloudWedding();
    } catch (e) {
      if (mounted) setState(() => _createError = e.toString());
    } finally {
      if (mounted) setState(() => _creatingWedding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessProvider>();
    final hasCloudWedding = access.cloudWeddingId != null;
    final checklist = context.watch<ChecklistProvider>();
    final budget = context.watch<BudgetProvider>();
    final guests = context.watch<GuestProvider>();
    final vendors = context.watch<VendorProvider>();

    if (access.isRestoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!hasCloudWedding) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => rootScaffoldKey.currentState?.openDrawer(),
          ),
          title: const Text('Wedding Planner'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Create a shared wedding or join one with an invite code '
                  'from the Collaborators screen to get started.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _creatingWedding ? null : () => _createWedding(context),
                  child: _creatingWedding
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create shared wedding'),
                ),
                if (_createError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _createError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => rootScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Wedding Planner'),
        actions: [
          if (access.isOwner)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editDetails(context, access),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final weddingId = access.cloudWeddingId!;
          final checklistProvider = context.read<ChecklistProvider>();
          final budgetProvider = context.read<BudgetProvider>();
          final guestProvider = context.read<GuestProvider>();
          final vendorProvider = context.read<VendorProvider>();
          await checklistProvider.load(weddingId: weddingId);
          await budgetProvider.load(weddingId: weddingId);
          await guestProvider.load(weddingId: weddingId);
          await vendorProvider.load(weddingId: weddingId);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            WeddingHeroCard(
              brideName: access.brideName,
              groomName: access.groomName,
              isOwner: access.isOwner,
              weddingDate: access.weddingDate,
              onEditNames: () => _editDetails(context, access),
              onEditDate: () => _editDetails(context, access),
            ),
            const SizedBox(height: 20),
            Text('At a Glance', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                StatCard(
                  label: 'Checklist Done',
                  value: '${checklist.completedCount}/${checklist.items.length}',
                  icon: Icons.checklist,
                  color: statPalette[0],
                ),
                StatCard(
                  label: 'Checklist Pending',
                  value: '${checklist.pendingCount}',
                  icon: Icons.pending_actions,
                  color: statPalette[1],
                ),
                StatCard(
                  label: 'Budget Spent',
                  value: NumberFormat.compact().format(budget.totalActual),
                  icon: Icons.savings,
                  color: statPalette[2],
                ),
                StatCard(
                  label: 'Budget Estimated',
                  value: NumberFormat.compact().format(budget.totalEstimated),
                  icon: Icons.account_balance_wallet,
                  color: statPalette[3],
                ),
                StatCard(
                  label: 'Total Guests',
                  value: '${guests.totalHeadcount}',
                  icon: Icons.people,
                  color: statPalette[4],
                ),
                StatCard(
                  label: 'Vendors Reserved',
                  value: '${vendors.countForStatus(VendorStatus.reserved)}/${vendors.vendors.length}',
                  icon: Icons.storefront,
                  color: statPalette[5],
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
