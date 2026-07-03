import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/lista_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/pin_screen.dart';
import 'services/notification_service.dart';
import 'services/database_service.dart';
import 'data/default_products.dart';

const _blue = Color(0xFF1E3A8A);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite for Windows/Linux/macOS
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  } else {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  await DatabaseService.instance.database;
  
  try {
    await NotificationService.instance.initialize();
  } catch (_) {}
  try {
    await DefaultProducts.seedIfEmpty();
  } catch (_) {}
  
  runApp(const StorePHApp());
}

class _SlideFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _SlideFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const curve = Curves.easeOutCubic;
    final slideAnim = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: curve));

    return SlideTransition(
      position: slideAnim,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: curve),
        child: child,
      ),
    );
  }
}

class StorePHApp extends StatelessWidget {
  const StorePHApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // FIXED: Separated data instantiation from the build framework loop to prevent layout race conditions
      create: (_) => AppProvider()..initialize(),
      child: MaterialApp(
          title: 'StorePH',
          debugShowCheckedModeBanner: false,
          shortcuts: {
            ...WidgetsApp.defaultShortcuts,
            const SingleActivator(LogicalKeyboardKey.backspace): const ActivateIntent(),
          },
          builder: (context, widget) {
            ErrorWidget.builder = (errorDetails) {
              if (errorDetails.exception.toString().contains('_dependents.isEmpty')) {
                return const SizedBox.shrink();
              }
              return ErrorWidget(errorDetails.exception);
            };
            if (widget != null) return widget;
            return const Scaffold(
              backgroundColor: Colors.white,
              body: SizedBox.shrink(),
            );
          },
          theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _blue,
            brightness: Brightness.light,
          ),
          pageTransitionsTheme: PageTransitionsTheme(
            builders: {
              TargetPlatform.android: const _SlideFadePageTransitionsBuilder(),
              TargetPlatform.iOS: const _SlideFadePageTransitionsBuilder(),
              TargetPlatform.windows: const _SlideFadePageTransitionsBuilder(),
              TargetPlatform.macOS: const _SlideFadePageTransitionsBuilder(),
              TargetPlatform.linux: const _SlideFadePageTransitionsBuilder(),
            },
          ),
          textTheme: GoogleFonts.poppinsTextTheme(),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
            titleTextStyle: GoogleFonts.poppins(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: _blue,
            foregroundColor: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            ),
          ),
        ),
        home: const _StartupRouter(),
        routes: {
          '/pin': (_) => const PinScreen(),
          '/home': (_) => const _MainShell(),
        },
      ),
    );
  }
}

class _StartupRouter extends StatefulWidget {
  const _StartupRouter();
  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  @override
  void initState() {
    super.initState();
    // FIXED: Safely invoke data fetching immediately after the widget mounts to the tree
    Future.microtask(() {
      if (mounted) {
        context.read<AppProvider>().initialize();
      }
    });
    _route();
  }

  Future<void> _route() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_seen') ?? false;
    if (!seen) {
      await _askName(prefs);
    } else {
      final pinEnabled = prefs.getBool('pin_enabled') ?? false;
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(pinEnabled ? '/pin' : '/home');
      }
    }
  }

  Future<void> _askName(SharedPreferences prefs) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Welcome! 👋',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'What is your name?\nThis will be used for your greeting.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'e.g. Maria, Juan...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              prefixIcon: Icon(Icons.person_outlined, color: Colors.grey[500], size: 18),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              await prefs.setBool('onboarding_seen', true);
              if (mounted) Navigator.pop(context);
            },
            child: Text('Skip', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              await prefs.setBool('onboarding_seen', true);
              if (name.isNotEmpty) {
                await prefs.setString('user_name', name);
              }
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Done!', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    final prefs2 = await SharedPreferences.getInstance();
    final pinEnabled = prefs2.getBool('pin_enabled') ?? false;
    Navigator.of(context).pushReplacementNamed(pinEnabled ? '/pin' : '/home');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1E3A8A),
      body: Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      ),
    );
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell();
  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _tab = 0;

  final _screens = const [
    HomeScreen(),
    SalesScreen(),
    ListaScreen(),
    InventoryScreen(),
    ReportsScreen(),
  ];

  static const _tabColors = [
    _blue,
    Color(0xFF059669),
    Color(0xFFEA580C),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        layoutBuilder: (currentChild, previousChildren) => Stack(
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        ),
        child: KeyedSubtree(
          key: ValueKey(_tab),
          child: IndexedStack(index: _tab, children: _screens),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
                _navItem(1, Icons.point_of_sale_rounded, Icons.point_of_sale_outlined, 'Sales'),
                _navItem(2, Icons.list_alt_rounded, Icons.list_alt_outlined, 'Credit'),
                _navItem(3, Icons.inventory_2_rounded, Icons.inventory_2_outlined, 'Products'),
                _navItem(4, Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Reports'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData filledIcon, IconData outlineIcon, String label) {
    final selected = _tab == index;
    final color = _tabColors[index];
    return GestureDetector(
      onTap: () {
        if (_tab != index) {
          HapticFeedback.selectionClick();
          setState(() => _tab = index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: selected ? 1.15 : 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.elasticOut,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: child,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Icon(
                  selected ? filledIcon : outlineIcon,
                  key: ValueKey(selected),
                  size: 22,
                  color: selected ? color : Colors.grey[500],
                ),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : Colors.grey[500],
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}