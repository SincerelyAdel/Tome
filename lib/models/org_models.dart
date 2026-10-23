import 'github_models.dart';

/// Organization data: people, teams, runners, alerts, settings, billing,
/// audit log, projects and search results.

class GhMember {
  final GhUser user;
  final bool isOwner;

  const GhMember(this.user, {this.isOwner = false});
}

class GhInvite {
  final int id;
  final String login; // empty for email invites
  final String email;
  final String role;
  final DateTime? createdAt;
  final String inviter;

  const GhInvite({
    required this.id,
    required this.login,
    required this.email,
    required this.role,
    this.createdAt,
    this.inviter = '',
  });

  factory GhInvite.fromJson(Map<String, dynamic> j) => GhInvite(
        id: j['id'] ?? 0,
        login: j['login'] ?? '',
        email: j['email'] ?? '',
        role: j['role'] ?? 'direct_member',
        createdAt: DateTime.tryParse(j['created_at'] ?? ''),
        inviter: j['inviter']?['login'] ?? '',
      );

  String get roleLabel => switch (role) {
        'admin' => 'Owner',
        'billing_manager' => 'Billing manager',
        _ => 'Member',
      };
}

class GhTeam {
  final String slug;
  final String name;
  final String description;
  final String privacy;
  final String parent;

  const GhTeam({
    required this.slug,
    required this.name,
    this.description = '',
    this.privacy = '',
    this.parent = '',
  });

  factory GhTeam.fromJson(Map<String, dynamic> j) => GhTeam(
        slug: j['slug'] ?? '',
        name: j['name'] ?? '',
        description: j['description'] ?? '',
        privacy: j['privacy'] ?? '',
        parent: j['parent']?['name'] ?? '',
      );
}

class GhRunner {
  final String name;
  final String os;
  final bool online;
  final bool busy;
  final List<String> labels;

  const GhRunner({
    required this.name,
    required this.os,
    required this.online,
    required this.busy,
    this.labels = const [],
  });

  factory GhRunner.fromJson(Map<String, dynamic> j) => GhRunner(
        name: j['name'] ?? '',
        os: j['os'] ?? '',
        online: j['status'] == 'online',
        busy: j['busy'] == true,
        labels: ((j['labels'] as List?) ?? [])
            .map((l) => (l['name'] ?? '').toString())
            .toList(),
      );
}

/// A Dependabot, code scanning or secret scanning alert.
class GhAlert {
  final String kind; // dependabot, code, secret
  final int number;
  final String repo;
  final String title;
  final String severity; // critical, high, medium, low, or ''
  final String detail;
  final String location;
  final DateTime? createdAt;
  final String extra;

  const GhAlert({
    required this.kind,
    required this.number,
    required this.repo,
    required this.title,
    this.severity = '',
    this.detail = '',
    this.location = '',
    this.createdAt,
    this.extra = '',
  });

  factory GhAlert.dependabot(Map<String, dynamic> j) {
    final adv = j['security_advisory'] ?? {};
    final vuln = j['security_vulnerability'] ?? {};
    final pkg = j['dependency']?['package'] ?? {};
    final patched = vuln['first_patched_version']?['identifier'];
    return GhAlert(
      kind: 'dependabot',
      number: j['number'] ?? 0,
      repo: j['repository']?['name'] ?? '',
      title: adv['summary'] ?? '',
      severity: (vuln['severity'] ?? adv['severity'] ?? '').toString(),
      detail: [
        '${pkg['ecosystem'] ?? ''} · ${pkg['name'] ?? ''}',
        if ((vuln['vulnerable_version_range'] ?? '').toString().isNotEmpty)
          'Affected: ${vuln['vulnerable_version_range']}',
        patched == null ? 'No patched version yet' : 'Fixed in $patched',
      ].join('\n'),
      location: j['dependency']?['manifest_path'] ?? '',
      createdAt: DateTime.tryParse(j['created_at'] ?? ''),
      extra: [adv['ghsa_id'], adv['cve_id']]
          .where((x) => x != null && x.toString().isNotEmpty)
          .join(' · '),
    );
  }

