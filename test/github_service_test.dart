import 'package:flutter_test/flutter_test.dart';
import 'package:repoviewer/services/github_service.dart';

void main() {
  test('repo inputs parse as repos', () {
    expect(GitHubService.parseRepoUrl('https://github.com/SincerelyAdel/RTL'),
        {'owner': 'SincerelyAdel', 'repo': 'RTL'});
    expect(GitHubService.parseRepoUrl('SincerelyAdel/RTL'),
        {'owner': 'SincerelyAdel', 'repo': 'RTL'});
  });

  test('usernames are not repos but parse as usernames', () {
    for (final input in [
      'SincerelyAdel',
      '@SincerelyAdel',
      'https://github.com/SincerelyAdel',
      'github.com/SincerelyAdel/',
    ]) {
      expect(GitHubService.parseRepoUrl(input), isNull, reason: input);
      expect(GitHubService.parseUsername(input), 'SincerelyAdel',
          reason: input);
    }
  });

  test('junk is neither', () {
    expect(GitHubService.parseUsername('not a user'), isNull);
  });
}
