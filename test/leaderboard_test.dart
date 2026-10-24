import 'package:flutter_test/flutter_test.dart';
import 'package:tome/models/leaderboard.dart';
import 'package:tome/screens/org/leaderboard_tab.dart';

final now = DateTime.utc(2026, 10, 23);

/// A week [weeksAgo] before [now] with [commits] commits.
Map<String, dynamic> week(int weeksAgo, int commits, {int a = 10, int d = 2}) =>
    {
      'w': now.subtract(Duration(days: 7 * weeksAgo)).millisecondsSinceEpoch ~/
          1000,
      'a': a,
      'd': d,
      'c': commits,
    };

RepoContributor who(String repo, String login, List<Map<String, dynamic>> weeks) =>
    RepoContributor.fromJson(repo, {
      'author': {'login': login, 'avatar_url': 'https://x/$login.png'},
      'weeks': weeks,
    })!;

void main() {
  final data = [
    who('api', 'ada', [week(0, 5), week(10, 20)]),
    who('web', 'ada', [week(2, 3)]),
    who('api', 'bob', [week(0, 9)]),
    who('web', 'Bob', [week(60, 40)]), // same person, different case
    who('api', 'dependabot[bot]', [week(0, 99)]),
    who('web', 'cy', [week(3, 0)]), // no commits at all
  ];

  test('all time adds up across repos and merges case', () {
    final r = rankContributors(data, LeaderPeriod.all, now: now);
    expect(r.map((e) => e.login), ['bob', 'ada']);
    expect(r[0].commits, 49);
    expect(r[0].repos, {'api', 'web'});
    expect(r[1].commits, 28);
    expect(r[1].additions, 30);
  });

  test('a window only counts weeks inside it', () {
    final week1 = rankContributors(data, LeaderPeriod.week, now: now);
    expect(week1.map((e) => (e.login, e.commits)), [('bob', 9), ('ada', 5)]);

    final month = rankContributors(data, LeaderPeriod.month, now: now);
    expect(month.map((e) => (e.login, e.commits)), [('bob', 9), ('ada', 8)]);
  });

  test('bots and people with no commits are left out', () {
    final r = rankContributors(data, LeaderPeriod.all, now: now);
    expect(r.any((e) => e.login.contains('[bot]')), isFalse);
    expect(r.any((e) => e.login == 'cy'), isFalse);
  });

  test('entries without an account are skipped', () {
    expect(RepoContributor.fromJson('x', {'author': null, 'weeks': []}), isNull);
  });

  test('ties go to more lines added, then name', () {
    final r = rankContributors([
      who('a', 'zed', [week(0, 2, a: 5)]),
      who('a', 'amy', [week(0, 2, a: 5)]),
      who('a', 'max', [week(0, 2, a: 50)]),
    ], LeaderPeriod.all, now: now);
    expect(r.map((e) => e.login), ['max', 'amy', 'zed']);
  });

  test('compact counts', () {
    expect(compactCount(950), '950');
    expect(compactCount(1000), '1k');
    expect(compactCount(12400), '12.4k');
    expect(compactCount(250000), '250k');
    expect(compactCount(3100000), '3.1M');
  });
}
