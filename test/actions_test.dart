import 'package:flutter_test/flutter_test.dart';
import 'package:tome/models/actions.dart';
import 'package:tome/services/artifact_service.dart';

void main() {
  test('parses a workflow run', () {
    final run = WorkflowRun.fromJson({
      'id': 39565443104,
      'name': 'Build Flutter APK',
      'display_title': 'Fix Android build',
      'run_number': 9,
      'head_branch': 'main',
      'event': 'push',
      'status': 'completed',
      'conclusion': 'success',
      'head_sha': '4c23299ea21769d9e5c1fce66ce02ee20b8e92e3',
      'created_at': '2026-10-21T07:55:34Z',
      'html_url': 'https://github.com/o/r/actions/runs/39565443104',
    });
    expect(run.isRunning, isFalse);
    expect(run.shortSha, '4c23299');
    expect(run.conclusion, 'success');
  });

  test('in-progress run has no conclusion', () {
    final run = WorkflowRun.fromJson(
        {'id': 1, 'status': 'in_progress', 'conclusion': null});
    expect(run.isRunning, isTrue);
  });

  test('parses an artifact', () {
    final a = Artifact.fromJson({
      'id': 12329419632,
      'name': 'tome-apk',
      'size_in_bytes': 33277700,
      'expired': false,
      'expires_at': '2026-11-20T08:00:18Z',
    });
    expect(a.name, 'tome-apk');
    expect(a.expired, isFalse);
  });

  test('detects APKs and treats universal APKs as matching', () {
    expect(ArtifactService.isApk('app-arm64-v8a-release.APK'), isTrue);
    expect(ArtifactService.isApk('notes.txt'), isFalse);
    expect(ArtifactService.matchesDevice('Tome.apk'), isTrue);
  });
}
