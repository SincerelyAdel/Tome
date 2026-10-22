import 'package:flutter/material.dart';
import '../app_nav.dart';
import '../services/github_org.dart';
import '../services/github_service.dart';
import '../theme.dart';

/// Deletes a repo in one step: a single dialog where you type its name to
/// confirm (instead of GitHub's several screens). Returns true once gone.
Future<bool> deleteRepoFlow(BuildContext context, GitHubService github,
    String owner, String repo) async {
  final ctrl = TextEditingController();
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) {
        final match = ctrl.text.trim() == repo;
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Delete $owner/$repo?',
              style: TextStyle(color: AppColors.text)),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'This deletes the repository, its issues, pull requests, '
                    'Actions runs and releases on GitHub. GitHub usually keeps '
                    'it restorable for 90 days under Settings → Repositories → '
                    'Deleted repositories.',
                    style: TextStyle(color: AppColors.muted, height: 1.45)),
                const SizedBox(height: 16),
                Text.rich(TextSpan(children: [
                  TextSpan(
                      text: 'Type ',
                      style: TextStyle(color: AppColors.text)),
                  TextSpan(
                      text: repo,
                      style: TextStyle(
                          color: AppColors.text,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700)),
                  TextSpan(
                      text: ' to confirm.',
                      style: TextStyle(color: AppColors.text)),
                ])),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (_) => setD(() {}),
                  onSubmitted: (_) {
                    if (match) Navigator.pop(ctx, true);
                  },
                  style: TextStyle(
                      color: AppColors.text, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: repo,
                    hintStyle: TextStyle(color: AppColors.faint),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child:
                    Text('Cancel', style: TextStyle(color: AppColors.muted))),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white),
              onPressed: match ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Delete repository'),
            ),
          ],
        );
      },
    ),
  );
  ctrl.dispose();
  if (go != true || !context.mounted) return false;

  try {
    await github.deleteRepo(owner, repo);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Deleted $owner/$repo')));
    }
    reposChanged.value++;
    return true;
  } catch (e) {
    // A dialog, not a snackbar: the reason is worth reading in full.
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Could not delete $repo',
              style: TextStyle(color: AppColors.text)),
          content: SelectableText(e is ApiException ? e.message : '$e',
              style: TextStyle(color: AppColors.muted, height: 1.5)),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK')),
          ],
        ),
      );
    }
    return false;
  }
}
