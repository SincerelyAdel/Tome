import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome/services/uvm_runs.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('uvm_runs_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  File put(String rel, String text) =>
      File('${tmp.path}/$rel')
        ..createSync(recursive: true)
        ..writeAsStringSync(text);

  test('run artifacts are recognised by name', () {
    expect(UvmRuns.isRunArtifact('uvmdbg-fifo_v3-seed42'), isTrue);
    expect(UvmRuns.isRunArtifact('UVMDBG_all'), isTrue);
    expect(UvmRuns.isRunArtifact('app-release.apk'), isFalse);
  });

  test('finds every folder holding a run.json', () {
    final files = [
      put('uvmdbg_out/b_run/run.json', '{}'),
      put('uvmdbg_out/b_run/timeline.jsonl', ''),
      put('uvmdbg_out/a_run/run.json', '{}'),
      put('uvmdbg_out/a_run/topology.json', '{}'),
      put('notes.txt', 'x'),
    ];
    final runs = UvmRuns.findRuns(files);
    expect(runs.map(UvmRuns.runId), ['a_run', 'b_run']);
  });

  test('finds a run whose files sit at the artifact root', () {
    final runs = UvmRuns.findRuns([put('files/run.json', '{}')]);
    expect(runs.map(UvmRuns.runId), ['files']);
  });

  test('names and sums up a run from run.json', () {
    put('files/run.json',
        '{"run_id":"20261024-153012-s42","test":"fifo_test","seed":42,"status":"passed"}');
    final dir = Directory('${tmp.path}/files');
    expect(UvmRuns.runId(dir), '20261024-153012-s42');
    expect(UvmRuns.summary(dir), 'fifo_test · seed 42 · passed');
  });

  test('packs a run with its files at the zip root', () async {
    put('r1/run.json', '{"run_id":"r1"}');
    put('r1/timeline.jsonl', '{}\n');
    final zip = await UvmRuns.pack(Directory('${tmp.path}/r1'));
    final names = ZipDecoder()
        .decodeBytes(zip.readAsBytesSync())
        .files
        .map((f) => f.name)
        .toList()
      ..sort();
    expect(names, ['run.json', 'timeline.jsonl']);
  });
}
