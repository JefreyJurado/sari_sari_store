import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

// Correct imports for database
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/lista_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/pin_screen.dart';
import 'services/notification_service.dart';
import 'services/database_service.dart';
import 'data/default_products.dart';

const _blue = Color(0xFF1E3A8A);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database based on platform
  if (kIsWeb) {
    // For Web platform - just set the factory, no init needed
    databaseFactory = databaseFactoryFfiWeb;
  } else {
    // For Desktop/Mobile platforms
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await DatabaseService.instance.database;
  await NotificationService.instance.initialize();
  await DefaultProducts.seedIfEmpty();

  runApp(const TindaPHApp());
}

class TindaPHApp extends StatelessWidget {
  const TindaPHApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider()..initialize(),
      child: MaterialApp(
        title: 'TindaPH',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: _blue),
          textTheme: GoogleFonts.poppinsTextTheme(),
        ),
        initialRoute: '/splash',
        routes: {
          '/splash': (_) => const SplashScreen(),
          '/pin': (_) => const PinScreen(),
          '/home': (_) => const MainShell(),
        },
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  final _screens = const [
    HomeScreen(),
    SalesScreen(),
    ListaScreen(),
    InventoryScreen(),
    ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, Icons.home_outlined, 'Home'),
            _navItem(1, Icons.point_of_sale_outlined, 'Sales'),
            _navItem(2, Icons.list_alt_outlined, 'Credit'),
            _navItem(3, Icons.inventory_2_outlined, 'Products'),
            _navItem(4, Icons.bar_chart_outlined, 'Reports'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _tab == index;
    return IconButton(
      icon: Icon(icon, color: selected ? _blue : Colors.black54),
      onPressed: () => setState(() => _tab = index),
    );
  }
}