  factory GhAlert.codeScanning(Map<String, dynamic> j) {
    final rule = j['rule'] ?? {};
    final inst = j['most_recent_instance'] ?? {};
    final loc = inst['location'] ?? {};
    return GhAlert(
      kind: 'code',
      number: j['number'] ?? 0,
      repo: j['repository']?['name'] ?? '',
      title: rule['description'] ?? rule['name'] ?? '',
      severity: (rule['security_severity_level'] ?? rule['severity'] ?? '')
          .toString(),
      detail: inst['message']?['text'] ?? '',
      location: loc['path'] == null
          ? ''
          : '${loc['path']}${loc['start_line'] == null ? '' : ':${loc['start_line']}'}',
      createdAt: DateTime.tryParse(j['created_at'] ?? ''),
      extra: '${j['tool']?['name'] ?? ''} · ${rule['id'] ?? ''}',
    );
  }

  factory GhAlert.secret(Map<String, dynamic> j) => GhAlert(
        kind: 'secret',
        number: j['number'] ?? 0,
        repo: j['repository']?['name'] ?? '',
        title: j['secret_type_display_name'] ?? j['secret_type'] ?? 'Secret',
        severity: 'high',
        detail: [
          if (j['validity'] != null) 'Validity: ${j['validity']}',
          if (j['push_protection_bypassed'] == true)
            'Push protection was bypassed',
        ].join('\n'),
        createdAt: DateTime.tryParse(j['created_at'] ?? ''),
      );
}

/// An Actions secret (name only; GitHub never returns values) or variable.
class GhSetting {
  final String name;
  final String? value;
  final String visibility;
  final DateTime? updatedAt;

  const GhSetting(
      {required this.name, this.value, this.visibility = '', this.updatedAt});

  factory GhSetting.fromJson(Map<String, dynamic> j) => GhSetting(
        name: j['name'] ?? '',
        value: j['value'],
        visibility: j['visibility'] ?? '',
        updatedAt: DateTime.tryParse(j['updated_at'] ?? ''),
      );
}

/// One billing line: a product/SKU's use this month.
class GhBillingLine {
  final String product;
  final String sku;
  final double quantity;
  final String unit;
  final double gross;
  final double net;

  const GhBillingLine({
    required this.product,
    required this.sku,
    required this.quantity,
    required this.unit,
    this.gross = 0,
    this.net = 0,
  });
}

class GhAuditEntry {
  final String action;
  final String actor;
  final String target;
  final DateTime? at;
  final Map<String, dynamic> raw;

  const GhAuditEntry(
      {required this.action,
      required this.actor,
      required this.target,
      this.at,
      this.raw = const {}});

  factory GhAuditEntry.fromJson(Map<String, dynamic> j) {
    final ms = j['@timestamp'] ?? j['created_at'];
    return GhAuditEntry(
      action: j['action'] ?? '',
      actor: j['actor'] ?? '',
      target: [j['repo'], j['team'], j['user'], j['name']]
          .where((x) => x != null && x.toString().isNotEmpty)
          .join(' · '),
      at: ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : null,
      raw: j,
    );
  }
}

/// An org Project (the new Projects).
class GhProject {
  final int number;
  final String title;
  final String description;
  final bool closed;
  final DateTime? updatedAt;
  final int items;

  const GhProject({
    required this.number,
    required this.title,
    this.description = '',
    this.closed = false,
    this.updatedAt,
    this.items = 0,
  });
}

class GhProjectItem {
  final String status; // '' = no status
  final String type; // ISSUE, PULL_REQUEST, DRAFT_ISSUE
  final String owner;
  final String repo;

  /// Null for draft issues.
  final GhIssue? issue;
  final String title;

  const GhProjectItem({
    required this.status,
    required this.type,
    required this.title,
    this.owner = '',
    this.repo = '',
    this.issue,
  });
}

class GhProjectBoard {
  final String title;

  /// Status column names, in the project's order.
  final List<String> columns;
  final List<GhProjectItem> items;

  const GhProjectBoard(
      {required this.title, required this.columns, required this.items});
}

/// An issue or PR found by search, with the repo it lives in.
class GhSearchItem {
  final String owner;
  final String repo;
  final GhIssue issue;
  final DateTime? updatedAt;

  const GhSearchItem(this.owner, this.repo, this.issue, {this.updatedAt});
}
