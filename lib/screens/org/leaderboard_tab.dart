import 'package:flutter/material.dart';
import '../../models/leaderboard.dart';
import '../../services/github_org.dart';
import '../../services/github_service.dart';
import '../../theme.dart';
import '../../widgets/gh_widgets.dart';
import '../../widgets/loader.dart';
import 'org_screen.dart' show orgPad;

const _silver = Color(0xFFB4B8BF);
const _bronze = Color(0xFFC0844F);

/// Who commits the most across the org's repos, over a chosen period:
/// a podium for the top three, then everyone else ranked.
class LeaderboardTab extends StatefulWidget {
  const LeaderboardTab({super.key, required this.org, required this.github});

  final String org;
  final GitHubService github;

  @override
  State<LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<LeaderboardTab> {
  var _period = LeaderPeriod.all;

  @override
  Widget build(BuildContext context) {
    return Loader<OrgCommitStats>(
      load: () => widget.github.getOrgCommitStats(widget.org),
      builder: (context, stats, reload) {
        final ranked = rankContributors(stats.contributors, _period);
        final total = ranked.fold<int>(0, (n, e) => n + e.commits);
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(padding: orgPad, children: [
            segmentChips(
              [for (final p in LeaderPeriod.values) p.label],
              _period.index,
              (i) => setState(() => _period = LeaderPeriod.values[i]),
            ),
            const SizedBox(height: 10),
            Text(
              'Commits to the default branch of the ${stats.repoCount} most '
              'recently pushed repos. Forks and bots aren\'t counted.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            if (stats.pendingRepos.isNotEmpty) ...[
              const SizedBox(height: 8),
              _note(
                'GitHub is still counting ${stats.pendingRepos.length} '
                '${stats.pendingRepos.length == 1 ? 'repo' : 'repos'} '
                '(${stats.pendingRepos.take(3).join(', ')}'
                '${stats.pendingRepos.length > 3 ? ', …' : ''}). '
                'Pull down in a minute to include them.',
              ),
            ],
            const SizedBox(height: 20),
            if (ranked.isEmpty)
              emptyNote(_period == LeaderPeriod.all
                  ? 'No commits to count yet.'
                  : 'No commits in this period. Try a longer one.')
            else ...[
              _summary(ranked.length, total),
              const SizedBox(height: 24),
              _Podium(top: ranked.take(3).toList()),
              if (ranked.length > 3) ...[
                const SizedBox(height: 24),
                rowsBox([
                  for (var i = 3; i < ranked.length; i++)
                    _RankRow(
                      rank: i + 1,
                      entry: ranked[i],
                      best: ranked.first.commits,
                    ),
                ]),
              ],
            ],
          ]),
        );
      },
    );
  }

  Widget _summary(int people, int commits) {
    Widget stat(String value, String label) => Expanded(
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontFamily: kSerif,
                    color: AppColors.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        stat(compactCount(commits), commits == 1 ? 'commit' : 'commits'),
        Container(width: 1, height: 36, color: AppColors.border),
        stat('$people', people == 1 ? 'contributor' : 'contributors'),
      ]),
    );
  }

  Widget _note(String text) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.warning.withOpacity(0.5)),
        ),
        child: Text(text,
            style: TextStyle(color: AppColors.text, fontSize: 13, height: 1.4)),
      );
}

/// 2nd, 1st, 3rd side by side, the winner raised in the middle.
class _Podium extends StatelessWidget {
  const _Podium({required this.top});

  final List<LeaderEntry> top;

  @override
  Widget build(BuildContext context) {
    Widget place(int i) => Expanded(
          child: i < top.length
              ? _PodiumPlace(rank: i + 1, entry: top[i])
              : const SizedBox.shrink(),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [place(1), const SizedBox(width: 10), place(0), const SizedBox(width: 10), place(2)],
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  const _PodiumPlace({required this.rank, required this.entry});

  final int rank;
  final LeaderEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = switch (rank) {
      1 => AppColors.accentLight,
      2 => _silver,
      _ => _bronze,
    };
    final avatar = rank == 1 ? 76.0 : 60.0;
    final block = switch (rank) { 1 => 92.0, 2 => 68.0, _ => 52.0 };

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => openProfile(context, entry.login),
      child: Column(children: [
        Icon(Icons.emoji_events, color: color, size: rank == 1 ? 30 : 24),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.5),
            boxShadow: rank == 1
                ? [BoxShadow(color: color.withOpacity(0.45), blurRadius: 14)]
                : null,
          ),
          child: Avatar(entry.avatarUrl, size: avatar),
        ),
        const SizedBox(height: 8),
        Text(entry.login,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: AppColors.text,
                fontSize: rank == 1 ? 15 : 13.5,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text('${compactCount(entry.commits)} '
            '${entry.commits == 1 ? 'commit' : 'commits'}',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
        const SizedBox(height: 10),
        Container(
          height: block,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withOpacity(AppColors.isDark ? 0.16 : 0.22),
            border: Border(top: BorderSide(color: color, width: 3)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Text('$rank',
              style: TextStyle(
                  fontFamily: kSerif,
                  color: color,
                  fontSize: rank == 1 ? 34 : 26,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

/// Rank 4 and below: avatar, name, a bar against the leader, and totals.
class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.entry, required this.best});

  final int rank;
  final LeaderEntry entry;
  final int best;

  @override
  Widget build(BuildContext context) {
    final share = best == 0 ? 0.0 : entry.commits / best;
    return InkWell(
      onTap: () => openProfile(context, entry.login),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        child: Row(children: [
          SizedBox(
            width: 30,
            child: Text('$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Avatar(entry.avatarUrl, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(entry.login,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600)),
                  ),
                  Text(compactCount(entry.commits),
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: share.clamp(0.02, 1.0),
                    minHeight: 5,
                    color: AppColors.accent,
                    backgroundColor: AppColors.surfaceAlt,
                  ),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '+${compactCount(entry.additions)}',
                        style: TextStyle(color: AppColors.success)),
                    const TextSpan(text: '  '),
                    TextSpan(
                        text: '−${compactCount(entry.deletions)}',
                        style: TextStyle(color: AppColors.danger)),
                    TextSpan(
                        text: '  ·  ${entry.repos.length} '
                            '${entry.repos.length == 1 ? 'repo' : 'repos'}'),
                  ]),
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// 950 -> "950", 12400 -> "12.4k", 3100000 -> "3.1M".
String compactCount(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) {
    final k = n / 1000;
    return '${k >= 100 ? k.round() : k.toStringAsFixed(1).replaceAll('.0', '')}k';
  }
  final m = n / 1000000;
  return '${m >= 100 ? m.round() : m.toStringAsFixed(1).replaceAll('.0', '')}M';
}
