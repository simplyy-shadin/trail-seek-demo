import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/features/avatar/avatar_creator.dart';

void main() {
  test('every character has a full body and a portrait', () {
    for (final c in CharacterCatalog.characters) {
      expect(File(CharacterCatalog.full(c.key)).existsSync(), isTrue, reason: c.key);
      expect(File(CharacterCatalog.face(c.key)).existsSync(), isTrue, reason: '${c.key} face');
      expect(CharacterCatalog.parse(CharacterCatalog.id(c.key)), c.key);
    }
  });

  test('older tiered ids still resolve to the character', () {
    expect(CharacterCatalog.parse('char:meera:summit'), 'meera');
    expect(CharacterCatalog.parse('char:nobody'), isNull);
    expect(CharacterCatalog.parse('v1:abc'), isNull);
  });
}
