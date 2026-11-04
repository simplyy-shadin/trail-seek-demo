import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/app/providers.dart';
import 'package:trailseek/data/models/group_session.dart';

Member _m(String id, String name, int idx) => Member(id: id, displayName: name, role: MemberRole.member, memberIndex: idx);

void main() {
  test('duplicate display names get an index-ordered suffix', () {
    final out = disambiguateNames([_m('b', 'Trail Seeker', 3), _m('a', 'Trail Seeker', 0), _m('c', 'Ashna', 1)]);
    final byId = {for (final m in out) m.id: m.displayName};
    expect(byId['a'], 'Trail Seeker');
    expect(byId['b'], 'Trail Seeker 2');
    expect(byId['c'], 'Ashna');
  });

  test('unique names are returned untouched', () {
    final input = [_m('a', 'Shad', 0), _m('b', 'Amalu', 1)];
    expect(identical(disambiguateNames(input), input), isTrue);
  });
}
