import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/planning_item.dart';
import '../providers/access_provider.dart';
import '../screens/planning_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/custom_list_provider.dart';
import '../providers/wedding_provider.dart';
import '../screens/analyze_screen.dart';
import '../screens/backup_restore_screen.dart';
import '../screens/categories_screen.dart';
import '../screens/collaborators_screen.dart';
import '../screens/create_custom_list_screen.dart';
import '../screens/custom_list_detail_screen.dart';
import '../screens/delete_reset_screen.dart';
import '../screens/emergency_contacts_screen.dart';
import '../screens/export_data_screen.dart';
import '../screens/help_screen.dart';
import '../screens/menu_screen.dart';
import '../screens/mood_board_screen.dart';
import '../screens/seating_chart_screen.dart';
import '../screens/timeline_screen.dart';
import 'wedding_details_dialog.dart';

const Map<String, IconData> _customListIcons = {
  'list_alt': Icons.list_alt,
};

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _addWedding(BuildContext context, {required bool hasCloudWeddings}) async {
    if (hasCloudWeddings) {
      // Cloud is the real multi-wedding system now; create a new cloud
      // wedding, then immediately prompt for its name/date/time so the
      // owner isn't left staring at a blank "Untitled Wedding".
      final access = context.read<AccessProvider>();
      await access.createCloudWedding();
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) await showWeddingDetailsDialog(context, access);
      return;
    }
    final provider = context.read<WeddingProvider>();
    final wedding = await provider.addWedding();
    await provider.setActiveWedding(wedding.id);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          "You'll need a new invite code to rejoin a shared wedding, since this device "
          "doesn't use an email or password to sign back in.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      Navigator.pop(context);
      await context.read<AuthProvider>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final weddingProvider = context.watch<WeddingProvider>();
    final weddings = weddingProvider.weddings;
    final activeId = weddingProvider.activeWeddingId;
    final customLists = context.watch<CustomListProvider>().lists;
    final auth = context.watch<AuthProvider>();
    final access = context.watch<AccessProvider>();
    final myCloudWeddings = access.myWeddings;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      (auth.displayName?.isNotEmpty ?? false) ? auth.displayName![0].toUpperCase() : '?',
                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      auth.displayName?.isNotEmpty ?? false ? auth.displayName! : 'Signed in',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                'Weddings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            ...myCloudWeddings.map((row) {
              final weddingId = (row['weddings'] as Map<String, dynamic>)['id'] as String;
              final isActive = weddingId == access.cloudWeddingId;
              final isOwnerHere = row['role'] == 'owner';
              return ListTile(
                leading: Icon(
                  isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isActive ? Theme.of(context).colorScheme.primary : null,
                ),
                title: Text(AccessProvider.coupleNameFor(row)),
                subtitle: Text(isOwnerHere ? 'Owner' : 'Member'),
                trailing: const Icon(Icons.cloud_outlined, size: 18),
                selected: isActive,
                onTap: () async {
                  await context.read<AccessProvider>().switchWedding(weddingId);
                  if (context.mounted) Navigator.pop(context);
                },
              );
            }),
            if (myCloudWeddings.isNotEmpty) const Divider(height: 1),
            // Once any cloud wedding exists, cloud is the sole source of
            // truth for what's active and listed here (see home_screen.dart)
            // -- local sqflite weddings are legacy leftovers, so they're only
            // shown if the user has never created/joined a cloud wedding.
            if (myCloudWeddings.isEmpty)
              ...weddings.map((wedding) {
                final isActive = wedding.id == activeId;
                return ListTile(
                  leading: Icon(
                    isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isActive ? Theme.of(context).colorScheme.primary : null,
                  ),
                  title: Text(wedding.displayName),
                  selected: isActive,
                  onTap: () async {
                    await context.read<WeddingProvider>().setActiveWedding(wedding.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                );
              }),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add Wedding'),
              onTap: () => _addWedding(context, hasCloudWeddings: myCloudWeddings.isNotEmpty),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Collaborators'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CollaboratorsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Categories'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                );
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'More Tools',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Wedding Schedule'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TimelineScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.emergency),
              title: const Text('Emergency Contacts'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_restaurant),
              title: const Text('Seating Chart'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SeatingChartScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Mood Board'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MoodBoardScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: const Text('Wedding Menu'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MenuScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(planningCategoryIcons[PlanningCategory.accommodation]),
              title: const Text('Accommodation'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AccommodationScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(planningCategoryIcons[PlanningCategory.transportation]),
              title: const Text('Transportation'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TransportationScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(planningCategoryIcons[PlanningCategory.jewelry]),
              title: const Text('Jewelry'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const JewelryScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(planningCategoryIcons[PlanningCategory.food]),
              title: const Text('Food'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FoodPlanningScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(planningCategoryIcons[PlanningCategory.ceremonyVenue]),
              title: const Text('Ceremony & Venue'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CeremonyVenueScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(planningCategoryIcons[PlanningCategory.decorationFlower]),
              title: const Text('Decoration & Flower'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DecorationFlowerScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Analyze'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AnalyzeScreen()),
                );
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Custom Lists',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            ...customLists.map((list) {
              return ListTile(
                leading: Icon(_customListIcons[list.icon] ?? Icons.list_alt),
                title: Text(list.name),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CustomListDetailScreen(listId: list.id),
                    ),
                  );
                },
              );
            }),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add Custom List'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateCustomListScreen()),
                );
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Data',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Export Data'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExportDataScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Backup & Restore'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BackupRestoreScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete & Reset'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DeleteResetScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              onTap: () => _signOut(context),
            ),
          ],
        ),
      ),
    );
  }
}
