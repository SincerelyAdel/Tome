import 'package:flutter_test/flutter_test.dart';
import 'package:tome/models/repo_item.dart';

RepoInfo repo(String name) => RepoInfo(
      owner: 'me',
      name: name,
      fullName: 'me/$name',
      description: '',
      defaultBranch: 'main',
      stars: 0,
      language: '',
    );

void main() {
  test('the APK builder repo goes last, others keep their order', () {
    final sorted = [repo('apk-builder'), repo('b'), repo('a'), repo('c')]
        .withAppRepoLast()
        .map((r) => r.name)
        .toList();
    expect(sorted, ['b', 'a', 'c', 'apk-builder']);
  });

  test('Tome itself is not pinned', () {
    expect([repo('Tome'), repo('x')].withAppRepoLast().first.name,
        'Tome');
  });

  test('matches any capitalisation, leaves lists without it alone', () {
    expect([repo('APK-Builder'), repo('x')].withAppRepoLast().last.name,
        'APK-Builder');
    expect([repo('x'), repo('y')].withAppRepoLast().map((r) => r.name),
        ['x', 'y']);
  });
}
