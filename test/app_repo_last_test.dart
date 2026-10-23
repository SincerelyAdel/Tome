import 'package:flutter_test/flutter_test.dart';
import 'package:repoviewer/models/repo_item.dart';

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
    final sorted = [repo('repo-viewer'), repo('b'), repo('a'), repo('c')]
        .withAppRepoLast()
        .map((r) => r.name)
        .toList();
    expect(sorted, ['b', 'a', 'c', 'repo-viewer']);
  });

  test('matches any capitalisation, leaves lists without it alone', () {
    expect([repo('Repo-Viewer'), repo('x')].withAppRepoLast().last.name,
        'Repo-Viewer');
    expect([repo('x'), repo('y')].withAppRepoLast().map((r) => r.name),
        ['x', 'y']);
  });
}
