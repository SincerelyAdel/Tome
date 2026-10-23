import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/github_models.dart';
import '../../models/org_models.dart';
import '../../models/repo_item.dart';
import '../../services/github_org.dart';
import '../../services/github_service.dart';
import '../../theme.dart';
import '../../widgets/gh_widgets.dart';
import '../../widgets/loader.dart';
import '../repo_browser_screen.dart';

const _pad = EdgeInsets.fromLTRB(24, 10, 24, 48);

/// A tab with sub-view chips on top and a lazily loaded list below.
class _SubViews extends StatefulWidget {
  const _SubViews(
      {required this.labels, required this.build, this.generation = 0});

  final List<String> labels;

  /// Bump to reload the open sub-view (e.g. after a change).
  final int generation;
  final Widget Function(int view) build;

  @override
  State<_SubViews> createState() => _SubViewsState();
}

class _SubViewsState extends State<_SubViews> {
  int _view = 0;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
        child: segmentChips(
            widget.labels, _view, (i) => setState(() => _view = i)),
      ),
      Expanded(child: KeyedSubtree(key: ValueKey('$_view:${widget.generation}'), child: widget.build(_view))),
    ]);
  }
}

/// Loader + pull-to-refresh list in one.
Widget _list<T>(
  Future<T> Function() load,
  List<Widget> Function(BuildContext, T, Future<void> Function()) rows, {
  String? note,
}) {
  return Loader<T>(
    load: load,
    builder: (context, data, reload) => RefreshIndicator(
      onRefresh: reload,
      child: ListView(padding: _pad, children: rows(context, data, reload)),
    ),
  );
}

Widget _userRow(BuildContext context, GhUser u,
    {Widget? trailing, String? subtitle}) {
  return InkWell(
    onTap: () => openProfile(context, u.login),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(children: [
        Avatar(u.avatarUrl, size: 36),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(u.login,
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              if (subtitle != null)
                Text(subtitle,
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ]),
    ),
  );
}

// ================================================================== people

class PeopleTab extends StatefulWidget {
  const PeopleTab(
      {super.key,
      required this.org,
      required this.github,
      required this.isOwner});

  final String org;
  final GitHubService github;
  final bool isOwner;

  @override
  State<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<PeopleTab> {
  int _reloads = 0;

  GitHubService get _gh => widget.github;

  Future<void> _invite() async {
    final login = TextEditingController();
    var role = 'direct_member';
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Invite to ${widget.org}',
              style: TextStyle(color: AppColors.text)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: login,
              autofocus: true,
              autocorrect: false,
              style: TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                  labelText: 'GitHub username', prefixText: '@'),
            ),
            const SizedBox(height: 16),
            RadioListTile<String>(
              value: 'direct_member',
              groupValue: role,
              onChanged: (v) => setLocal(() => role = v!),
              title: Text('Member', style: TextStyle(color: AppColors.text)),
              subtitle: Text('Can see the org and join teams',
                  style: TextStyle(color: AppColors.muted)),
            ),
            RadioListTile<String>(
              value: 'admin',
              groupValue: role,
              onChanged: (v) => setLocal(() => role = v!),
              title: Text('Owner', style: TextStyle(color: AppColors.text)),
              subtitle: Text('Full control of the organization',
                  style: TextStyle(color: AppColors.muted)),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Send invitation')),
          ],
        ),
      ),
    );
    final name = login.text.trim().replaceFirst('@', '');
    if (go != true || name.isEmpty || !mounted) return;
    final ok = await runAction(
        context, () => _gh.inviteMember(widget.org, name, role),
        done: 'Invitation sent to @$name');
    if (ok && mounted) setState(() => _reloads++);
  }

  Future<void> _cancel(GhInvite i) async {
    final who = i.login.isNotEmpty ? '@${i.login}' : i.email;
    if (!await confirmAction(context,
        title: 'Cancel invitation?',
        message: '$who will no longer be able to join ${widget.org} with '
            'this invitation.',
        action: 'Cancel invitation',
        danger: true)) {
      return;
    }
    if (!mounted) return;
    final ok = await runAction(
        context, () => _gh.cancelInvitation(widget.org, i.id),
        done: 'Invitation cancelled');
    if (ok && mounted) setState(() => _reloads++);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      _SubViews(
        generation: _reloads,
        labels: const ['Members', 'Invitations', 'Outside collaborators'],
        build: (view) => switch (view) {
          0 => _list<List<GhMember>>(
              () => _gh.getOrgMembers(widget.org),
              (context, members, _) => [
                Text(
                    '${members.length} member${members.length == 1 ? '' : 's'}'
                    ' · ${members.where((m) => m.isOwner).length} owner'
                    '${members.where((m) => m.isOwner).length == 1 ? '' : 's'}',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                const SizedBox(height: 10),
                rowsBox([
                  for (final m in members)
                    _userRow(context, m.user,
                        trailing: m.isOwner
                            ? pill('Owner', AppColors.accent)
                            : pill('Member', AppColors.muted)),
                ]),
              ],
            ),
          1 => _list<List<GhInvite>>(
              () => _gh.getInvitations(widget.org),
              (context, invites, _) => [
                if (invites.isEmpty)
                  emptyNote('No pending invitations.')
                else
                  rowsBox([
                    for (final i in invites)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                        child: Row(children: [
                          Icon(Icons.mail_outline, color: AppColors.muted),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    i.login.isNotEmpty ? i.login : i.email,
                                    style: TextStyle(
                                        color: AppColors.text,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                    'Invited ${timeAgo(i.createdAt)}'
                                    '${i.inviter.isEmpty ? '' : ' by ${i.inviter}'}',
                                    style: TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12.5)),
                              ],
                            ),
                          ),
                          pill(i.roleLabel, AppColors.muted),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => _cancel(i),
                            child: Text('Cancel',
                                style: TextStyle(color: AppColors.danger)),
                          ),
                        ]),
                      ),
                  ]),
              ],
            ),
          _ => _list<List<GhUser>>(
              () => _gh.getOutsideCollaborators(widget.org),
              (context, users, _) => [
                Text('People with access to some repos who aren\'t members.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                const SizedBox(height: 10),
                if (users.isEmpty)
                  emptyNote('No outside collaborators.')
                else
                  rowsBox([for (final u in users) _userRow(context, u)]),
              ],
            ),
        },
      ),
      if (widget.isOwner)
        Positioned(
          right: 24,
          bottom: 24,
          child: FloatingActionButton.extended(
            backgroundColor: AppColors.button,
            foregroundColor: AppColors.onButton,
            onPressed: _invite,
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Invite member'),
          ),
        ),
    ]);
  }
}

