import '../app_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static const _claudeKey = 'claude_api_key';
  static const _githubKey = 'github_token';
  static const _github2Key = 'github_token_2';
  static const _activeAccountKey = 'active_account';
  static const _darkModeKey = 'dark_mode';
  static const _recentReposKey = 'recent_repos';
  static const _listOwnerKey = 'list_owner';

  static Future<String?> getClaudeKey() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_claudeKey);
  }

  static Future<void> setClaudeKey(String key) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_claudeKey, key);
  }

  static Future<String?> getGithubToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_githubKey);
  }

  static Future<void> setGithubToken(String token) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_githubKey, token);
  }

  /// Token for the second GitHub account (swipe on the home screen).
  static Future<String?> getGithubToken2() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_github2Key);
  }

  static Future<void> setGithubToken2(String token) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_github2Key, token);
  }

  /// Which account page the home screen was last on (0 or 1).
  static Future<int> getActiveAccount() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_activeAccountKey) ?? 0;
  }

  static Future<void> setActiveAccount(int index) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_activeAccountKey, index);
  }

  /// The repo ("owner/name") whose build-apk.yml workflow builds APKs
  /// for other repos on demand. Empty when not set up.
  static Future<String> getBuilderRepo() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('apk_builder_repo') ?? '';
  }

  static Future<void> setBuilderRepo(String repo) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('apk_builder_repo', repo.trim());
    builderRepo.value = repo.trim();
  }

  /// Where Build APK runs by default: "github" or "my-pc".
  static Future<String> getBuildRunner() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('apk_build_runner') ?? 'github';
  }

  static Future<void> setBuildRunner(String runner) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('apk_build_runner', runner);
  }

  static Future<bool> getDarkMode() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_darkModeKey) ?? true;
  }

  static Future<void> setDarkMode(bool dark) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_darkModeKey, dark);
  }

  static Future<List<String>> getRecentRepos() async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(_recentReposKey) ?? [];
  }

  static Future<void> addRecentRepo(String repo) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_recentReposKey) ?? [];
    list.remove(repo);
    list.insert(0, repo);
    if (list.length > 10) list.removeLast();
    await p.setStringList(_recentReposKey, list);
  }

  static Future<void> clearRecentRepos() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_recentReposKey);
  }

  /// Whose public repos to list on the home screen when there's no token.
  /// Empty until someone types a username: a fresh install shows a welcome.
  static Future<String> getListOwner() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_listOwnerKey) ?? '';
  }

  static Future<void> setListOwner(String owner) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_listOwnerKey, owner);
  }
}
