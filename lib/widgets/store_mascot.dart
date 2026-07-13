import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum MascotMood { happySales, neutralIdle, lowStock, sleepy, celebrating }

extension on MascotMood {
  // storeph_mascot_low_stock.png and storeph_mascot_sleepy.png ship with
  // swapped content vs. their filenames (low_stock.png is the sleepy/Zzz
  // art, sleepy.png is the worried/empty-shelf art) — mapped by content.
  String get _asset {
    switch (this) {
      case MascotMood.happySales:
        return 'assets/mascot/storeph_mascot_happy_sales.png';
      case MascotMood.neutralIdle:
        return 'assets/mascot/storeph_mascot_neutral_idle.png';
      case MascotMood.lowStock:
        return 'assets/mascot/storeph_mascot_sleepy.png';
      case MascotMood.sleepy:
        return 'assets/mascot/storeph_mascot_low_stock.png';
      case MascotMood.celebrating:
        return 'assets/mascot/storeph_mascot_celebrating.png';
    }
  }
}

/// Mascot card that reflects live store status, with a gentle idle float
/// and a cross-fade when the mood changes.
class StoreMascot extends StatefulWidget {
  final MascotMood mood;
  final String statusText;
  const StoreMascot(
      {super.key, required this.mood, required this.statusText});

  @override
  State<StoreMascot> createState() => _StoreMascotState();
}

class _StoreMascotState extends State<StoreMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bobCtrl;

  @override
  void initState() {
    super.initState();
    _bobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bobCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _bobCtrl,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, -4 * _bobCtrl.value),
              child: child,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Image.asset(
                widget.mood._asset,
                key: ValueKey(widget.mood),
                width: 84,
                height: 84,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                widget.statusText,
                key: ValueKey(widget.statusText),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
