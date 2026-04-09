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

  bool _showButton = false;
  bool _isFirstLaunch = true;

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
          curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.7, curve: Curves.elasticOut)),
    );
    _slideAnim = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.3, 0.9, curve: Curves.easeOut)),
    );

    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_seen') ?? false;

    if (seen) {
      // Hindi na first launch — skip onboarding
      setState(() => _isFirstLaunch = false);
      _controller.forward();
      Future.delayed(const Duration(milliseconds: 2200), () async {
        if (!mounted) return;
        final pinEnabled = prefs.getBool('pin_enabled') ?? false;
        if (pinEnabled) {
          Navigator.of(context).pushReplacementNamed('/pin');
        } else {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      });
    } else {
      // First launch — ipakita ang onboarding
      setState(() => _isFirstLaunch = true);
      _controller.forward().then((_) {
        if (mounted) setState(() => _showButton = true);
      });
    }
  }

  Future<void> _getStarted() async {
    final prefs = await SharedPreferences.getInstance();
    // Itanong ang pangalan bago mag-proceed
    if (!mounted) return;
    await _askName(prefs);
  }

  Future<void> _askName(SharedPreferences prefs) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Kumusta! 👋',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'Ano ang iyong pangalan?\nGagamitin ito para sa personalized na greeting.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'hal: Maria, Juan...',
              prefixIcon: const Icon(Icons.person_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              // Skip — walang pangalan
              await prefs.setBool('onboarding_seen', true);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Presto na',
                style: TextStyle(color: Colors.grey)),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Tapos na!'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    final pinEnabled = prefs.getBool('pin_enabled') ?? false;
    if (pinEnabled) {
      Navigator.of(context).pushReplacementNamed('/pin');
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1565C0),
              Color(0xFF0038A8),
              Color(0xFF1A237E),
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Logo
                ScaleTransition(
                  scale: _scaleAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.asset(
                          'assets/icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.store, color: Colors.white, size: 70),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Welcome text
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Transform.translate(
                    offset: Offset(0, _slideAnim.value),
                    child: const Text(
                      'Maligayang Pagdating sa',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        letterSpacing: 0.5,
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
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'PH',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6,
                          height: 1.0,
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // Tagline
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Transform.translate(
                    offset: Offset(0, _slideAnim.value),
                    child: const Text(
                      'Your Sari-Sari Store Manager',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // Dots indicator
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == 1 ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == 1
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                  ),
                ),

                const SizedBox(height: 40),

                // GET STARTED button — first launch only
                if (_isFirstLaunch)
                  AnimatedOpacity(
                    opacity: _showButton ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 500),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: GestureDetector(
                        onTap: _getStarted,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFFD700),
                                Color(0xFFFFA000),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700)
                                    .withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Magsimula Na',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  // Loading dots para sa returning users
                  const _LoadingDots(),

                const SizedBox(height: 48),
              ],
            ),
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
            width: 10, height: 10,
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