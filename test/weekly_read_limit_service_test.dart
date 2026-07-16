import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:merakitales/services/weekly_read_limit_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('can read and record up to 7 unique tales in a week', () async {
    final service = WeeklyReadLimitService();
    
    // Read 7 unique tales
    for (int i = 1; i <= 7; i++) {
      expect(await service.canRead(i), isTrue);
      await service.recordRead(i);
    }

    // 8th unique tale should fail
    expect(await service.canRead(8), isFalse);
  });

  test('rereading the same tale does not count against the limit', () async {
    final service = WeeklyReadLimitService();
    
    // Read tale 1 multiple times
    for (int i = 0; i < 10; i++) {
      expect(await service.canRead(1), isTrue);
      await service.recordRead(1);
    }
    
    // Still can read 6 more unique tales
    for (int i = 2; i <= 7; i++) {
      expect(await service.canRead(i), isTrue);
      await service.recordRead(i);
    }

    // 8th unique tale should fail
    expect(await service.canRead(8), isFalse);
  });

  test('limit resets on Monday', () async {
    final service = WeeklyReadLimitService();
    
    // Read 7 unique tales
    for (int i = 1; i <= 7; i++) {
      await service.recordRead(i);
    }

    // Should fail
    expect(await service.canRead(8), isFalse);

    // Simulate time passing to next Monday
    final now = DateTime.now();
    final nextMonday = now.add(Duration(days: 8 - now.weekday));
    service.setMockTime(nextMonday);

    // Should be able to read again
    expect(await service.canRead(8), isTrue);
  });
}
