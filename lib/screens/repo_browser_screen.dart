import 'package:flutter/material.dart';
import '../models/repo_item.dart';
import '../services/github_service.dart';
import '../services/download_service.dart';
import '../services/prefs_service.dart';
import '../widgets/file_icon.dart';
import 'actions_screen.dart';
import 'file_viewer_screen.dart';
import '../theme.dart';

class RepoBrowserScreen extends StatefulWidget {
  final String owner;
  final String repo;
  final String? token;

  const RepoBrowserScreen({
    super.key,
    required this.owner,
    required this.repo,
    this.token,
  });

  @override
  State<RepoBrowserScreen> createState() => _RepoBrowserScreenState();
}

class _RepoBrowserScreenState extends State<RepoBrowserScreen> {
  late GitHubService _github;
  final Map<String, List<RepoItem>> _cache = {};
  final List<String> _pathStack = [];
  List<RepoItem> _currentItems = [];
  bool _loading = true;
  String? _error;
  RepoItem? _selectedItem;
  double _downloadProgress = 0;
  bool _downloading = false;

  String get _currentPath => _pathStack.join('/');

  @override
  void initState() {
    super.initState();
    _github = GitHubService(token: widget.token);
    _loadPath('');
    PrefsService.addRecentRepo('${widget.owner}/${widget.repo}');
  }

  Future<void> _loadPath(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = _cache[path] ??
          await _github.getContents(widget.owner, widget.repo, path);
      _cache[path] = items;
      setState(() {
        _currentItems = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _navigateTo(RepoItem item) {
    if (item.isDirectory) {
      setState(() {
        _pathStack.add(item.name);
        _selectedItem = null;
      });
      _loadPath(_currentPath);
    } else if (item.isFile) {
      setState(() => _selectedItem = item);
      if (MediaQuery.of(context).size.width < 800) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FileViewerScreen(
              item: item,
              owner: widget.owner,
              repo: widget.repo,
              github: _github,
            ),
          ),
        );
      }
    }
  }

  void _navigateBack() {
    if (_pathStack.isNotEmpty) {
      setState(() {
        _pathStack.removeLast();
        _selectedItem = null;
      });
      _loadPath(_currentPath);
    }
  }

  void _navigateToBreadcrumb(int index) {
    setState(() {
      _pathStack.removeRange(index + 1, _pathStack.length);
      _selectedItem = null;
    });
    _loadPath(_currentPath);
  }

