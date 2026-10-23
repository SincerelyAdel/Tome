import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:repoviewer/models/actions.dart';
import 'package:repoviewer/widgets/gh_markdown.dart';
import 'package:repoviewer/widgets/job_log.dart';

JobStep step(int n, String name, String start, {String? conclusion}) =>
    JobStep(
      number: n,
      name: name,
      status: 'completed',
      conclusion: conclusion ?? 'success',
      startedAt: DateTime.parse(start),
      completedAt: DateTime.parse(start),
    );

void main() {
  test('log lines go to the step that was running', () {
    final steps = [
      step(1, 'Set up job', '2024-05-01T10:00:00Z'),
      step(2, 'Checkout', '2024-05-01T10:00:02Z'),
      step(3, 'Lint', '2024-05-01T10:00:05Z', conclusion: 'skipped'),
      step(4, 'Build', '2024-05-01T10:00:05Z'),
    ];
    const log = '﻿2024-05-01T10:00:00.1234567Z Current runner version\n'
        '2024-05-01T10:00:01.0000000Z Prepare workflow directory\n'
        '2024-05-01T10:00:02.0000000Z ##[group]Run actions/checkout@v4\n'
        '2024-05-01T10:00:02.1000000Z with: repo\n'
        '2024-05-01T10:00:02.2000000Z ##[endgroup]\n'
        '2024-05-01T10:00:03.0000000Z Fetching\n'
        '2024-05-01T10:00:05.0000000Z last checkout line\n'
        '2024-05-01T10:00:05.5000000Z ##[group]Run flutter build\n'
        '2024-05-01T10:00:09.0000000Z \x1B[31mboom\x1B[0m\n'
        '2024-05-01T10:00:09.1000000Z ##[error]Process completed with exit code 1.\n';
    final out = splitLogBySteps(log, steps);
    expect(out[0].map((l) => l.text),
        ['Current runner version', 'Prepare workflow directory']);
    expect(out[1].first.kind, LogKind.group);
    expect(out[1].first.text, 'Run actions/checkout@v4');
    expect(out[1][1].group, 1); // folded under the group line
    expect(out[1].map((l) => l.text).last, 'last checkout line');
    expect(out[2], isEmpty); // skipped
    expect(out[3].first.text, 'Run flutter build');
    expect(out[3].last.kind, LogKind.error);
    expect(out[3].last.text, 'Error: Process completed with exit code 1.');
    expect(out[3].map((l) => l.number), [1, 2, 3]);
  });

  test('ANSI colors become spans without escape codes', () {
    final spans = ansiSpans('\x1B[1;32mok\x1B[0m done\x1B[K', dark: true);
    expect(spans.map((s) => s.text).join(), 'ok done');
    expect(spans.first.style?.color, isNotNull);
  });

  test('mentions become profile links; emails and code do not', () {
    String html(String s) => md.markdownToHtml(s,
        extensionSet: md.ExtensionSet.gitHubWeb,
        inlineSyntaxes: [MentionSyntax()]);
    expect(html('thanks @octo-cat!'),
        contains('<strong><a href="mention:octo-cat">@octo-cat</a></strong>'));
    expect(html('cc @org/team'), contains('href="mention:org"'));
    expect(html('mail me@example.com'), isNot(contains('mention:')));
    expect(html('`@notamention`'), isNot(contains('mention:')));
  });
}
