import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/supabase_config.dart';
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
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  NotificationService.instance.init();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AccessProvider()),
        ChangeNotifierProvider(create: (_) => WeddingProvider()..load()),
        ChangeNotifierProvider(create: (_) => ChecklistProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProxyProvider<BudgetProvider, PlanningProvider>(
          create: (context) => PlanningProvider(context.read<BudgetProvider>()),
          update: (_, budget, previous) => previous ?? PlanningProvider(budget),
        ),
        ChangeNotifierProvider(create: (_) => GuestProvider()),
        ChangeNotifierProvider(create: (_) => VendorProvider()),
        ChangeNotifierProvider(create: (_) => TimelineProvider()),
        ChangeNotifierProvider(create: (_) => EmergencyContactProvider()),
        ChangeNotifierProvider(create: (_) => SeatingProvider()),
        ChangeNotifierProvider(create: (_) => MoodBoardProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
        ChangeNotifierProvider(create: (_) => CustomListProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
      ],
      child: MaterialApp(
        title: 'Wedding Planner',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: const AuthGate(),
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1E3A5F),
    brightness: brightness,
  );
  final scaffoldColor = isDark ? const Color(0xFF0F1216) : const Color(0xFFFAFAFA);
  final fieldFill = isDark
      ? scheme.surfaceContainerHighest.withValues(alpha: 0.5)
      : scheme.surfaceContainerHighest.withValues(alpha: 0.5);
  final dialogSurface = isDark ? const Color(0xFF1A1F26) : Colors.white;
  final baseTextTheme = GoogleFonts.interTextTheme(
    isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scaffoldColor,
    textTheme: baseTextTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: scaffoldColor,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? const Color(0xFF181C22) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? const Color(0xFF14181D) : Colors.white,
      indicatorColor: scheme.primary.withValues(alpha: 0.12),
      elevation: 0,
      labelTextStyle: WidgetStateProperty.all(
        GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dialogSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: scheme.onSurface,
      ),
      contentTextStyle: GoogleFonts.inter(fontSize: 14, color: scheme.onSurfaceVariant),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      labelStyle: GoogleFonts.inter(color: scheme.onSurfaceVariant),
      floatingLabelStyle: GoogleFonts.inter(color: scheme.primary, fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: fieldFill,
      selectedColor: scheme.primary.withValues(alpha: 0.16),
      labelStyle: GoogleFonts.inter(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
