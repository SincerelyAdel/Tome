import 'package:flutter/material.dart';
import '../models/actions.dart';
import '../theme.dart';

/// How GitHub draws a log line.
enum LogKind { normal, group, error, warning, notice, debug, command }

class LogLine {
  /// 1-based, numbered per step like GitHub.
  final int number;
  final String text;
  final LogKind kind;

  /// Number of the `##[group]` line this line is folded under, if any.
  final int? group;

  const LogLine(this.number, this.text, this.kind, {this.group});
}

final _stamp = RegExp(
    r'^﻿?(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.\d+)?Z ?');
final _command = RegExp(r'^##\[(\w+)\]');

/// Splits a raw job log into the job's steps.
///
/// Each log line starts with a timestamp. A line belongs to the step that
/// had started by then; a step's first line is usually `##[group]Run ...`,
/// which settles ties when two steps start in the same second.
List<List<LogLine>> splitLogBySteps(String log, List<JobStep> steps) {
  final out = List.generate(steps.length, (_) => <LogLine>[]);
  if (steps.isEmpty) return out;

  // Steps that actually ran, in order.
  final ran = <int>[
    for (var i = 0; i < steps.length; i++)
      if (steps[i].startedAt != null && steps[i].conclusion != 'skipped') i
  ];
  if (ran.isEmpty) ran.add(0);
  DateTime? startOf(int r) => steps[ran[r]].startedAt?.toUtc();

  var cur = 0;
  final groupOf = <int, int?>{}; // step -> open group line number
  for (final raw in log.split('\n')) {
    var line = raw.endsWith('\r') ? raw.substring(0, raw.length - 1) : raw;
    DateTime? t;
    final m = _stamp.firstMatch(line);
    if (m != null) {
      t = DateTime.tryParse('${m[1]}Z');
      line = line.substring(m.end);
    }
    if (t != null) {
      while (cur + 1 < ran.length) {
        final next = startOf(cur + 1);
        if (next == null) break;
        if (t.isAfter(next) ||
            (t.isAtSameMomentAs(next) && line.startsWith('##[group]'))) {
          cur++;
        } else {
          break;
        }
      }
    }
    final step = ran[cur];
    final lines = out[step];

    var kind = LogKind.normal;
    final cmd = _command.firstMatch(line);
    if (cmd != null) {
      final name = cmd[1]!;
      final rest = line.substring(cmd.end);
      switch (name) {
        case 'group':
          lines.add(LogLine(lines.length + 1, rest, LogKind.group));
          groupOf[step] = lines.length;
          continue;
        case 'endgroup':
          groupOf[step] = null;
          continue;
        case 'error':
          kind = LogKind.error;
          line = 'Error: $rest';
        case 'warning':
          kind = LogKind.warning;
          line = 'Warning: $rest';
        case 'notice':
          kind = LogKind.notice;
          line = 'Notice: $rest';
        case 'debug':
          kind = LogKind.debug;
          line = rest;
        case 'command':
          kind = LogKind.command;
          line = rest;
        default:
          line = rest;
      }
    }
    if (line.isEmpty && raw.trim().isEmpty && lines.isEmpty) continue;
    lines.add(LogLine(lines.length + 1, line, kind, group: groupOf[step]));
  }
  // Trailing blank line from the final newline.
  for (final l in out) {
    if (l.isNotEmpty && l.last.text.isEmpty) l.removeLast();
  }
  return out;
}

final _sgr = RegExp(r'\x1B\[([0-9;]*)m');
final _otherEscapes = RegExp(r'\x1B\[[0-9;?]*[A-Za-z]');

/// Text with its ANSI color codes turned into styled spans.
List<TextSpan> ansiSpans(String text, {required bool dark}) {
  final spans = <TextSpan>[];
  Color? fg;
  var bold = false;
  var pos = 0;
  void emit(String s) {
    s = s.replaceAll(_otherEscapes, '');
    if (s.isEmpty) return;
    spans.add(TextSpan(
      text: s,
      style: TextStyle(
          color: fg, fontWeight: bold ? FontWeight.w700 : null),
    ));
  }

  for (final m in _sgr.allMatches(text)) {
    emit(text.substring(pos, m.start));
    pos = m.end;
    final codes = (m[1]!.isEmpty ? '0' : m[1]!)
        .split(';')
        .map((c) => int.tryParse(c) ?? 0)
        .toList();
    for (var i = 0; i < codes.length; i++) {
      final c = codes[i];
      if (c == 0) {
        fg = null;
        bold = false;
      } else if (c == 1) {
        bold = true;
      } else if (c == 22) {
        bold = false;
      } else if (c == 39) {
        fg = null;
      } else if (c >= 30 && c <= 37) {
        fg = _ansi(c - 30, dark);
      } else if (c >= 90 && c <= 97) {
        fg = _ansi(c - 90 + 8, dark);
      } else if (c == 38 && i + 2 < codes.length && codes[i + 1] == 5) {
        final n = codes[i + 2];
        fg = n < 16 ? _ansi(n, dark) : null;
        i += 2;
      } else if (c == 38 && i + 4 < codes.length && codes[i + 1] == 2) {
        fg = Color.fromARGB(255, codes[i + 2], codes[i + 3], codes[i + 4]);
        i += 4;
      }
    }
  }
  emit(text.substring(pos));
  return spans;
}

Color _ansi(int n, bool dark) {
  const darkColors = [
    0xFF8B949E, 0xFFFF7B72, 0xFF3FB950, 0xFFD29922, //
    0xFF58A6FF, 0xFFBC8CFF, 0xFF39C5CF, 0xFFB1BAC4,
    0xFF6E7681, 0xFFFFA198, 0xFF56D364, 0xFFE3B341,
    0xFF79C0FF, 0xFFD2A8FF, 0xFF56D4DD, 0xFFF0F6FC,
  ];
  const lightColors = [
    0xFF24292F, 0xFFCF222E, 0xFF116329, 0xFF4D2D00, //
    0xFF0969DA, 0xFF8250DF, 0xFF1B7C83, 0xFF6E7781,
    0xFF57606A, 0xFFA40E26, 0xFF1A7F37, 0xFF633C01,
    0xFF218BFF, 0xFFA475F9, 0xFF3192AA, 0xFF8C959F,
  ];
  return Color((dark ? darkColors : lightColors)[n.clamp(0, 15)]);
}

/// The color a line kind is drawn in, or null for normal text.
Color? logKindColor(LogKind k) => switch (k) {
      LogKind.error => AppColors.danger,
      LogKind.warning => AppColors.warning,
      LogKind.notice => AppColors.accent,
      LogKind.debug => AppColors.faint,
      LogKind.command => AppColors.accentLight,
      _ => null,
    };