  Future<void> _downloadZip() async {
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
    });
    try {
      final service = DownloadService();
      final zipUrl =
          'https://github.com/${widget.owner}/${widget.repo}/archive/refs/heads/main.zip';
      final path = await service.downloadZip(
        zipUrl,
        '${widget.owner}_${widget.repo}',
        onProgress: (received, total) {
          if (total > 0) {
            setState(
                () => _downloadProgress = received / total);
          }
        },
      );
      setState(() => _downloading = false);
      _showSnack('Saved to: $path');
    } catch (e) {
      setState(() => _downloading = false);
      _showSnack('Download failed: $e');
    }
  }

  void _openActions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActionsScreen(
          owner: widget.owner,
          repo: widget.repo,
          github: _github,
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 4)));
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.code, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              isWide ? '${widget.owner} / ${widget.repo}' : widget.repo,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.text,
                  fontFamily: 'monospace',
                  fontSize: 15),
            ),
          ),
        ]),
        iconTheme: IconThemeData(color: AppColors.text),
        actions: [
          // GitHub Actions runs and artifacts
          if (isWide)
            TextButton.icon(
              icon: Icon(Icons.play_circle_outline,
                  color: AppColors.warning, size: 18),
              label: Text('Actions',
                  style: TextStyle(color: AppColors.warning)),
              onPressed: _openActions,
            )
          else
            IconButton(
              icon: Icon(Icons.play_circle_outline,
                  color: AppColors.warning),
              tooltip: 'Actions',
              onPressed: _openActions,
            ),
          // Download ZIP button
          if (_downloading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 120,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LinearProgressIndicator(
                      value: _downloadProgress,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation(
                          AppColors.accent),
                    ),
                    Text(
                      '${(_downloadProgress * 100).toInt()}%',
                      style: TextStyle(
                          color: AppColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            )
          else if (isWide)
            TextButton.icon(
              icon: Icon(Icons.download,
                  color: AppColors.success, size: 18),
              label: Text('Download ZIP',
                  style: TextStyle(color: AppColors.success)),
              onPressed: _downloadZip,
            )
          else
            IconButton(
              icon: Icon(Icons.download, color: AppColors.success),
              tooltip: 'Download ZIP',
              onPressed: _downloadZip,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildBreadcrumb(),
          Expanded(
            child: isWide
                ? Row(children: [
                    SizedBox(width: 320, child: _buildFileTree()),
                    VerticalDivider(
                        width: 1, color: AppColors.border),
                    Expanded(child: _buildFilePane()),
                  ])
                : _buildFileTree(),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          InkWell(
            onTap: _pathStack.isNotEmpty
                ? () {
                    setState(() {
                      _pathStack.clear();
                      _selectedItem = null;
                    });
                    _loadPath('');
                  }
                : null,
            child: Text(
              widget.repo,
              style: TextStyle(
                color: _pathStack.isEmpty
                    ? AppColors.text
                    : AppColors.accent,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
          ..._pathStack.asMap().entries.map((e) => Row(children: [
                Text(' / ',
                    style: TextStyle(
                        color: AppColors.faint, fontSize: 13)),
                InkWell(
                  onTap: e.key < _pathStack.length - 1
                      ? () => _navigateToBreadcrumb(e.key)
                      : null,
                  child: Text(
                    e.value,
                    style: TextStyle(
                      color: e.key < _pathStack.length - 1
                          ? AppColors.accent
                          : AppColors.text,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
              ])),
        ],
      ),
    );
  }

  Widget _buildFileTree() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AppColors.danger, size: 40),
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: AppColors.danger),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _loadPath(_currentPath),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _currentItems.length +
          (_pathStack.isNotEmpty ? 1 : 0),
      itemBuilder: (context, i) {
        if (_pathStack.isNotEmpty && i == 0) {
          return ListTile(
            leading: Icon(Icons.arrow_upward,
                color: AppColors.muted, size: 20),
            title: Text('..',
                style: TextStyle(
                    color: AppColors.muted,
                    fontFamily: 'monospace')),
            dense: true,
            onTap: _navigateBack,
          );
        }
        final item = _currentItems[
            i - (_pathStack.isNotEmpty ? 1 : 0)];
        final isSelected = _selectedItem?.path == item.path;
        return Material(
          color: isSelected
              ? AppColors.surfaceAlt
              : Colors.transparent,
          child: ListTile(
            leading: FileIcon(
                name: item.name,
                isDirectory: item.isDirectory,
                size: 20),
            title: Text(
              item.name,
              style: TextStyle(
                color: isSelected
                    ? AppColors.accent
                    : AppColors.text,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
            trailing: item.isFile && item.size != null
                ? Text(
                    _formatSize(item.size!),
                    style: TextStyle(
                        color: AppColors.faint, fontSize: 11),
                  )
                : item.isDirectory
                    ? Icon(Icons.chevron_right,
                        color: AppColors.faint, size: 16)
                    : null,
            dense: true,
            onTap: () => _navigateTo(item),
          ),
        );
      },
    );
  }

  Widget _buildFilePane() {
    if (_selectedItem == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app,
                color: AppColors.border, size: 56),
            const SizedBox(height: 12),
            Text(
              'Select a file to view',
              style: TextStyle(
                  color: AppColors.muted, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return FileViewerScreen(
      item: _selectedItem!,
      owner: widget.owner,
      repo: widget.repo,
      github: _github,
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
