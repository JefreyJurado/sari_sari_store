import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ProfitChart extends StatelessWidget {
  final List<Map<String, dynamic>> dailyData;

  const ProfitChart({super.key, required this.dailyData});

  @override
  Widget build(BuildContext context) {
    if (dailyData.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(
            child: Text('Walang data',
                style: TextStyle(color: Colors.grey))),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < dailyData.length; i++) {
      final rev =
          (dailyData[i]['revenue'] as num?)?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), rev));
    }

    final maxY =
        spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 160,
      child: LineChart(LineChartData(
        minY: 0,
        maxY: maxY == 0 ? 100 : maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.withValues(alpha: 0.15),
              strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= dailyData.length) {
                  return const SizedBox();
                }
                final day =
                    dailyData[idx]['day'] as String? ?? '';
                final label =
                    day.length >= 10 ? day.substring(5) : day;
                return Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: Colors.grey));
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF2E7D32),
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF2E7D32)
                  .withValues(alpha: 0.1),
            ),
            dotData: FlDotData(
              show: spots.length <= 14,
              getDotPainter: (_, __, ___, ____) =>
                  FlDotCirclePainter(
                radius: 4,
                color: const Color(0xFF2E7D32),
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
          ),
        ],
      )),
    );
  }
}