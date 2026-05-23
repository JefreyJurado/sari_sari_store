import 'package:intl/intl.dart';

class DateHelper {
  static final _date = DateFormat('MMM d, yyyy');
  static final _time = DateFormat('h:mm a');

  static String formatDate(DateTime d) => _date.format(d);
  static String formatTime(DateTime d) => _time.format(d);
  static String todayFormatted() => _date.format(DateTime.now());

  static String greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 18) return 'Afternoon';
    return 'Evening';
  }

  static String timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return _date.format(d);
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}