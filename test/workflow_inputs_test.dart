import 'package:flutter_test/flutter_test.dart';
import 'package:tome/services/workflow_inputs.dart';

void main() {
  test('reads workflow_dispatch inputs in file order', () {
    const yaml = '''
name: uvmdbg
on:
  push:
  workflow_dispatch:
    inputs:
      vip:
        description: Folder under vip/
        required: true
      seed:
        default: "1"
      test:
        description: Empty means the default test
      waves:
        type: boolean
      mode:
        type: choice
        options: [fast, full]
        default: full
jobs: {}
''';
    final inputs = WorkflowInputs.parse(yaml);
    expect(inputs.map((i) => i.name), ['vip', 'seed', 'test', 'waves', 'mode']);
    expect(inputs[0].required, isTrue);
    expect(inputs[0].description, 'Folder under vip/');
    expect(inputs[1].defaultValue, '1');
    expect(inputs[2].required, isFalse);
    expect(inputs[3].type, 'boolean');
    expect(inputs[4].options, ['fast', 'full']);
    expect(inputs[4].defaultValue, 'full');
  });

  test('no inputs when there is no dispatch trigger or bad yaml', () {
    expect(WorkflowInputs.parse('on: push\njobs: {}'), isEmpty);
    expect(WorkflowInputs.parse('on:\n  workflow_dispatch:\n'), isEmpty);
    expect(WorkflowInputs.parse(': : :\n  - ['), isEmpty);
  });

  test('reads the real uvmdbg.yml trigger (uvm-vip-eqsemi 335be60)', () {
    const yaml = '''
name: uvmdbg

on:
  workflow_dispatch:
    inputs:
      vip:
        description: VIP folder under vip/
        required: true
        type: string
      test:
        description: UVM test, empty for the VIP's default_test
        required: false
        default: ""
        type: string
      seed:
        description: Simulation seed
        required: false
        default: "1"
        type: string

permissions:
  contents: write
''';
    final inputs = WorkflowInputs.parse(yaml);
    expect(inputs.map((i) => i.name), ['vip', 'test', 'seed']);
    expect(inputs.map((i) => i.required), [true, false, false]);
    expect(inputs.map((i) => i.defaultValue), ['', '', '1']);
    expect(inputs[1].description, "UVM test, empty for the VIP's default_test");
    expect(inputs.every((i) => i.type == 'string'), isTrue);
  });
}
