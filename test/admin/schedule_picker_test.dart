import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/admin/util/format.dart';

void main() {
  test('combineDateTime merges a date and a time', () {
    final r = combineDateTime(DateTime(2026, 5, 1), const TimeOfDay(hour: 9, minute: 30));
    expect(r, DateTime(2026, 5, 1, 9, 30));
  });
}
