import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzData;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tzData.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Manila'));
    } catch (_) {}

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (details) {},
    );
  }

  Future<bool> get isEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications') ?? true;
  }

  Future<void> showLowStockAlert(List<String> productNames) async {
    if (!await isEnabled) return;
    if (productNames.isEmpty) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'low_stock', 'Low Stock Alerts',
        channelDescription: 'Alerts for low product stock',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    final body = productNames.length == 1
        ? productNames.first
        : '${productNames.take(3).join(', ')}${productNames.length > 3 ? ' at iba pa...' : ''}';
    await _plugin.show(1, '⚠️ Mababang Stock!', body, details);
  }

  Future<void> showOutOfStockAlert(List<String> productNames) async {
    if (!await isEnabled) return;
    if (productNames.isEmpty) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'out_of_stock', 'Out of Stock Alerts',
        channelDescription: 'Alerts for out of stock products',
        importance: Importance.max,
        priority: Priority.max,
      ),
    );
    await _plugin.show(
        2, '🚨 Ubos na ang Stock!', productNames.take(3).join(', '), details);
  }

  Future<void> showDailySummary({
    required double revenue,
    required double profit,
    required int transactions,
  }) async {
    if (!await isEnabled) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_summary', 'Daily Sales Summary',
        channelDescription: 'Daily sales summary notification',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _plugin.show(
      3,
      '📊 Buod ng Benta Ngayon',
      'Benta: ₱${revenue.toStringAsFixed(2)} | Kita: ₱${profit.toStringAsFixed(2)} | $transactions transaksyon',
      details,
    );
  }

  Future<void> scheduleStockCheck(
      List<String> lowStock, List<String> outOfStock) async {
    if (outOfStock.isNotEmpty) {
      await showOutOfStockAlert(outOfStock);
    } else if (lowStock.isNotEmpty) {
      await showLowStockAlert(lowStock);
    }
  }

  Future<void> cancelAll() async => _plugin.cancelAll();
}