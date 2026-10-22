import 'package:flutter/material.dart';
import '../models/repo_item.dart';
import '../services/github_service.dart';
import '../services/download_service.dart';
import '../services/prefs_service.dart';
import '../widgets/file_icon.dart';
import 'actions_screen.dart';
import 'file_viewer_screen.dart';
import 'report_screen.dart';

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

  void _openReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportScreen(
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
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: Row(children: [
          const Icon(Icons.code, color: Color(0xFF58A6FF), size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              isWide ? '${widget.owner} / ${widget.repo}' : widget.repo,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Color(0xFFC9D1D9),
                  fontFamily: 'monospace',
                  fontSize: 15),
            ),
          ),
        ]),
        iconTheme: const IconThemeData(color: Color(0xFFC9D1D9)),
        actions: [
          // GitHub Actions runs and artifacts
          if (isWide)
            TextButton.icon(
              icon: const Icon(Icons.play_circle_outline,
                  color: Color(0xFFD29922), size: 18),
              label: const Text('Actions',
                  style: TextStyle(color: Color(0xFFD29922))),
              onPressed: _openActions,
            )
          else
            IconButton(
              icon: const Icon(Icons.play_circle_outline,
                  color: Color(0xFFD29922)),
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
                      backgroundColor: const Color(0xFF30363D),
                      valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF238636)),
                    ),
                    Text(
                      '${(_downloadProgress * 100).toInt()}%',
                      style: const TextStyle(
                          color: Color(0xFF8B949E), fontSize: 11),
                    ),
                  ],
                ),
              ),
            )
          else if (isWide)
            TextButton.icon(
              icon: const Icon(Icons.download,
                  color: Color(0xFF3FB950), size: 18),
              label: const Text('Download ZIP',
                  style: TextStyle(color: Color(0xFF3FB950))),
              onPressed: _downloadZip,
            )
          else
            IconButton(
              icon: const Icon(Icons.download, color: Color(0xFF3FB950)),
              tooltip: 'Download ZIP',
              onPressed: _downloadZip,
            ),
          // Generate report button
          if (isWide)
            TextButton.icon(
              icon: const Icon(Icons.auto_awesome,
                  color: Color(0xFF58A6FF), size: 18),
              label: const Text('Report',
                  style: TextStyle(color: Color(0xFF58A6FF))),
              onPressed: _openReport,
            )
          else
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: Color(0xFF58A6FF)),
              tooltip: 'Report',
              onPressed: _openReport,
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
                    const VerticalDivider(
                        width: 1, color: Color(0xFF30363D)),
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
      color: const Color(0xFF161B22),
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
                    ? const Color(0xFFC9D1D9)
                    : const Color(0xFF58A6FF),
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
          ..._pathStack.asMap().entries.map((e) => Row(children: [
                const Text(' / ',
                    style: TextStyle(
                        color: Color(0xFF484F58), fontSize: 13)),
                InkWell(
                  onTap: e.key < _pathStack.length - 1
                      ? () => _navigateToBreadcrumb(e.key)
                      : null,
                  child: Text(
                    e.value,
                    style: TextStyle(
                      color: e.key < _pathStack.length - 1
                          ? const Color(0xFF58A6FF)
                          : const Color(0xFFC9D1D9),
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
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(color: Colors.red),
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
            leading: const Icon(Icons.arrow_upward,
                color: Color(0xFF8B949E), size: 20),
            title: const Text('..',
                style: TextStyle(
                    color: Color(0xFF8B949E),
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
              ? const Color(0xFF1C2128)
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
                    ? const Color(0xFF58A6FF)
                    : const Color(0xFFC9D1D9),
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
            trailing: item.isFile && item.size != null
                ? Text(
                    _formatSize(item.size!),
                    style: const TextStyle(
                        color: Color(0xFF484F58), fontSize: 11),
                  )
                : item.isDirectory
                    ? const Icon(Icons.chevron_right,
                        color: Color(0xFF484F58), size: 16)
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
            const Icon(Icons.touch_app,
                color: Color(0xFF30363D), size: 56),
            const SizedBox(height: 12),
            Text(
              'Select a file to view',
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 14),
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
