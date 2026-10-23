import 'package:flutter/material.dart';
import '../models/github_models.dart';
import '../screens/profile_screen.dart';
import '../theme.dart';

/// "3d ago", "2h ago" ...
String timeAgo(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inDays >= 365) return '${d.inDays ~/ 365}y ago';
  if (d.inDays >= 30) return '${d.inDays ~/ 30}mo ago';
  if (d.inDays >= 1) return '${d.inDays}d ago';
  if (d.inHours >= 1) return '${d.inHours}h ago';
  if (d.inMinutes >= 1) return '${d.inMinutes}m ago';
  return 'just now';
}

// GitHub's state colors, slightly tuned per theme.
Color get ghOpen =>
    AppColors.isDark ? const Color(0xFF3FB950) : const Color(0xFF1A7F37);
Color get ghClosed =>
    AppColors.isDark ? const Color(0xFFF85149) : const Color(0xFFCF222E);
Color get ghMerged =>
    AppColors.isDark ? const Color(0xFFA371F7) : const Color(0xFF8250DF);
Color get ghDraft => AppColors.muted;

/// The open / closed / merged icon GitHub shows next to an issue or PR.
Widget issueStateIcon(GhIssue i, {double size = 20}) {
  if (i.isPullRequest) {
    if (i.isMerged) return Icon(Icons.merge, color: ghMerged, size: size);
    if (!i.isOpen) {
      return Icon(Icons.call_split, color: ghClosed, size: size);
    }
    return Icon(Icons.call_split,
        color: i.isDraft ? ghDraft : ghOpen, size: size);
  }
  return i.isOpen
      ? Icon(Icons.radio_button_checked, color: ghOpen, size: size)
      : Icon(Icons.check_circle_outline, color: ghMerged, size: size);
}

/// Opens a GitHub user's or organization's profile page.
void openProfile(BuildContext context, String login) {
  if (login.isEmpty || login == 'ghost' || login == '?') return;
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ProfileScreen(login: login)),
  );
}

/// Round avatar with a person icon until the image loads. With a [login]
/// it opens that profile when tapped.
class Avatar extends StatelessWidget {
  const Avatar(this.url, {super.key, this.size = 20, this.login});

  final String url;
  final double size;
  final String? login;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.surfaceAlt,
      foregroundImage: url.isEmpty ? null : NetworkImage(url),
      child: Icon(Icons.person, size: size * 0.7, color: AppColors.faint),
    );
    if (login == null || login!.isEmpty) return avatar;
    return GestureDetector(
      onTap: () => openProfile(context, login!),
      child: avatar,
    );
  }
}

/// A username that opens the profile when tapped.
class UserName extends StatelessWidget {
  const UserName(this.login, {super.key, this.style});

  final String login;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openProfile(context, login),
      child: Text(login,
          style: style ??
              TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
    );
  }
}

/// [UserName] inside a Text.rich.
InlineSpan userSpan(String login, {TextStyle? style}) => WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: UserName(login, style: style),
    );

/// A colored issue label, like GitHub's.
class LabelChip extends StatelessWidget {
  const LabelChip(this.label, {super.key});

  final GhLabel label;

  @override
  Widget build(BuildContext context) {
    final c = Color(int.tryParse('FF${label.color}', radix: 16) ?? 0xFF888888);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(AppColors.isDark ? 0.18 : 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.6)),
      ),
      child: Text(label.name,
          style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.isDark
                  ? Color.lerp(c, Colors.white, 0.45)
                  : Color.lerp(c, Colors.black, 0.45))),
    );
  }
}

/// Small rounded outline badge ("Default", "Draft" ...).
Widget outlineBadge(String text, {Color? color}) {
  final c = color ?? AppColors.muted;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: c.withOpacity(0.6)),
    ),
    child: Text(text, style: TextStyle(color: c, fontSize: 11)),
  );
}

/// Centered loading / error / empty states for the tabs.
Widget tabMessage({String? error, String? empty, VoidCallback? onRetry}) {
  if (error == null && empty == null) {
    return const Center(child: CircularProgressIndicator());
  }
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(error ?? empty!,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: error != null ? AppColors.danger : AppColors.muted)),
        if (error != null && onRetry != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ]),
    ),
  );
}
