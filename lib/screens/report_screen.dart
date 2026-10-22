import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/claude_service.dart';
import '../services/github_service.dart';
import '../services/prefs_service.dart';
import '../theme.dart';

class ReportScreen extends StatefulWidget {
  final String owner;
  final String repo;
  final GitHubService github;

  const ReportScreen({
    super.key,
    required this.owner,
    required this.repo,
    required this.github,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  List<_FileEntry> _files = [];
  bool _loadingFiles = true;
  bool _generating = false;
  String _report = '';
  final _labCtrl = TextEditingController();
  final _extraCtrl = TextEditingController();
  final _reportCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadVerilogFiles();
  }

  Future<void> _loadVerilogFiles() async {
    try {
      final files = await widget.github
          .getAllVerilogFiles(widget.owner, widget.repo);
      setState(() {
        _files = files
            .map((f) => _FileEntry(item: f, selected: true))
            .toList();
        _loadingFiles = false;
      });
    } catch (e) {
      setState(() => _loadingFiles = false);
      _showSnack('Failed to load files: $e');
    }
  }

  Future<void> _generate() async {
    final key = await PrefsService.getClaudeKey();
    if (key == null || key.isEmpty) {
      _showSnack('Add your Claude API key in Settings first');
      return;
    }

    final selected = _files.where((f) => f.selected).toList();
    if (selected.isEmpty) {
      _showSnack('Select at least one file');
      return;
    }

    setState(() {
      _generating = true;
      _report = '';
    });

    try {
      // Fetch all selected file contents
      final Map<String, String> contents = {};
      for (final entry in selected) {
        final content = await widget.github.getFileContent(
            widget.owner, widget.repo, entry.item.path);
        contents[entry.item.path] = content;
      }

      final service = ClaudeService(apiKey: key);
      await for (final chunk in service.generateReport(
        contents,
        '${widget.owner}/${widget.repo}',
        labNumber: _labCtrl.text.trim().isEmpty ? null : _labCtrl.text.trim(),
        extraInstructions:
            _extraCtrl.text.trim().isEmpty ? null : _extraCtrl.text.trim(),
      )) {
        setState(() => _report = chunk);
        // Auto-scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_reportCtrl.hasClients) {
            _reportCtrl.animateTo(
              _reportCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      setState(() => _generating = false);
    }
  }

  void _copyReport() {
    Clipboard.setData(ClipboardData(text: _report));
    _showSnack('Report copied to clipboard');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Generate Report',
            style: TextStyle(color: AppColors.text)),
        iconTheme: const IconThemeData(color: AppColors.text),
        actions: [
          if (_report.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy, color: AppColors.muted),
              tooltip: 'Copy report',
              onPressed: _copyReport,
            ),
        ],
      ),
      body: isWide
          ? Row(children: [
              SizedBox(width: 340, child: _buildConfig()),
              const VerticalDivider(
                  width: 1, color: AppColors.border),
              Expanded(child: _buildOutput()),
            ])
          : Column(children: [
              Expanded(child: _buildConfig()),
              const Divider(height: 1, color: AppColors.border),
              Expanded(child: _buildOutput()),
            ]),
    );
  }

  Widget _buildConfig() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Lab Number (optional)'),
          const SizedBox(height: 6),
          _textField(_labCtrl, 'e.g. 2'),
          const SizedBox(height: 16),
          _label('Extra Instructions (optional)'),
          const SizedBox(height: 6),
          _textField(_extraCtrl,
              'e.g. Focus on structural modeling, include EQSemi branding',
              maxLines: 3),
          const SizedBox(height: 20),
          _label('Verilog Files'),
          const SizedBox(height: 6),
          Row(children: [
            TextButton(
              onPressed: () => setState(
                  () => _files.forEach((f) => f.selected = true)),
              child: const Text('All',
                  style: TextStyle(color: AppColors.accent)),
            ),
            TextButton(
              onPressed: () => setState(
                  () => _files.forEach((f) => f.selected = false)),
              child: const Text('None',
                  style: TextStyle(color: AppColors.muted)),
            ),
          ]),
          Expanded(
            child: _loadingFiles
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _files.length,
                    itemBuilder: (context, i) {
                      final f = _files[i];
                      return CheckboxListTile(
                        value: f.selected,
                        onChanged: (v) =>
                            setState(() => f.selected = v ?? false),
                        title: Text(
                          f.item.path,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                        dense: true,
                        activeColor: AppColors.accent,
                        checkColor: AppColors.onAccent,
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.onAccent))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(_generating ? 'Generating...' : 'Generate Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutput() {
    if (_report.isEmpty && !_generating) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined,
                color: AppColors.border, size: 64),
            SizedBox(height: 12),
            Text('Configure and generate your report',
                style: TextStyle(color: AppColors.faint)),
          ],
        ),
      );
    }

    return Scrollbar(
      controller: _reportCtrl,
      child: SingleChildScrollView(
        controller: _reportCtrl,
        padding: const EdgeInsets.all(20),
        child: SelectableText(
          _report,
          style: const TextStyle(
            color: AppColors.text,
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.bold));

  Widget _textField(TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style:
          const TextStyle(color: AppColors.text, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.faint),
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  @override
  void dispose() {
    _labCtrl.dispose();
    _extraCtrl.dispose();
    _reportCtrl.dispose();
    super.dispose();
  }
}

class _FileEntry {
  final dynamic item;
  bool selected;
  _FileEntry({required this.item, required this.selected});
}
