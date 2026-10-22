import 'package:flutter_test/flutter_test.dart';
import 'package:repoviewer/services/github_service.dart';

void main() {
  test('repo inputs parse as repos', () {
    expect(GitHubService.parseRepoUrl('https://github.com/octocat/RTL'),
        {'owner': 'octocat', 'repo': 'RTL'});
    expect(GitHubService.parseRepoUrl('octocat/RTL'),
        {'owner': 'octocat', 'repo': 'RTL'});
  });

  test('usernames are not repos but parse as usernames', () {
    for (final input in [
      'octocat',
      '@octocat',
      'https://github.com/octocat',
      'github.com/octocat/',
    ]) {
      expect(GitHubService.parseRepoUrl(input), isNull, reason: input);
      expect(GitHubService.parseUsername(input), 'octocat',
          reason: input);
    }
  });

  test('junk is neither', () {
    expect(GitHubService.parseUsername('not a user'), isNull);
  });
}
