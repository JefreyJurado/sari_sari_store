import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
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
    // Translated string concatenation to English format
    final body = productNames.length == 1
        ? productNames.first
        : '${productNames.take(3).join(', ')}${productNames.length > 3 ? ' and others...' : ''}';

    // Translated title from '⚠️ Mababang Stock!'
    try {
      await _plugin.show(1, '⚠️ Low Stock!', body, details);
    } catch (_) {}
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
    
    // Translated title from '🚨 Ubos na ang Stock!'
    try {
      await _plugin.show(
          2, '🚨 Out of Stock!', productNames.take(3).join(', '), details);
    } catch (_) {}
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
    
    // Pluralization check for English 'transaction/transactions' labels
    final txLabel = transactions == 1 ? 'transaction' : 'transactions';
    
    // Translated title and metrics string content payload
    try {
      await _plugin.show(
        3,
        '📊 Today\'s Sales Summary',
        'Sales: ₱${revenue.toStringAsFixed(2)} | Profit: ₱${profit.toStringAsFixed(2)} | $transactions $txLabel',
        details,
      );
    } catch (_) {}
  }

  Future<void> scheduleStockCheck(
      List<String> lowStock, List<String> outOfStock) async {
    if (outOfStock.isNotEmpty) {
      await showOutOfStockAlert(outOfStock);
    } else if (lowStock.isNotEmpty) {
      await showLowStockAlert(lowStock);
    }
  }

  // ── Balance Reminder — 12 hours before deadline ──────────────
  Future<void> scheduleDebtReminder({
    required String customerName,
    required DateTime dueDate,
    required double amount,
  }) async {
    if (!await isEnabled) return;

    final notifTime = dueDate.subtract(const Duration(hours: 12));
    if (notifTime.isBefore(DateTime.now())) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'debt_reminder', 'Payment Reminders',
        channelDescription: 'Reminders for outstanding balances close to their deadline',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    // Unique ID based on customer + due date
    final id = (customerName + dueDate.toString()).hashCode.abs() % 100000;

    // Translated titles, labels, and contexts from Tagalog structures
    //
    // Best-effort: some platforms (e.g. Windows desktop) don't implement
    // scheduled notifications and throw UnimplementedError here. A failure
    // to schedule a reminder must never abort the sale/debt transaction
    // that already committed to the database before this call.
    try {
      await _plugin.zonedSchedule(
        id,
        '⏰ Payment Reminder',
        '$customerName has an outstanding balance of ₱${amount.toStringAsFixed(2)} — due tomorrow!',
        tz.TZDateTime.from(notifTime, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}