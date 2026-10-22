import 'package:flutter/material.dart';
import '../../models/github_models.dart';
import '../../services/github_service.dart';
import '../../theme.dart';
import '../../widgets/gh_widgets.dart';

/// All branches. Tapping one makes it the branch shown in Code and Commits.
class BranchesTab extends StatefulWidget {
  const BranchesTab({
    super.key,
    required this.owner,
    required this.repo,
    required this.github,
    required this.defaultBranch,
    required this.current,
    required this.onSelect,
    this.onCount,
  });

  final String owner;
  final String repo;
  final GitHubService github;
  final String? defaultBranch;
  final String? current;
  final ValueChanged<String> onSelect;
  final ValueChanged<int>? onCount;

  @override
  State<BranchesTab> createState() => _BranchesTabState();
}

class _BranchesTabState extends State<BranchesTab> {
  List<GhBranch>? _branches;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final b = await widget.github.getBranches(widget.owner, widget.repo);
      if (!mounted) return;
      setState(() => _branches = b);
      widget.onCount?.call(b.length);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_branches == null) return tabMessage(error: _error, onRetry: _load);
    if (_branches!.isEmpty) return tabMessage(empty: 'No branches');
    // Default branch first, then alphabetical. Sorted here because the
    // default branch name may arrive after the list.
    final branches = [..._branches!]..sort((x, y) {
        if (x.name == widget.defaultBranch) return -1;
        if (y.name == widget.defaultBranch) return 1;
        return x.name.toLowerCase().compareTo(y.name.toLowerCase());
      });
    final current = widget.current ?? widget.defaultBranch;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: branches.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
        itemBuilder: (_, i) {
          final b = branches[i];
          final selected = b.name == current;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Icon(Icons.account_tree_outlined,
                color: selected ? AppColors.accent : AppColors.muted, size: 20),
            title: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(b.name,
                    style: TextStyle(
                        color: selected ? AppColors.accent : AppColors.text,
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400)),
                if (b.name == widget.defaultBranch) outlineBadge('default'),
                if (b.isProtected)
                  Icon(Icons.shield_outlined, size: 15, color: AppColors.muted),
              ],
            ),
            trailing: selected
                ? Icon(Icons.check, color: AppColors.accent, size: 20)
                : Icon(Icons.chevron_right, color: AppColors.faint),
            onTap: () => widget.onSelect(b.name),
          );
        },
      ),
    );
  }
}
