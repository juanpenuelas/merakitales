import 'package:shared_preferences/shared_preferences.dart';

class WeeklyReadLimitService {
  static const int _maxReadsPerWeek = 7;
  static const String _readTalesKey = 'weekly_read_tales';
  static const String _weekStartKey = 'weekly_read_start_date';

  DateTime? _mockTime;

  /// Used for testing to simulate time progression
  void setMockTime(DateTime time) {
    _mockTime = time;
  }

  DateTime _getNow() {
    return _mockTime ?? DateTime.now();
  }

  /// Returns the start of the week (Monday 00:00:00) for a given date
  DateTime _getStartOfWeek(DateTime date) {
    // weekday is 1 for Monday, 7 for Sunday
    final daysToSubtract = date.weekday - 1;
    final monday = date.subtract(Duration(days: daysToSubtract));
    return DateTime(monday.year, monday.month, monday.day);
  }

  /// Checks if the weekly limit should be reset based on the current date
  Future<void> _checkAndResetLimit(SharedPreferences prefs) async {
    final now = _getNow();
    final currentWeekStart = _getStartOfWeek(now);

    final storedWeekStartStr = prefs.getString(_weekStartKey);
    if (storedWeekStartStr != null) {
      final storedWeekStart = DateTime.parse(storedWeekStartStr);
      if (currentWeekStart.isAfter(storedWeekStart)) {
        // It's a new week, reset the read tales list
        await prefs.setStringList(_readTalesKey, []);
        await prefs.setString(_weekStartKey, currentWeekStart.toIso8601String());
      }
    } else {
      // First time using the service, initialize the week start
      await prefs.setString(_weekStartKey, currentWeekStart.toIso8601String());
    }
  }

  /// Determines if a user can read the given tale.
  Future<bool> canRead(int taleId) async {
    final prefs = await SharedPreferences.getInstance();
    await _checkAndResetLimit(prefs);

    final readTalesStr = prefs.getStringList(_readTalesKey) ?? [];
    final readTales = readTalesStr.map((e) => int.parse(e)).toList();

    // If already read this week, it doesn't count against limit
    if (readTales.contains(taleId)) {
      return true;
    }

    // Check if limit is reached
    if (readTales.length >= _maxReadsPerWeek) {
      return false;
    }

    return true;
  }

  /// Records a tale as read.
  Future<void> recordRead(int taleId) async {
    final prefs = await SharedPreferences.getInstance();
    await _checkAndResetLimit(prefs);

    final readTalesStr = prefs.getStringList(_readTalesKey) ?? [];
    final readTales = readTalesStr.map((e) => int.parse(e)).toSet();

    if (!readTales.contains(taleId)) {
      readTales.add(taleId);
      await prefs.setStringList(_readTalesKey, readTales.map((e) => e.toString()).toList());
    }
  }
}
