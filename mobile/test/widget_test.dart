import 'package:flutter_test/flutter_test.dart';
import 'package:orbix/theme.dart';

void main() {
  test('colour tokens match the spec', () {
    expect(Tokens.background.toARGB32(), 0xFF0A0A14);
    expect(Tokens.primary.toARGB32(), 0xFF7C5CFF);
    expect(Tokens.gold.toARGB32(), 0xFFFFC94D);
  });
}
