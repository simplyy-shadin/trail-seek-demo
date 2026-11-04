import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/app/links.dart';
import 'package:trailseek/features/group/join_group_screen.dart';

void main() {
  test('reads the code from the lobby QR link, not the letters of trailseek', () {
    expect(extractJoinCode(AppLinks.joinDeepLink('FFXZYD')), 'FFXZYD');
  });

  test('reads the code from a shared invite and from a bare code', () {
    final invite = AppLinks.groupInvite(groupName: 'Peechi crew', adventureName: 'Peechi trek', date: '1 Nov', code: '8UH2E4');
    expect(extractJoinCode(invite), '8UH2E4');
    expect(extractJoinCode(' ffxzyd '), 'FFXZYD');
    expect(extractJoinCode('no code here'), isNull);
  });
}
