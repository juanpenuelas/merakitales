import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/admin/theme/app_theme.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  test('headings use Fraunces, body uses Inter', () {
    final t = AppTheme.light().textTheme;
    expect(t.headlineSmall!.fontFamily, contains('Fraunces'));
    expect(t.titleLarge!.fontFamily, contains('Fraunces'));
    expect(t.bodyMedium!.fontFamily, contains('Inter'));
  });
}
