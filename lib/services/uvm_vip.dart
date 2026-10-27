import 'dart:async';
import 'dart:convert';

import '../models/actions.dart';
import '../models/repo_item.dart';
import 'github_org.dart';
import 'github_service.dart';

/// A VIP in a uvm-vip-eqsemi style repo: a folder `vip/<name>/` holding a
/// `vip.json` that lists its tests. Tome starts runs of it with the repo's
/// `uvmdbg.yml` workflow, and the results come back as runs for the viewer.
class UvmVip {
  final String name;
  final List<String> tests;
  final String defaultTest;

  const UvmVip(
      {required this.name, this.tests = const [], this.defaultTest = ''});

  /// The workflow that runs a VIP. It takes inputs vip, test and seed.
  static const workflowFile = 'uvmdbg.yml';
  static const workflowPath = '.github/workflows/$workflowFile';

  /// True when a repo folder listing is a VIP: it holds a vip.json.
  static bool isVipFolder(List<RepoItem> items) =>
      items.any((i) => i.isFile && i.name == 'vip.json');

  /// Reads vip.json. [folder] is the name used when the file has none.
  /// Returns null when the text isn't a JSON object.
  static UvmVip? parse(String text, {String folder = ''}) {
    final Object? j;
    try {
      j = jsonDecode(text);
    } catch (_) {
      return null;
    }
    if (j is! Map) return null;
    final tests = j['tests'] is List
        ? [for (final t in j['tests'] as List) '$t']
        : <String>[];
    final name = j['name'] is String && (j['name'] as String).isNotEmpty
        ? j['name'] as String
        : folder;
    final def = j['default_test'] is String ? j['default_test'] as String : '';
    return UvmVip(name: name, tests: tests, defaultTest: def);
  }

  /// The tests in picker order: the default first, then the rest.
  List<String> get testChoices => [
        if (defaultTest.isNotEmpty) defaultTest,
        for (final t in tests)
          if (t != defaultTest) t,
      ];

  /// The workflow inputs for one run. The default test (or none) is sent
  /// as an empty test, which the workflow reads as "use default_test".
  Map<String, String> inputs({String? test, required String seed}) => {
        'vip': name,
        'test': test == null || test.isEmpty || test == defaultTest ? '' : test,
        'seed': seed.trim().isEmpty ? '1' : seed.trim(),
      };

  /// Whether [ref] has the workflow, so a run can start from it.
  static Future<bool> hasWorkflow(
      GitHubService github, String owner, String repo, String? ref) async {
    try {
      await github.getRawFile(owner, repo, workflowPath, ref: ref);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Starts a run of this VIP on [ref] and returns it once GitHub lists
  /// it, or null if it hasn't shown up after [wait].
  Future<WorkflowRun?> start(
    GitHubService github,
    String owner,
    String repo,
    String ref, {
    String? test,
    required String seed,
    Duration wait = const Duration(seconds: 30),
  }) async {
    // Runs listed before the start, so the new one can be told apart.
    final before = <int>{};
    try {
      before.addAll((await github.getWorkflowRuns(owner, repo,
              workflowId: workflowFile, perPage: 10))
          .map((r) => r.id));
    } catch (_) {}
    await github.dispatchWorkflow(owner, repo, workflowFile, ref,
        inputs: inputs(test: test, seed: seed));
    final end = DateTime.now().add(wait);
    while (DateTime.now().isBefore(end)) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final runs = await github.getWorkflowRuns(owner, repo,
            workflowId: workflowFile, perPage: 10);
        for (final r in runs) {
          if (!before.contains(r.id) &&
              r.event == 'workflow_dispatch' &&
              r.branch == ref) {
            return r;
          }
        }
      } catch (_) {}
    }
    return null;
  }
}
