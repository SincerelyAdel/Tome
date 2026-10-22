import 'package:flutter/material.dart';
import '../services/prefs_service.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _claudeCtrl = TextEditingController();
  final _github1Ctrl = TextEditingController();
  final _github2Ctrl = TextEditingController();
  bool _claudeVisible = false;
  bool _github1Visible = false;
  bool _github2Visible = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final claude = await PrefsService.getClaudeKey();
    final github1 = await PrefsService.getGithubToken();
    final github2 = await PrefsService.getGithubToken2();
    if (!mounted) return;
    setState(() {
      _claudeCtrl.text = claude ?? '';
      _github1Ctrl.text = github1 ?? '';
      _github2Ctrl.text = github2 ?? '';
    });
  }

  Future<void> _save() async {
    await PrefsService.setClaudeKey(_claudeCtrl.text.trim());
    await PrefsService.setGithubToken(_github1Ctrl.text.trim());
    await PrefsService.setGithubToken2(_github2Ctrl.text.trim());
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: AppColors.text)),
        iconTheme: IconThemeData(color: AppColors.text),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Claude API Key'),
            const SizedBox(height: 8),
            _buildKeyField(
              controller: _claudeCtrl,
              hint: 'sk-ant-api03-...',
              visible: _claudeVisible,
              onToggle: () =>
                  setState(() => _claudeVisible = !_claudeVisible),
            ),
            const SizedBox(height: 8),
            _hint('Needed for the Explain button in the file viewer.'),
            const SizedBox(height: 28),
            _sectionTitle('GitHub Account 1'),
            const SizedBox(height: 8),
            _buildKeyField(
              controller: _github1Ctrl,
              hint: 'github_pat_... (optional for public repos)',
              visible: _github1Visible,
              onToggle: () =>
                  setState(() => _github1Visible = !_github1Visible),
            ),
            const SizedBox(height: 8),
            _hint('Personal access token. Needed for private repos, '
                'Actions artifacts and higher rate limits.'),
            const SizedBox(height: 28),
            _sectionTitle('GitHub Account 2'),
            const SizedBox(height: 8),
            _buildKeyField(
              controller: _github2Ctrl,
              hint: 'github_pat_...',
              visible: _github2Visible,
              onToggle: () =>
                  setState(() => _github2Visible = !_github2Visible),
            ),
            const SizedBox(height: 8),
            _hint('Token for your second account. On the home screen, '
                'swipe left or right to switch between accounts.'),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  _saved ? '✓ Saved' : 'Save',
                  style: TextStyle(
                      color: AppColors.onAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 40),
            _sectionTitle('Recent Repos'),
            const SizedBox(height: 8),
            FutureBuilder<List<String>>(
              future: PrefsService.getRecentRepos(),
              builder: (context, snap) {
                if (!snap.hasData || snap.data!.isEmpty) {
                  return _hint('No recent repos.');
                }
                return Column(
                  children: snap.data!
                      .map((r) => ListTile(
                            title: Text(r,
                                style: TextStyle(
                                    color: AppColors.accent,
                                    fontFamily: 'monospace')),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                await PrefsService.clearRecentRepos();
                setState(() {});
              },
              child: Text('Clear recent repos',
                  style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: TextStyle(
          color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold));

  Widget _hint(String text) =>
      Text(text, style: TextStyle(color: AppColors.muted, fontSize: 13));

  Widget _buildKeyField({
    required TextEditingController controller,
    required String hint,
    required bool visible,
    required VoidCallback onToggle,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color),
        );
    return TextField(
      controller: controller,
      obscureText: !visible,
      autocorrect: false,
      style: TextStyle(
          color: AppColors.text, fontFamily: 'monospace', fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.faint),
        filled: true,
        fillColor: AppColors.surface,
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.accent),
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility_off : Icons.visibility,
              color: AppColors.muted),
          onPressed: onToggle,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _claudeCtrl.dispose();
    _github1Ctrl.dispose();
    _github2Ctrl.dispose();
    super.dispose();
  }
}
