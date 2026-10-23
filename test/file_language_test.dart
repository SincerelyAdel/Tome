import 'package:highlight/languages/all.dart' show allLanguages;
import 'package:flutter_test/flutter_test.dart';
import 'package:repoviewer/widgets/file_icon.dart';

void main() {
  test('files map to the expected languages', () {
    const cases = {
      'top.sv': 'verilog',
      'pkg.svh': 'verilog',
      'alu.v': 'verilog',
      'constraints.sdc': 'tcl',
      'pins.xdc': 'tcl',
      'Makefile': 'makefile',
      'rules.mk': 'makefile',
      'CMakeLists.txt': 'cmake',
      'Dockerfile': 'dockerfile',
      'main.rs': 'rust',
      'MainActivity.kt': 'kotlin',
      'build.gradle.kts': 'kotlin',
      'AppDelegate.swift': 'swift',
      'GeneratedPluginRegistrant.m': 'objectivec',
      'driver.c': 'cpp',
      'model.cpp': 'cpp',
      'index.html': 'xml',
      'page.astro': 'xml',
      'app.tsx': 'typescript',
      'boot.S': 'mipsasm',
      'link.ld': 'cpp',
      'brix_tags.yaml': 'yaml',
      'README.md': 'markdown',
      'notes.txt': 'plaintext',
    };
    cases.forEach((file, lang) {
      expect(languageForFile(file), lang, reason: file);
    });
  });

  test('every mapped language is known to the highlighter', () {
    // The highlighter silently falls back to plain text for unknown names,
    // so check each name against its language table.
    const files = [
      'a.sv', 'a.vhd', 'a.tcl', 'Makefile', 'CMakeLists.txt', 'Dockerfile',
      'a.rs', 'a.go', 'a.kt', 'a.swift', 'a.m', 'a.java', 'a.dart', 'a.c',
      'a.js', 'a.ts', 'a.html', 'a.css', 'a.scss', 'a.less', 'a.py',
      'a.sh', 'a.ps1', 'a.bat', 'a.lua', 'a.sql', 'a.gradle', 'Jenkinsfile',
      'a.json', 'a.yaml', 'a.toml', 'a.properties', 'a.md', 'a.diff',
      'a.s', 'a.asm',
    ];
    for (final f in files) {
      final lang = languageForFile(f);
      expect(allLanguages.containsKey(lang), isTrue,
          reason: '$f -> $lang');
    }
  });
}
