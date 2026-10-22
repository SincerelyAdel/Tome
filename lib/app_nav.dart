import 'package:flutter/material.dart';

/// The app's navigator, so the fixed top header can open and close pages.
final navigatorKey = GlobalKey<NavigatorState>();

/// Bumped each time Settings closes, so screens can reload saved tokens.
final settingsChanged = ValueNotifier<int>(0);
