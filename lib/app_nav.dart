import 'package:flutter/material.dart';

/// The app's navigator, so the fixed top header can open and close pages.
final navigatorKey = GlobalKey<NavigatorState>();

/// Bumped each time Settings closes, so screens can reload saved tokens.
final settingsChanged = ValueNotifier<int>(0);

/// Bumped when a repo is created or deleted, so repo lists reload.
final reposChanged = ValueNotifier<int>(0);

/// The APK builder repo ("owner/name", or empty). Its card is drawn in
/// gold and opening it goes straight to its Actions.
final builderRepo = ValueNotifier<String>('');

bool isBuilderRepo(String owner, String repo) =>
    builderRepo.value.isNotEmpty &&
    builderRepo.value.toLowerCase() == '$owner/$repo'.toLowerCase();
