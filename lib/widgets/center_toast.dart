import 'package:flutter/material.dart';

/// A brief, centered confirmation popup — replaces the bottom SnackBar
/// for success messages so they're not missed off-screen or behind the
/// keyboard/bottom nav.
class CenterToast {
  static OverlayEntry? _current;

  static void showSuccess(BuildContext context, String message) {
    _current?.remove();
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CenterToastWidget(
        message: message,
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
  final VoidCallback onDone;
  const _CenterToastWidget({required this.message, required this.onDone});

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
    await Future.delayed(const Duration(milliseconds: 1400));
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
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_outline,
                        color: Colors.green, size: 26),
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
