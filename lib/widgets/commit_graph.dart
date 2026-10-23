import 'package:flutter/material.dart';
import '../models/github_models.dart';
import '../theme.dart';

/// A lane carries the line towards one expected commit.
class _Lane {
  _Lane(this.sha, this.color);
  final String sha;
  final int color;
}

/// What to draw in one commit's row of the graph.
class GraphRow {
  GraphRow({
    required this.before,
    required this.after,
    required this.column,
    required this.color,
    required this.sha,
    required this.parents,
  });

  /// Lanes entering the row from above and leaving it below.
  final List<_Lane?> before;
  final List<_Lane?> after;

  /// The lane the commit's dot sits on, and its color index.
  final int column;
  final int color;
  final String sha;
  final List<String> parents;

  int get width => [before.length, after.length, column + 1]
      .reduce((a, b) => a > b ? a : b);
}

/// Lays out commits (newest first, as GitHub returns them) into lanes,
/// like `git log --graph`.
List<GraphRow> layoutGraph(List<GhCommit> commits) {
  var lanes = <_Lane?>[];
  var nextColor = 0;
  final rows = <GraphRow>[];

  int freeSlot(List<_Lane?> l) {
    final i = l.indexOf(null);
    if (i >= 0) return i;
    l.add(null);
    return l.length - 1;
  }

  for (final c in commits) {
    final before = List<_Lane?>.of(lanes);
    var column = lanes.indexWhere((l) => l?.sha == c.sha);
    late int color;
    if (column == -1) {
      // A branch tip nothing below has pointed at yet: start a new lane.
      column = freeSlot(lanes);
      color = nextColor++;
    } else {
      color = lanes[column]!.color;
    }

    final after = List<_Lane?>.of(lanes);
    while (after.length < lanes.length) {
      after.add(null);
    }
    // Every lane that was heading for this commit ends here.
    for (var i = 0; i < after.length; i++) {
      if (after[i]?.sha == c.sha) after[i] = null;
    }
    if (column >= after.length) after.add(null);

    for (var p = 0; p < c.parents.length; p++) {
      final sha = c.parents[p];
      if (after.any((l) => l?.sha == sha)) continue; // joins an existing lane
      if (p == 0 && after[column] == null) {
        after[column] = _Lane(sha, color); // first parent continues straight
      } else {
        after[freeSlot(after)] = _Lane(sha, nextColor++);
      }
    }
    while (after.isNotEmpty && after.last == null) {
      after.removeLast();
    }

    rows.add(GraphRow(
      before: before,
      after: after,
      column: column,
      color: color,
      sha: c.sha,
      parents: c.parents,
    ));
    lanes = after;
  }
  return rows;
}

const laneWidth = 16.0;

/// Line colors, cycled per lane.
List<Color> get _laneColors => [
      AppColors.accent,
      AppColors.isDark ? const Color(0xFF58A6FF) : const Color(0xFF0969DA),
      AppColors.isDark ? const Color(0xFF3FB950) : const Color(0xFF1A7F37),
      AppColors.isDark ? const Color(0xFFA371F7) : const Color(0xFF8250DF),
      AppColors.isDark ? const Color(0xFFF778BA) : const Color(0xFFBF3989),
      AppColors.isDark ? const Color(0xFF39C5CF) : const Color(0xFF1B7C83),
      AppColors.isDark ? const Color(0xFFF0883E) : const Color(0xFFBC4C00),
    ];

/// Paints one row of the graph: passing lanes, merges into the dot, and
/// lines from the dot down to each parent.
class GraphRowPainter extends CustomPainter {
  GraphRowPainter(this.row, {required this.isMerge, required this.dark});

  final GraphRow row;
  final bool isMerge;
  final bool dark; // repaint when the theme changes

  double _x(int lane) => laneWidth / 2 + lane * laneWidth + 6;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = _laneColors;
    Color colorOf(int i) => colors[i % colors.length];
    final h = size.height;
    final mid = h / 2;
    final dot = Offset(_x(row.column), mid);

    Paint stroke(int color) => Paint()
      ..color = colorOf(color)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    void curve(Offset a, Offset b, int color) {
      if ((a.dx - b.dx).abs() < 0.5) {
        canvas.drawLine(a, b, stroke(color));
        return;
      }
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, (a.dy + b.dy) / 2, b.dx, (a.dy + b.dy) / 2, b.dx, b.dy);
      canvas.drawPath(path, stroke(color));
    }

    // Lanes coming in from above.
    for (var i = 0; i < row.before.length; i++) {
      final lane = row.before[i];
      if (lane == null) continue;
      if (lane.sha == row.sha) {
        curve(Offset(_x(i), 0), dot, lane.color); // ends at this commit
      } else {
        final j = row.after.indexWhere((l) => l?.sha == lane.sha);
        if (j >= 0) curve(Offset(_x(i), 0), Offset(_x(j), h), lane.color);
      }
    }
    // Lines from this commit to its parents.
    for (final p in row.parents) {
      final j = row.after.indexWhere((l) => l?.sha == p);
      if (j >= 0) curve(dot, Offset(_x(j), h), row.after[j]!.color);
    }

    // The dot: a ring for merge commits, filled otherwise.
    final c = colorOf(row.color);
    canvas.drawCircle(dot, 6, Paint()..color = AppColors.bg);
    if (isMerge) {
      canvas.drawCircle(
          dot,
          4.5,
          Paint()
            ..color = c
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    } else {
      canvas.drawCircle(dot, 5, Paint()..color = c);
    }
  }

  @override
  bool shouldRepaint(covariant GraphRowPainter old) =>
      old.row != row || old.dark != dark;
}
