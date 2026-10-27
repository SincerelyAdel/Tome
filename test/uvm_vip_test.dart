import 'package:flutter_test/flutter_test.dart';
import 'package:tome/models/repo_item.dart';
import 'package:tome/services/uvm_vip.dart';

void main() {
  // vip/rr_arb/vip.json in uvm-vip-eqsemi at 335be60.
  const rrArb = '''
{
  "name": "rr_arb",
  "top": "tb_rr_arb",
  "tests": ["arb_test"],
  "default_test": "arb_test",
  "plusargs": [],
  "xrun_args": [],
  "env": []
}''';

  test('reads vip.json', () {
    final vip = UvmVip.parse(rrArb)!;
    expect(vip.name, 'rr_arb');
    expect(vip.tests, ['arb_test']);
    expect(vip.defaultTest, 'arb_test');
    expect(vip.testChoices, ['arb_test']);
  });

  test('default test comes first in the picker', () {
    final vip = UvmVip.parse(
        '{"name":"f","tests":["a_test","b_test","c_test"],"default_test":"b_test"}')!;
    expect(vip.testChoices, ['b_test', 'a_test', 'c_test']);
  });

  test('default or missing test is sent empty, others by name', () {
    final vip = UvmVip.parse(
        '{"name":"f","tests":["a_test","b_test"],"default_test":"b_test"}')!;
    expect(vip.inputs(test: 'b_test', seed: '7'),
        {'vip': 'f', 'test': '', 'seed': '7'});
    expect(vip.inputs(test: 'a_test', seed: ''),
        {'vip': 'f', 'test': 'a_test', 'seed': '1'});
    expect(vip.inputs(seed: ' 42 '), {'vip': 'f', 'test': '', 'seed': '42'});
  });

  test('no tests listed: name from the folder, default test', () {
    final vip = UvmVip.parse('{}', folder: 'fifo_v1')!;
    expect(vip.name, 'fifo_v1');
    expect(vip.testChoices, isEmpty);
    expect(vip.inputs(test: '', seed: '3')['test'], '');
  });

  test('bad vip.json is null; vip.json marks the folder', () {
    expect(UvmVip.parse('not json'), isNull);
    expect(UvmVip.parse('[1,2]'), isNull);
    RepoItem item(String name) => RepoItem.fromJson(
        {'name': name, 'path': 'vip/x/$name', 'type': 'file', 'size': 1});
    expect(UvmVip.isVipFolder([item('files.f'), item('vip.json')]), isTrue);
    expect(UvmVip.isVipFolder([item('README.md')]), isFalse);
  });
}
