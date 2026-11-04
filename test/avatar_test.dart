import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/core/widgets/widgets.dart';
import 'package:trailseek/data/models/avatar.dart';

void main() {
  test('avatar encodes and decodes, clamping bad values', () {
    const a = Avatar(base: 3, outfit: 1, accessory: 2, hairStyle: 4, hairColor: 5);
    expect(a.encode(), 'v1:3.1.2.4.5');
    expect(Avatar.decode(a.encode()), a);
    expect(Avatar.decode(null), const Avatar());
    expect(Avatar.decode('garbage'), const Avatar());
    expect(Avatar.decode('v1:99.99.99.99.99').base, Avatar.bases - 1);
  });

  testWidgets('AvatarView paints every style combination at marker and profile sizes', (tester) async {
    final combos = <Avatar>[
      for (var h = 0; h < Avatar.hairStyles; h++)
        for (var acc = 0; acc < Avatar.accessories; acc++) Avatar(base: (h + acc) % Avatar.bases, outfit: acc % Avatar.outfits, accessory: acc, hairStyle: h, hairColor: h % Avatar.hairColors),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Wrap(children: [
            for (final c in combos) AvatarView(avatar: c, size: 24),
            for (final c in combos.take(4)) AvatarView(avatar: c, size: 160),
            AvatarRing(initials: 'FF', avatar: combos.first, size: 120, onEdit: () {}),
            MemberAvatar(initials: 'AN', avatar: combos.last, ring: Colors.white),
          ]),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(AvatarView), findsNWidgets(combos.length + 4 + 2));
  });
}