// =================================================================== teams

class TeamsTab extends StatelessWidget {
  const TeamsTab({super.key, required this.org, required this.github});

  final String org;
  final GitHubService github;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _list<List<GhTeam>>(
        () => github.getTeams(org),
        (context, teams, _) => [
          if (teams.isEmpty)
            emptyNote('No teams yet.')
          else
            rowsBox([
              for (final t in teams)
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TeamScreen(org: org, team: t, github: github),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(children: [
                      Icon(Icons.groups_outlined, color: AppColors.accent),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.name,
                                style: TextStyle(
                                    color: AppColors.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                            if (t.description.isNotEmpty || t.parent.isNotEmpty)
                              Text(
                                  [
                                    if (t.parent.isNotEmpty) 'in ${t.parent}',
                                    if (t.description.isNotEmpty) t.description,
                                  ].join('  ·  '),
                                  style: TextStyle(
                                      color: AppColors.muted, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      if (t.privacy == 'secret')
                        pill('Secret', AppColors.muted)
                      else
                        pill('Visible', AppColors.muted),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right, color: AppColors.faint),
                    ]),
                  ),
                ),
            ]),
        ],
      ),
    );
  }
}

class TeamScreen extends StatelessWidget {
  const TeamScreen(
      {super.key, required this.org, required this.team, required this.github});

  final String org;
  final GhTeam team;
  final GitHubService github;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        iconTheme: IconThemeData(color: AppColors.text),
        title: Text('$org / ${team.name}'),
      ),
      body: _SubViews(
        labels: const ['Members', 'Repositories'],
        build: (view) => view == 0
            ? _list<List<GhUser>>(
                () => github.getTeamMembers(org, team.slug),
                (context, users, _) => [
                  if (users.isEmpty)
                    emptyNote('No members.')
                  else
                    rowsBox([for (final u in users) _userRow(context, u)]),
                ],
              )
            : _list<List<(RepoInfo, String)>>(
                () => github.getTeamRepos(org, team.slug),
                (context, repos, _) => [
                  if (repos.isEmpty)
                    emptyNote('This team has no repositories.')
                  else
                    rowsBox([
                      for (final (r, perm) in repos)
                        ListTile(
                          leading: Icon(Icons.book_outlined,
                              color: AppColors.muted),
                          title: Text(r.name,
                              style: TextStyle(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w600)),
                          subtitle: r.description.isEmpty
                              ? null
                              : Text(r.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: AppColors.muted)),
                          trailing: pill(perm, AppColors.accent),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RepoBrowserScreen(
                                  owner: r.owner,
                                  repo: r.name,
                                  token: github.token),
                            ),
                          ),
                        ),
                    ]),
                ],
              ),
      ),
    );
  }
}

