import 'package:flutter_test/flutter_test.dart';
import 'package:orbix/theme.dart';

void main() {
  test('theme builds with dark background token', () {
    final t = buildTheme();
    expect(t.scaffoldBackgroundColor, Tokens.background);
  });
}
