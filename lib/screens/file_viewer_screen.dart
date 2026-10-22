import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/github.dart';
import '../models/repo_item.dart';
import '../services/github_service.dart';
import '../services/claude_service.dart';
import '../services/prefs_service.dart';
import '../widgets/file_icon.dart';
import '../theme.dart';

class FileViewerScreen extends StatefulWidget {
  final RepoItem item;
  final String owner;
  final String repo;
  final GitHubService github;

  /// Branch to read from; null means the default branch.
  final String? branch;

  const FileViewerScreen({
    super.key,
    required this.item,
    required this.owner,
    required this.repo,
    required this.github,
    this.branch,
  });

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  String? _content;
  String? _error;
  bool _loading = true;
  String? _explanation;
  bool _explaining = false;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    try {
      final content = await widget.github
          .getFileContent(widget.owner, widget.repo, widget.item.path,
              ref: widget.branch);
      setState(() {
        _content = content;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _explain() async {
    final key = await PrefsService.getClaudeKey();
    if (key == null || key.isEmpty) {
      _showSnack('Add your Claude API key in Settings first');
      return;
    }
    setState(() => _explaining = true);
    try {
      final service = ClaudeService(apiKey: key);
      final result =
          await service.explainFile(widget.item.name, _content ?? '');
      setState(() {
        _explanation = result;
        _explaining = false;
      });
    } catch (e) {
      setState(() => _explaining = false);
      _showSnack('Claude error: $e');
    }
  }

  void _copy() {
    if (_content != null) {
      Clipboard.setData(ClipboardData(text: _content!));
      _showSnack('Copied to clipboard');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final lang = languageForFile(widget.item.name);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Row(children: [
          FileIcon(name: widget.item.name, isDirectory: false, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.item.name,
              style: TextStyle(
                  color: AppColors.text,
                  fontFamily: 'monospace',
                  fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        iconTheme: IconThemeData(color: AppColors.text),
        actions: [
          if (_content != null)
            IconButton(
              icon: Icon(Icons.copy, color: AppColors.muted),
              tooltip: 'Copy',
              onPressed: _copy,
            ),
          if (_content != null && lang == 'verilog')
            TextButton.icon(
              icon: _explaining
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent))
                  : Icon(Icons.auto_awesome,
                      color: AppColors.accent, size: 18),
              label: Text('Explain',
                  style: TextStyle(color: AppColors.accent)),
              onPressed: _explaining ? null : _explain,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: TextStyle(color: AppColors.danger)))
              : Column(
                  children: [
                    if (_explanation != null) _buildExplanation(),
                    Expanded(child: _buildCode(lang)),
                  ],
                ),
    );
  }

  Widget _buildExplanation() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.auto_awesome, color: AppColors.accent, size: 16),
            const SizedBox(width: 6),
            Text('Claude Explanation',
                style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.close,
                  color: AppColors.muted, size: 16),
              onPressed: () => setState(() => _explanation = null),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
          const SizedBox(height: 8),
          Text(_explanation!,
              style: TextStyle(
                  color: AppColors.text, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildCode(String lang) {
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(12),
          child: HighlightView(
            _content ?? '',
            language: lang,
            theme: {
              ..._codeTheme,
              'root': _codeTheme['root']!.copyWith(
                  backgroundColor: AppColors.surface, color: AppColors.text),
            },
            padding: const EdgeInsets.all(16),
            textStyle:
                const TextStyle(fontFamily: 'monospace', fontSize: 14, height: 1.5),
          ),
        ),
      ),
    );
  }
}

/// Syntax colors that match the current light or dark theme.
Map<String, TextStyle> get _codeTheme =>
    AppColors.isDark ? atomOneDarkTheme : githubTheme;
