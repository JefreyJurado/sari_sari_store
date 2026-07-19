import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/center_toast.dart';
import '../services/biometric_service.dart';

class PinScreen extends StatefulWidget {
  final bool isSetup;
  const PinScreen({super.key, this.isSetup = false});
  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _hasError = false;
  String _errorMsg = '';
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
    // Only the lock screen (not PIN setup/change) offers biometric unlock.
    if (!widget.isSetup) _initBiometric();
  }

  Future<void> _initBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('biometric_enabled') ?? false;
    if (!mounted) return;
    setState(() => _biometricEnabled = enabled);
    if (enabled) {
      // Brief delay so the lock screen is visible for a moment before the
      // system biometric prompt overlays it, rather than popping up
      // instantly on a still-blank screen.
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    final success =
        await BiometricService.instance.authenticate('Unlock StorePH');
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
    // On failure/cancel: no error shown — the PIN keypad underneath is
    // always the expected fallback, not an error state.
  }

  Future<void> _forgotPin() async {
    final secured = await BiometricService.instance.isDeviceSecured();
    if (!mounted) return;
    if (!secured) {
      _showNoRecoveryDialog();
      return;
    }

    final verified = await BiometricService.instance.authenticateForReset(
        "Verify it's you to reset your StorePH PIN");
    if (!verified || !mounted) return;

    // Setup screen pops with `true` on success (see _verifySetup) — that
    // pop lands back here, so we finish the job by continuing to Home.
    final createdNewPin = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PinScreen(isSetup: true)),
    );
    if (createdNewPin == true && mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  void _showNoRecoveryDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('No Screen Lock Found',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
        content: const Text(
          "StorePH resets your PIN by verifying your phone's own screen lock "
          "(fingerprint, face, PIN, or pattern) — but this phone doesn't have "
          "one set up, so there's no way to confirm it's you.\n\n"
          "The only way back in is clearing StorePH's app data or reinstalling "
          "it, which will erase all sales, inventory, and other data. To avoid "
          "this in the future, set up a screen lock on your phone.",
          style: TextStyle(fontSize: 13, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Understood',
                style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onKey(String key) {
    setState(() => _hasError = false);

    if (key == 'del') {
      if (widget.isSetup && _isConfirming) {
        if (_confirmPin.isNotEmpty) {
          setState(() => _confirmPin =
              _confirmPin.substring(0, _confirmPin.length - 1));
        }
      } else {
        if (_pin.isNotEmpty) {
          setState(() =>
              _pin = _pin.substring(0, _pin.length - 1));
        }
      }
      return;
    }

    if (widget.isSetup) {
      if (!_isConfirming) {
        if (_pin.length < 4) {
          setState(() => _pin += key);
          if (_pin.length == 4) {
            Future.delayed(const Duration(milliseconds: 300),
                () => setState(() => _isConfirming = true));
          }
        }
      } else {
        if (_confirmPin.length < 4) {
          setState(() => _confirmPin += key);
          if (_confirmPin.length == 4) {
            _verifySetup();
          }
        }
      }
    } else {
      if (_pin.length < 4) {
        setState(() => _pin += key);
        if (_pin.length == 4) {
          _verifyPin();
        }
      }
    }
  }

  Future<void> _verifySetup() async {
    if (_pin == _confirmPin) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_pin', _pin);
      await prefs.setBool('pin_enabled', true);
      if (mounted) {
        Navigator.pop(context, true);
        CenterToast.showSuccess(context, 'PIN set successfully!');
      }
    } else {
      _shakeCtrl.forward(from: 0);
      setState(() {
        _hasError = true;
        _errorMsg = 'PINs do not match. Try again.';
        _confirmPin = '';
        _pin = '';
        _isConfirming = false;
      });
    }
  }

  Future<void> _verifyPin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('app_pin') ?? '';
    if (_pin == savedPin) {
      if (mounted) {
    Navigator.pushReplacementNamed(context, '/home');
    }
    } else {
      _shakeCtrl.forward(from: 0);
      setState(() {
        _hasError = true;
        _errorMsg = 'Incorrect PIN. Try again.';
        _pin = '';
      });
    }
  }

  String get _currentPin =>
      widget.isSetup && _isConfirming ? _confirmPin : _pin;

  String get _title {
    if (widget.isSetup) {
      return _isConfirming ? 'Confirm PIN' : 'Create PIN';
    }
    return 'Enter PIN';
  }

  String get _subtitle {
    if (widget.isSetup) {
      return _isConfirming
          ? 'Confirm your new PIN'
          : 'Choose a 4-digit PIN for security';
    }
    return 'Enter your PIN to continue';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isSetup
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('Setup PIN',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.blue, AppColors.blueDark],
          ),
        ),
        child: SafeArea(
        child: Column(children: [
          const Spacer(),

          // Logo
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/icon.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.store,
                    color: Colors.white,
                    size: 40),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            _title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _subtitle,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),

          // PIN dots with shake animation
          AnimatedBuilder(
            animation: _shakeAnim,
            builder: (_, child) => Transform.translate(
              offset: Offset(
                _shakeAnim.value *
                    10 *
                    (1 - _shakeCtrl.value) *
                    ((_shakeCtrl.value * 10).toInt().isEven
                        ? 1
                        : -1),
                0,
              ),
              child: child,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _currentPin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 10),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _hasError
                        ? Colors.red
                        : filled
                            ? Colors.white
                            : Colors.transparent,
                    border: Border.all(
                      color: _hasError
                          ? Colors.red
                          : Colors.white54,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
          ),

          // Error message
          const SizedBox(height: 16),
          AnimatedOpacity(
            opacity: _hasError ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              _errorMsg,
              style: const TextStyle(
                  color: Colors.redAccent, fontSize: 14),
            ),
          ),

          if (!widget.isSetup) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _forgotPin,
              child: const Text('Forgot PIN?',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ],

          const Spacer(),

          // Keypad
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 48),
            child: Column(children: [
              for (final row in [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
                ['', '0', 'del'],
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceEvenly,
                    children: row.map((k) {
                      if (k.isEmpty) {
                        if (!widget.isSetup && _biometricEnabled) {
                          return _KeyButton(
                              label: 'bio', onTap: _tryBiometric);
                        }
                        return const SizedBox(width: 72);
                      }
                      return _KeyButton(
                        label: k,
                        onTap: () => _onKey(k),
                      );
                    }).toList(),
                  ),
                ),
            ]),
          ),

          const SizedBox(height: 32),
        ]),
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _KeyButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDel = label == 'del';
    final isBio = label == 'bio';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.12),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1),
        ),
        child: Center(
          child: isDel
              ? const Icon(Icons.backspace_outlined,
                  color: Colors.white, size: 24)
              : isBio
                  ? const Icon(Icons.fingerprint,
                      color: Colors.white, size: 28)
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
        ),
      ),
    );
  }
}