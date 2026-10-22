import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static const _claudeKey = 'claude_api_key';
  static const _githubKey = 'github_token';
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
  static Future<String> getListOwner() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_listOwnerKey) ?? 'SincerelyAdel';
  }

  static Future<void> setListOwner(String owner) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_listOwnerKey, owner);
  }
}
