import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _blue = Color(0xFF1E3A8A);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_seen') ?? false;
    if (!seen) {
      await _askName(prefs);
    } else {
      final pinEnabled = prefs.getBool('pin_enabled') ?? false;
      if (mounted) {
        Navigator.of(context)
            .pushReplacementNamed(pinEnabled ? '/pin' : '/home');
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Welcome! 👋',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600,
                color: Colors.black87)),
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
              hintStyle:
                  TextStyle(color: Colors.grey[400], fontSize: 13),
              prefixIcon: Icon(Icons.person_outlined,
                  color: Colors.grey[500], size: 18),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: Colors.grey.shade300)),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              await prefs.setBool('onboarding_seen', true);
              if (mounted) Navigator.pop(context);
            },
            child: Text('Skip',
                style: TextStyle(
                    color: Colors.grey[600], fontSize: 13)),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Done!',
                style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    final pinEnabled = prefs.getBool('pin_enabled') ?? false;
    Navigator.of(context)
        .pushReplacementNamed(pinEnabled ? '/pin' : '/home');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _blue,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Image.asset(
                      'assets/icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.store,
                          color: Colors.white,
                          size: 56),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // App name
                const Text(
                  'TindaPH',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),

                // Tagline
                Text(
                  'Sari-Sari Store Manager',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}