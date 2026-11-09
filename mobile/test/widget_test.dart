import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbix/theme.dart';

void main() {
  test('colour tokens match the spec', () {
    expect(Tokens.background, const Color(0xFF0A0A14));
    expect(Tokens.primary, const Color(0xFF7C5CFF));
    expect(Tokens.gold, const Color(0xFFFFC94D));
  });
}
