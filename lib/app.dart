import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/access_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/category_provider.dart';
import 'providers/checklist_provider.dart';
import 'providers/custom_list_provider.dart';
import 'providers/emergency_contact_provider.dart';
import 'providers/guest_provider.dart';
import 'providers/menu_provider.dart';
import 'providers/mood_board_provider.dart';
import 'providers/planning_provider.dart';
import 'providers/seating_provider.dart';
import 'providers/timeline_provider.dart';
import 'providers/vendor_provider.dart';
import 'providers/wedding_provider.dart';
import 'screens/budget_screen.dart';
import 'screens/checklist_screen.dart';
import 'screens/guest_screen.dart';
import 'screens/home_screen.dart';
import 'screens/set_display_name_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/vendor_screen.dart';
import 'widgets/app_drawer.dart';
import 'widgets/root_scaffold_key.dart';

/// Gates the app behind Supabase auth: signed out -> [SignInScreen],
/// signed in but no display name yet -> [SetDisplayNameScreen],
/// otherwise -> the existing [WeddingPlannerApp].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isSignedIn) return const SignInScreen();
    if (auth.profileLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (auth.displayName == null || auth.displayName!.isEmpty) {
      return const SetDisplayNameScreen();
    }
    return const WeddingPlannerApp();
  }
}

class WeddingPlannerApp extends StatefulWidget {
  const WeddingPlannerApp({super.key});

  @override
  State<WeddingPlannerApp> createState() => _WeddingPlannerAppState();
}

class _WeddingPlannerAppState extends State<WeddingPlannerApp> {
  int _index = 0;
  String? _loadedWeddingId;
  String? _loadedCloudWeddingId;

  static const _screens = [
    HomeScreen(),
    ChecklistScreen(),
    BudgetScreen(),
    GuestScreen(),
    VendorScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WeddingProvider>().addListener(_onWeddingChanged);
      context.read<AccessProvider>().addListener(_onCloudWeddingChanged);
      _onWeddingChanged();
      _onCloudWeddingChanged();
    });
  }

  @override
  void dispose() {
    context.read<WeddingProvider>().removeListener(_onWeddingChanged);
    context.read<AccessProvider>().removeListener(_onCloudWeddingChanged);
    super.dispose();
  }

  // Mood board is the only remaining domain still on the legacy local
  // sqflite wedding (Storage migration deferred to its own pass).
  void _onWeddingChanged() {
    final weddingId = context.read<WeddingProvider>().activeWeddingId;
    if (weddingId == null || weddingId == _loadedWeddingId) return;
    _loadedWeddingId = weddingId;
    context.read<MoodBoardProvider>().load(weddingId: weddingId);
  }

  // Guests (Phase 2) plus budget, vendors, checklist, timeline, emergency
  // contacts, seating, menu, and custom lists (Phase 3) are all cloud-backed
  // (Supabase) now, driven by the collaborative wedding rather than the
  // legacy local sqflite wedding.
  void _onCloudWeddingChanged() {
    final cloudWeddingId = context.read<AccessProvider>().cloudWeddingId;
    if (cloudWeddingId == null || cloudWeddingId == _loadedCloudWeddingId) return;
    _loadedCloudWeddingId = cloudWeddingId;
    context.read<GuestProvider>().load(weddingId: cloudWeddingId);
    context.read<BudgetProvider>().load(weddingId: cloudWeddingId);
    context.read<VendorProvider>().load(weddingId: cloudWeddingId);
    context.read<ChecklistProvider>().load(weddingId: cloudWeddingId);
    context.read<TimelineProvider>().load(weddingId: cloudWeddingId);
    context.read<EmergencyContactProvider>().load(weddingId: cloudWeddingId);
    context.read<SeatingProvider>().load(weddingId: cloudWeddingId);
    context.read<MenuProvider>().load(weddingId: cloudWeddingId);
    context.read<CustomListProvider>().load(weddingId: cloudWeddingId);
    context.read<CategoryProvider>().load(weddingId: cloudWeddingId);
    context.read<PlanningProvider>().load(weddingId: cloudWeddingId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: rootScaffoldKey,
      drawer: const AppDrawer(),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: 'Checklist'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Budget'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Guests'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Vendors'),
        ],
      ),
    );
  }
}
