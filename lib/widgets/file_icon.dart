import 'package:flutter/material.dart';
import '../theme.dart';

class FileIcon extends StatelessWidget {
  final String name;
  final bool isDirectory;
  final bool isExpanded;
  final double size;

  const FileIcon({
    super.key,
    required this.name,
    required this.isDirectory,
    this.isExpanded = false,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (isDirectory) {
      return Icon(
        isExpanded ? Icons.folder_open : Icons.folder,
        color: AppColors.folder,
        size: size,
      );
    }
    final lang = languageForFile(name);
    final style = _iconFor[lang];
    final ext = _ext(name);
    if (style != null) {
      return Icon(style.$1, color: style.$2 ?? AppColors.accent, size: size);
    }
    if (ext == 'vcd') {
      return Icon(Icons.show_chart, color: AppColors.success, size: size);
    }
    if (ext == 'txt' || ext == 'log') {
      return Icon(Icons.article, color: AppColors.muted, size: size);
    }
    return Icon(Icons.insert_drive_file, color: AppColors.muted, size: size);
  }
}

/// Icon and color per highlight language (colors from GitHub's linguist).
/// A null color means the app's gold accent.
const Map<String, (IconData, Color?)> _iconFor = {
  'verilog': (Icons.memory, null),
  'vhdl': (Icons.memory, Color(0xFFADB2CB)),
  'tcl': (Icons.terminal, Color(0xFFE4CC98)),
  'python': (Icons.code, Color(0xFF3572A5)),
  'kotlin': (Icons.code, Color(0xFFA97BFF)),
  'cpp': (Icons.code, Color(0xFFF34B7D)),
  'dart': (Icons.code, Color(0xFF00B4AB)),
  'swift': (Icons.code, Color(0xFFF05138)),
  'objectivec': (Icons.code, Color(0xFF438EFF)),
  'java': (Icons.code, Color(0xFFB07219)),
  'rust': (Icons.code, Color(0xFFDEA584)),
  'go': (Icons.code, Color(0xFF00ADD8)),
  'javascript': (Icons.javascript, Color(0xFFF1E05A)),
  'typescript': (Icons.code, Color(0xFF3178C6)),
  'xml': (Icons.web, Color(0xFFE34C26)),
  'css': (Icons.palette_outlined, Color(0xFF663399)),
  'scss': (Icons.palette_outlined, Color(0xFFC6538C)),
  'less': (Icons.palette_outlined, Color(0xFF1D365D)),
  'cmake': (Icons.build_outlined, Color(0xFFDA3434)),
  'makefile': (Icons.build_outlined, Color(0xFF427819)),
  'dockerfile': (Icons.inventory_2_outlined, Color(0xFF384D54)),
  'gradle': (Icons.build_outlined, Color(0xFF02303A)),
  'x86asm': (Icons.developer_board, Color(0xFF6E4C13)),
  'mipsasm': (Icons.developer_board, Color(0xFF6E4C13)),
  'armasm': (Icons.developer_board, Color(0xFF6E4C13)),
  'json': (Icons.data_object, Color(0xFFB59A12)),
  'yaml': (Icons.data_object, Color(0xFFCB171E)),
  'ini': (Icons.tune, Color(0xFF9C4221)),
  'properties': (Icons.tune, Color(0xFF2A6277)),
  'markdown': (Icons.description, Color(0xFF6A9FB5)),
  'bash': (Icons.terminal, Color(0xFF89E051)),
  'powershell': (Icons.terminal, Color(0xFF012456)),
  'dos': (Icons.terminal, Color(0xFFC1F12E)),
  'sql': (Icons.storage, Color(0xFFE38C00)),
  'diff': (Icons.difference_outlined, Color(0xFF88DDDD)),
  'lua': (Icons.code, Color(0xFF000080)),
};

String _ext(String filename) {
  final dot = filename.lastIndexOf('.');
  return dot <= 0 ? '' : filename.substring(dot + 1).toLowerCase();
}

/// Files recognised by their whole name (no or misleading extension).
const Map<String, String> _byName = {
  'makefile': 'makefile',
  'gnumakefile': 'makefile',
  'cmakelists.txt': 'cmake',
  'dockerfile': 'dockerfile',
  'containerfile': 'dockerfile',
  'jenkinsfile': 'groovy',
  '.gitignore': 'bash',
  '.gitattributes': 'bash',
  '.dockerignore': 'bash',
  '.bashrc': 'bash',
  '.zshrc': 'bash',
  '.profile': 'bash',
  '.env': 'bash',
  '.editorconfig': 'ini',
  'gradle.properties': 'properties',
  'local.properties': 'properties',
};

/// Highlighting by extension. Covers every language used across the
/// SincerelyAdel and Empty-Quarter-Semiconductor-Company repos, plus the
/// config and script files that sit next to them.
const Map<String, String> _byExt = {
  // HDL / EDA
  'v': 'verilog', 'vh': 'verilog', 'sv': 'verilog', 'svh': 'verilog',
  'vhd': 'vhdl', 'vhdl': 'vhdl',
  'tcl': 'tcl', 'tk': 'tcl', 'sdc': 'tcl', 'xdc': 'tcl', 'upf': 'tcl',
  'do': 'tcl',
  // Systems
  'c': 'cpp', 'h': 'cpp', 'cpp': 'cpp', 'cc': 'cpp', 'cxx': 'cpp',
  'hpp': 'cpp', 'hh': 'cpp', 'hxx': 'cpp', 'ino': 'cpp',
  'ld': 'cpp', 'lds': 'cpp', // linker scripts: C-like comments and braces
  'rs': 'rust', 'go': 'go',
  's': 'mipsasm', 'asm': 'x86asm', // .s/.S: RISC-V style, closest is MIPS
  // Apps
  'dart': 'dart', 'kt': 'kotlin', 'kts': 'kotlin', 'java': 'java',
  'swift': 'swift', 'm': 'objectivec', 'mm': 'objectivec',
  'gradle': 'gradle', 'groovy': 'groovy',
  // Web
  'js': 'javascript', 'mjs': 'javascript', 'cjs': 'javascript',
  'jsx': 'javascript', 'ts': 'typescript', 'tsx': 'typescript',
  'mts': 'typescript', 'html': 'xml', 'htm': 'xml', 'xml': 'xml',
  'svg': 'xml', 'plist': 'xml', 'xaml': 'xml', 'astro': 'xml',
  'mako': 'xml', 'vue': 'xml',
  'css': 'css', 'scss': 'scss', 'less': 'less',
  // Scripts
  'py': 'python', 'pyw': 'python', 'pyi': 'python',
  'sh': 'bash', 'bash': 'bash', 'zsh': 'bash', 'csh': 'bash',
  'ps1': 'powershell', 'bat': 'dos', 'cmd': 'dos', 'lua': 'lua',
  'sql': 'sql',
  // Build
  'cmake': 'cmake', 'mk': 'makefile', 'mak': 'makefile',
  // Data / docs
  'json': 'json', 'jsonc': 'json', 'arb': 'json',
  'yaml': 'yaml', 'yml': 'yaml',
  'toml': 'ini', 'ini': 'ini', 'cfg': 'ini', 'conf': 'ini',
  'properties': 'properties',
  'md': 'markdown', 'markdown': 'markdown',
  'diff': 'diff', 'patch': 'diff',
};

/// The highlight.js language for a file, or 'plaintext'.
String languageForFile(String filename) {
  final name = filename.toLowerCase();
  final byName = _byName[name];
  if (byName != null) return byName;
  if (name.startsWith('dockerfile')) return 'dockerfile';
  if (name.startsWith('makefile')) return 'makefile';
  return _byExt[_ext(name)] ?? 'plaintext';
}

bool isTextFile(String filename) {
  final ext = _ext(filename);
  if (languageForFile(filename) != 'plaintext') return true;
  const textExts = {'txt', 'log', 'vcd', 'f', 'csv', 'gitignore'};
  return textExts.contains(ext) || ext.isEmpty;
}