// ================================================================ security

class SecurityTab extends StatelessWidget {
  const SecurityTab({super.key, required this.org, required this.github});

  final String org;
  final GitHubService github;

  @override
  Widget build(BuildContext context) {
    const note = 'Code scanning and secret scanning on private repos need '
        'GitHub Advanced Security. Tokens need the security_events scope.';
    return _SubViews(
      labels: const ['Dependabot', 'Code scanning', 'Secret scanning'],
      build: (view) => Loader<List<GhAlert>>(
        load: () => switch (view) {
          0 => github.getDependabotAlerts(org),
          1 => github.getCodeScanningAlerts(org),
          _ => github.getSecretScanningAlerts(org),
        },
        builder: (context, alerts, reload) => RefreshIndicator(
          onRefresh: reload,
          child: ListView(padding: _pad, children: [
            if (alerts.isEmpty)
              emptyNote('No open alerts. 🎉')
            else ...[
              _severitySummary(alerts),
              const SizedBox(height: 12),
              rowsBox([for (final a in alerts) _alertRow(context, a)]),
            ],
            if (view > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(note,
                    style: TextStyle(color: AppColors.faint, fontSize: 12)),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _severitySummary(List<GhAlert> alerts) {
    final counts = <String, int>{};
    for (final a in alerts) {
      counts[a.severity.toLowerCase()] =
          (counts[a.severity.toLowerCase()] ?? 0) + 1;
    }
    return Wrap(spacing: 8, runSpacing: 6, children: [
      for (final s in ['critical', 'high', 'medium', 'low', 'warning', 'note', 'error'])
        if (counts[s] != null) pill('${counts[s]} $s', severityColor(s)),
    ]);
  }

  Widget _alertRow(BuildContext context, GhAlert a) {
    return InkWell(
      onTap: () => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(a.title, style: TextStyle(color: AppColors.text)),
          content: SingleChildScrollView(
            child: SelectableText(
                [
                  '${a.repo} · #${a.number}',
                  if (a.severity.isNotEmpty) 'Severity: ${a.severity}',
                  if (a.location.isNotEmpty) 'Location: ${a.location}',
                  if (a.detail.isNotEmpty) '\n${a.detail}',
                  if (a.extra.isNotEmpty) '\n${a.extra}',
                  if (a.createdAt != null) '\nOpened ${timeAgo(a.createdAt)}',
                ].join('\n'),
                style: TextStyle(color: AppColors.text, height: 1.5)),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(a.kind == 'secret' ? Icons.key_outlined : Icons.shield_outlined,
              size: 20, color: severityColor(a.severity)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                    [
                      a.repo,
                      '#${a.number}',
                      if (a.location.isNotEmpty) a.location,
                      if (a.createdAt != null) timeAgo(a.createdAt),
                    ].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
              ],
            ),
          ),
          if (a.severity.isNotEmpty && a.kind != 'secret')
            pill(a.severity, severityColor(a.severity)),
        ]),
      ),
    );
  }
}

Color severityColor(String s) => switch (s.toLowerCase()) {
      'critical' || 'error' => ghClosed,
      'high' => const Color(0xFFF0883E),
      'medium' || 'moderate' || 'warning' => AppColors.warning,
      _ => AppColors.muted,
    };

// ================================================================ settings

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key, required this.org, required this.github});

  final String org;
  final GitHubService github;

