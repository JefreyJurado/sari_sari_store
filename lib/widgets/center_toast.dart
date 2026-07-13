import 'package:flutter/material.dart';

/// A brief, centered confirmation popup — replaces the bottom SnackBar
/// so messages aren't missed off-screen or behind the keyboard/bottom nav.
class CenterToast {
  static OverlayEntry? _current;

  static void showSuccess(BuildContext context, String message) => _show(
        context,
        message,
        icon: Icons.check_circle_outline,
        color: Colors.green,
      );

  static void showError(BuildContext context, String message) => _show(
        context,
        message,
        icon: Icons.error_outline,
        color: Colors.red,
        duration: const Duration(milliseconds: 2000),
      );

  static void showWarning(BuildContext context, String message) => _show(
        context,
        message,
        icon: Icons.warning_amber_outlined,
        color: Colors.orange,
        duration: const Duration(milliseconds: 1800),
      );

  static void _show(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color color,
    Duration duration = const Duration(milliseconds: 1400),
  }) {
    _current?.remove();
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CenterToastWidget(
        message: message,
        icon: icon,
        color: color,
        duration: duration,
        onDone: () {
          entry.remove();
          if (identical(_current, entry)) _current = null;
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _CenterToastWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color color;
  final Duration duration;
  final VoidCallback onDone;
  const _CenterToastWidget({
    required this.message,
    required this.icon,
    required this.color,
    required this.duration,
    required this.onDone,
  });

  @override
  State<_CenterToastWidget> createState() => _CenterToastWidgetState();
}

class _CenterToastWidgetState extends State<_CenterToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _ctrl.forward();
    _schedule();
  }

  Future<void> _schedule() async {
    await Future.delayed(widget.duration);
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _ctrl,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 56),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 26),
                  ),
                  const SizedBox(height: 10),
                  Text(widget.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
