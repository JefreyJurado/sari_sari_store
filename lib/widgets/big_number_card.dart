import 'package:flutter/material.dart';

// Your app's signature blue color
const _blue = Color(0xFF1E3A8A);

class BigNumberCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const BigNumberCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon, // Removed color from constructor parameters
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon wrapper utilizing your theme blue color with light opacity
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(icon, color: _blue, size: 20),
          ),
          const SizedBox(height: 10),
          // Main metrics value styled in solid blue
          Text(
            value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: _blue),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
                color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }
}