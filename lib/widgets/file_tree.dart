import 'package:flutter/material.dart';
import '../models/github_models.dart';
import '../theme.dart';
import 'gh_widgets.dart';

/// The changed files of a pull request or commit as a folder tree, like the
/// sidebar of GitHub's "Files changed" page. Folders that hold only one
/// folder are joined into one row ("design/peripherals/modules"). Each file
/// shows whether it was added, changed, removed or renamed.
class FileTree extends StatefulWidget {
  const FileTree(
      {super.key, required this.files, required this.onTap, this.selected});

  final List<GhFileChange> files;
  final ValueChanged<GhFileChange> onTap;
  final String? selected;

  @override
  State<FileTree> createState() => _FileTreeState();
}

class _Node {
  _Node(this.name, this.path);
  String name;
  final String path;
  final Map<String, _Node> dirs = {};
  final List<GhFileChange> files = [];
}

const _statuses = ['added', 'modified', 'removed', 'renamed'];

class _FileTreeState extends State<FileTree> {
  final _filter = TextEditingController();
  final _closed = <String>{};
  final _hidden = <String>{};

  @override
  void initState() {
    super.initState();
    _filter.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  _Node _build(List<GhFileChange> files) {
    final root = _Node('', '');
    for (final f in files) {
      final parts = f.filename.split('/');
      var node = root;
      for (var i = 0; i < parts.length - 1; i++) {
        final path = parts.sublist(0, i + 1).join('/');
        node = node.dirs.putIfAbsent(parts[i], () => _Node(parts[i], path));
      }
      node.files.add(f);
    }
    _squash(root);
    return root;
  }

  /// Joins a folder with its only child folder when it has no files.
  void _squash(_Node n) {
    for (final key in n.dirs.keys.toList()) {
      var child = n.dirs[key]!;
      while (child.files.isEmpty && child.dirs.length == 1) {
        final only = child.dirs.values.first;
        final joined = _Node('${child.name}/${only.name}', only.path)
          ..dirs.addAll(only.dirs)
          ..files.addAll(only.files);
        child = joined;
      }
      n.dirs[key] = child;
      _squash(child);
    }
  }

  static String _base(String path) => path.split('/').last;

  @override
  Widget build(BuildContext context) {
    final q = _filter.text.trim().toLowerCase();
    final shown = widget.files
        .where((f) => !_hidden.contains(_kind(f.status)))
        .where((f) => q.isEmpty || f.filename.toLowerCase().contains(q))
        .toList();
    final root = _build(shown);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: _filterBox()),
          const SizedBox(width: 8),
          _filterMenu(),
        ]),
        const SizedBox(height: 10),
        Expanded(
          child: shown.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No files match.',
                      style: TextStyle(color: AppColors.muted, fontSize: 13)),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: _children(root, 0, q.isNotEmpty),
                ),
        ),
      ],
    );
  }

  Widget _filterBox() => TextField(
        controller: _filter,
        autocorrect: false,
        style: TextStyle(color: AppColors.text, fontSize: 13.5),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Filter files...',
          hintStyle: TextStyle(color: AppColors.faint),
          prefixIcon: Icon(Icons.search, size: 18, color: AppColors.muted),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 36),
          suffixIcon: _filter.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, size: 16, color: AppColors.muted),
                  onPressed: _filter.clear),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.border)),
        ),
      );

  /// Show or hide files by what happened to them.
  Widget _filterMenu() {
    final active = _hidden.isNotEmpty;
    return PopupMenuButton<String>(
      tooltip: 'Filter by change',
      onSelected: (s) => setState(() {
        if (!_hidden.remove(s)) _hidden.add(s);
      }),
      itemBuilder: (_) => [
        for (final s in _statuses)
          CheckedPopupMenuItem(
            value: s,
            checked: !_hidden.contains(s),
            child: Row(children: [
              statusBox(s),
              const SizedBox(width: 10),
              Text('${s[0].toUpperCase()}${s.substring(1)} files'),
            ]),
          ),
      ],
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active ? AppColors.accent.withOpacity(0.15) : AppColors.surface,
          border: Border.all(color: active ? AppColors.accent : AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.filter_list,
            size: 20, color: active ? AppColors.accent : AppColors.muted),
      ),
    );
  }

  static String _kind(String status) =>
      _statuses.contains(status) ? status : 'modified';

  List<Widget> _children(_Node n, int depth, bool openAll) {
    final dirs = n.dirs.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final files = [...n.files]..sort((a, b) =>
        _base(a.filename).toLowerCase().compareTo(_base(b.filename).toLowerCase()));
    return [
      for (final d in dirs) ..._folder(d, depth, openAll),
      for (final f in files) _file(f),
    ];
  }

  List<Widget> _folder(_Node d, int depth, bool openAll) {
    final open = openAll || !_closed.contains(d.path);
    return [
      _row(
        onTap: () => setState(() {
          if (!_closed.remove(d.path)) _closed.add(d.path);
        }),
        child: Row(children: [
          Icon(open ? Icons.expand_more : Icons.chevron_right,
              size: 18, color: AppColors.muted),
          const SizedBox(width: 4),
          Icon(Icons.folder, size: 18, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(d.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.text, fontSize: 13.5)),
          ),
        ]),
      ),
      if (open)
        Container(
          margin: const EdgeInsets.only(left: 16),
          padding: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _children(d, depth + 1, openAll),
          ),
        ),
    ];
  }

  Widget _file(GhFileChange f) {
    final selected = f.filename == widget.selected;
    return _row(
      selected: selected,
      onTap: () => widget.onTap(f),
      child: Row(children: [
        const SizedBox(width: 22),
        statusBox(f.status),
        const SizedBox(width: 10),
        Expanded(
          child: Text(_base(f.filename),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: f.status == 'removed' ? AppColors.muted : AppColors.text,
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
        ),
      ]),
    );
  }

  Widget _row(
      {required Widget child, required VoidCallback onTap, bool selected = false}) {
    return Material(
      color: selected ? AppColors.surfaceAlt : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: child,
        ),
      ),
    );
  }
}

/// GitHub's small square file-status mark: + added, ± changed, − removed,
/// → renamed.
Widget statusBox(String status) {
  final (String mark, Color color) = switch (status) {
    'added' => ('+', ghOpen),
    'removed' => ('−', ghClosed),
    'renamed' => ('→', AppColors.muted),
    _ => ('±', AppColors.muted),
  };
  return Container(
    width: 15,
    height: 15,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      border: Border.all(color: color, width: 1.4),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(mark,
        style: TextStyle(
            color: color,
            fontSize: 11,
            height: 1,
            fontWeight: FontWeight.w700)),
  );
}
