import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/app/links.dart';

void main() {
  test('group invite contains the code, the trek, and the app download link', () {
    final m = AppLinks.groupInvite(groupName: 'Test', adventureName: 'Meesapulimala', date: '30 Oct', code: '8UH2E4');
    expect(m, startsWith('Join my Trail Seek group "Test" for Meesapulimala on 30 Oct.'));
    expect(m, contains('Code: 8UH2E4'));
    expect(m, contains('trailseek://join/8UH2E4'));
    expect(m, contains(AppLinks.androidApk));
    expect(m, contains('Android'));
    expect(AppLinks.androidApk, 'https://trailseek.vercel.app/trailseek.apk');
    expect(AppLinks.joinDeepLink('8UH2E4'), 'trailseek://join/8UH2E4');
  });
}
