import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Sends a downloaded file to another device through Android's share sheet
/// (Quick Share, Bluetooth, chat apps). The wording follows the device the
/// app runs on: a tablet sends to the phone, a phone sends to the tablet.
class ShareService {
  ShareService._();

  static const _channel = MethodChannel('repoviewer/share');

  /// Android's own rule: 600dp or more on the short side is a tablet.
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  static String sendLabel(BuildContext context) =>
      isTablet(context) ? 'Send to phone' : 'Send to tablet';

  static Future<void> send(BuildContext context, File file) {
    final name = file.uri.pathSegments.last;
    final apk = name.toLowerCase().endsWith('.apk');
    return _channel.invokeMethod('shareFile', {
      'path': file.path,
      'mime': apk ? 'application/vnd.android.package-archive' : '*/*',
      'title': '${sendLabel(context)}: $name',
    });
  }
}
