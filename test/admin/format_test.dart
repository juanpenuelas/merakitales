import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/admin/util/format.dart';

void main() {
  test('slugify lowercases, strips accents, hyphenates', () {
    expect(slugify('Aventuras Épicas!'), 'aventuras-epicas');
    expect(slugify('  Niños y Niñas  '), 'ninos-y-ninas');
    expect(slugify(''), '');
  });

  test('formatScheduled renders DD/MM HH:mm', () {
    expect(formatScheduled(DateTime(2026, 3, 9, 7, 5)), '09/03 07:05');
  });
}
