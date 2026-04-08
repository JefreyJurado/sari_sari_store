import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _slideAnim = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 3000), () async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final pinEnabled = prefs.getBool('pin_enabled') ?? false;
      if (!mounted) return;
      if (pinEnabled) {
        Navigator.of(context).pushReplacementNamed('/pin');
      } else {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0038A8),
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              ScaleTransition(
                scale: _scaleAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/icon.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.store,
                            color: Colors.white,
                            size: 60),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Welcome message
              FadeTransition(
                opacity: _fadeAnim,
                child: Transform.translate(
                  offset: Offset(0, _slideAnim.value),
                  child: const Text(
                    'Maligayang Pagdating sa',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // App name
              FadeTransition(
                opacity: _fadeAnim,
                child: Transform.translate(
                  offset: Offset(0, _slideAnim.value),
                  child: const Column(children: [
                    Text(
                      'Tinda',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'PH',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                        height: 1.0,
                      ),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 12),

              // Tagline
              FadeTransition(
                opacity: _fadeAnim,
                child: Transform.translate(
                  offset: Offset(0, _slideAnim.value),
                  child: const Text(
                    'Sari-Sari Store Manager',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 80),

              // Loading dots
              FadeTransition(
                opacity: _fadeAnim,
                child: const _LoadingDots(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final delay = i * 0.3;
          final val = (_ctrl.value - delay).clamp(0.0, 1.0);
          final opacity =
              (val < 0.5 ? val * 2 : (1 - val) * 2).clamp(0.3, 1.0);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}