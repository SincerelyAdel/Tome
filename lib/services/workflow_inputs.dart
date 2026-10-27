import 'dart:convert';

import 'package:yaml/yaml.dart';

import 'github_service.dart';

/// One input of a workflow's `workflow_dispatch` trigger.
class WorkflowInput {
  final String name;
  final String description;
  final bool required;
  final String defaultValue;

  /// `string`, `boolean`, `choice`, `number` or `environment`.
  final String type;

  /// The allowed values of a `choice` input.
  final List<String> options;

  const WorkflowInput({
    required this.name,
    this.description = '',
    this.required = false,
    this.defaultValue = '',
    this.type = 'string',
    this.options = const [],
  });
}

/// Reads the inputs a workflow asks for when it is started by hand.
class WorkflowInputs {
  WorkflowInputs._();

  /// The inputs declared in the workflow file at [path] on [ref]. Empty when
  /// the file can't be read or declares none, so the run can still start.
  static Future<List<WorkflowInput>> fetch(
      GitHubService github, String owner, String repo, String path,
      {String? ref}) async {
    try {
      final bytes = await github.getRawFile(owner, repo, path, ref: ref);
      return parse(utf8.decode(bytes, allowMalformed: true));
    } catch (_) {
      return const [];
    }
  }

  /// The `on.workflow_dispatch.inputs` of a workflow file, in file order.
  static List<WorkflowInput> parse(String yamlText) {
    final Object? doc;
    try {
      doc = loadYaml(yamlText);
    } catch (_) {
      return const [];
    }
    if (doc is! Map) return const [];
    // YAML 1.1 parsers read a bare `on` as true, so accept both keys.
    final on = doc['on'] ?? doc[true];
    if (on is! Map) return const [];
    final dispatch = on['workflow_dispatch'];
    if (dispatch is! Map) return const [];
    final inputs = dispatch['inputs'];
    if (inputs is! Map) return const [];
    return [
      for (final e in inputs.entries)
        _input('${e.key}', e.value is Map ? e.value as Map : const {}),
    ];
  }

  static WorkflowInput _input(String name, Map m) {
    final options = m['options'];
    return WorkflowInput(
      name: name,
      description: '${m['description'] ?? ''}'.trim(),
      required: m['required'] == true,
      defaultValue: m['default'] == null ? '' : '${m['default']}',
      type: '${m['type'] ?? 'string'}',
      options: options is List ? [for (final o in options) '$o'] : const [],
    );
  }
}
