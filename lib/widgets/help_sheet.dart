import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

const _blue = AppColors.blue;

/// Friendly "how this screen works" bottom sheet, triggered by a small
/// help icon on each screen — so an unfamiliar store owner can get a
/// plain-language explanation exactly where they're confused, without
/// hunting through a separate help section.
class HelpSheet {
  static void show(
    BuildContext context, {
    required String title,
    required List<String> points,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetCtx).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lightbulb_outline,
                        color: _blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87)),
                  ),
                ]),
                const SizedBox(height: 18),
                ...points.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: _blue,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(p,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.4,
                                    color: Colors.grey[700])),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Got it',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
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

/// Small circular help-icon button — drop into any AppBar actions row or
/// custom header row to wire up [HelpSheet.show] with one line.
class HelpIconButton extends StatelessWidget {
  final String title;
  final List<String> points;
  final Color? color;
  const HelpIconButton({
    super.key,
    required this.title,
    required this.points,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.help_outline, color: color ?? Colors.black54, size: 22),
      tooltip: 'How this works',
      onPressed: () => HelpSheet.show(context, title: title, points: points),
    );
  }
}
