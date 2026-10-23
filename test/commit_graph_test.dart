import 'package:flutter_test/flutter_test.dart';
import 'package:repoviewer/models/github_models.dart';
import 'package:repoviewer/widgets/commit_graph.dart';

GhCommit c(String sha, List<String> parents) =>
    GhCommit(sha: sha, message: sha, authorName: '', parents: parents);

void main() {
  test('a straight history stays in one lane', () {
    final rows = layoutGraph([c('c', ['b']), c('b', ['a']), c('a', [])]);
    expect(rows.map((r) => r.column), [0, 0, 0]);
    expect(rows.map((r) => r.width), [1, 1, 1]);
  });

  test('a merged branch opens a second lane and joins back', () {
    // m merges feature tip f into main; both come from a.
    final rows = layoutGraph([
      c('m', ['a', 'f']),
      c('f', ['a']),
      c('a', []),
    ]);
    expect(rows[0].column, 0); // merge commit on main
    expect(rows[0].after.map((l) => l == null), [false, false]); // 2 lanes out
    expect(rows[1].column, 1); // branch commit in the second lane
    expect(rows[1].after.length, 1); // its parent is already on lane 0
    expect(rows[2].column, 0);
  });

  test('two branch tips get separate lanes', () {
    final rows = layoutGraph([
      c('x', ['a']),
      c('y', ['a']),
      c('a', []),
    ]);
    expect(rows[0].column, 0);
    expect(rows[1].column, 1);
    // y's line curves into the lane already heading for a.
    expect(rows[1].after.length, 1);
    expect(rows[2].column, 0);
  });
}