  @override
  Widget build(BuildContext context) {
    return _SubViews(
      labels: const ['Secrets', 'Variables', 'Billing', 'Audit log'],
      build: (view) => switch (view) {
        0 => _list<List<GhSetting>>(
            () => github.getOrgSecrets(org),
            (context, secrets, _) => [
              Text('GitHub never reveals secret values, only their names.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
              const SizedBox(height: 10),
              if (secrets.isEmpty)
                emptyNote('No organization secrets.')
              else
                rowsBox([for (final s in secrets) _settingRow(context, s)]),
            ],
          ),
        1 => _list<List<GhSetting>>(
            () => github.getOrgVariables(org),
            (context, vars, _) => [
              if (vars.isEmpty)
                emptyNote('No organization variables.')
              else
                rowsBox([for (final v in vars) _settingRow(context, v)]),
            ],
          ),
        2 => Loader<List<GhBillingLine>>(
            load: () => github.getBilling(org),
            builder: (context, lines, reload) => RefreshIndicator(
              onRefresh: reload,
              child: ListView(padding: _pad, children: _billing(lines)),
            ),
          ),
        _ => _AuditLog(org: org, github: github),
      },
    );
  }

  Widget _settingRow(BuildContext context, GhSetting s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(children: [
        Icon(s.value == null ? Icons.key_outlined : Icons.data_object,
            size: 19, color: AppColors.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.name,
                  style: TextStyle(
                      color: AppColors.text,
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              if (s.value != null)
                GestureDetector(
                  onLongPress: () =>
                      Clipboard.setData(ClipboardData(text: s.value!)),
                  child: Text(s.value!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.muted,
                          fontFamily: 'monospace',
                          fontSize: 12.5)),
                ),
              if (s.updatedAt != null)
                Text('Updated ${timeAgo(s.updatedAt)}',
                    style: TextStyle(color: AppColors.faint, fontSize: 12)),
            ],
          ),
        ),
        pill(
            switch (s.visibility) {
              'all' => 'All repos',
              'private' => 'Private repos',
              'selected' => 'Selected repos',
              final v => v,
            },
            AppColors.muted),
      ]),
    );
  }

  List<Widget> _billing(List<GhBillingLine> lines) {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final net = lines.fold<double>(0, (a, l) => a + l.net);
    final gross = lines.fold<double>(0, (a, l) => a + l.gross);
    String qty(double q) =>
        q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);
    return [
      Text('${months[now.month - 1]} ${now.year}',
          style: TextStyle(
              fontFamily: kSerif, color: AppColors.text, fontSize: 22)),
      const SizedBox(height: 4),
      if (gross > 0)
        Text(
            'Gross \$${gross.toStringAsFixed(2)} · after discounts '
            '\$${net.toStringAsFixed(2)}',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
      const SizedBox(height: 12),
      if (lines.isEmpty)
        emptyNote('No usage this month.')
      else
        rowsBox([
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.sku,
                          style: TextStyle(
                              color: AppColors.text,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600)),
                      Text(l.product,
                          style: TextStyle(
                              color: AppColors.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
                Text('${qty(l.quantity)} ${l.unit}',
                    style: TextStyle(color: AppColors.text, fontSize: 14)),
                if (l.gross > 0) ...[
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 90,
                    child: Text('\$${l.net.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
            ),
        ]),
    ];
  }
}

class _AuditLog extends StatefulWidget {
  const _AuditLog({required this.org, required this.github});

  final String org;
  final GitHubService github;

  @override
  State<_AuditLog> createState() => _AuditLogState();
}

class _AuditLogState extends State<_AuditLog> {
  List<GhAuditEntry>? _entries;
  Object? _error;
  final _filter = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filter.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final e = await widget.github.getAuditLog(widget.org);
      if (mounted) setState(() => _entries = e);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    if (entries == null) {
      if (_error == null) {
        return const Center(child: CircularProgressIndicator());
      }
      final notEnterprise = _error is ApiException &&
          ((_error as ApiException).status == 404 ||
              (_error as ApiException).status == 403);
      return errorPanel(
        notEnterprise
            ? const ApiException(404,
                'GitHub only serves the audit log to apps on the Enterprise '
                'Cloud plan.')
            : _error!,
        note: notEnterprise
            ? 'As owner you can still read it on github.com: the org\'s '
                'Settings → Logs → Audit log.'
            : null,
        onRetry: _load,
      );
    }
    final q = _filter.text.trim().toLowerCase();
    final shown = entries
        .where((e) =>
            q.isEmpty ||
            e.action.toLowerCase().contains(q) ||
            e.actor.toLowerCase().contains(q) ||
            e.target.toLowerCase().contains(q))
        .toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: _pad, children: [
        TextField(
          controller: _filter,
          style: TextStyle(color: AppColors.text, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Filter by action, person or target',
            prefixIcon: Icon(Icons.search, size: 20, color: AppColors.muted),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.border)),
          ),
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          emptyNote('No events.')
        else
          rowsBox([
            for (final e in shown)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
                child: Row(children: [
                  Avatar('https://github.com/${e.actor}.png?size=64',
                      size: 26, login: e.actor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(TextSpan(children: [
                          userSpan(e.actor,
                              style: TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          const TextSpan(text: '  '),
                          TextSpan(
                              text: e.action,
                              style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: AppColors.accent,
                                  fontSize: 13)),
                        ])),
                        if (e.target.isNotEmpty)
                          Text(e.target,
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  Text(timeAgo(e.at),
                      style: TextStyle(color: AppColors.faint, fontSize: 12)),
                ]),
              ),
          ]),
      ]),
    );
  }
}
