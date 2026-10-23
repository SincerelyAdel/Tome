import 'package:flutter/material.dart';
import '../services/github_service.dart';
import '../theme.dart';

/// Loads data once, shows a spinner meanwhile and a readable error with a
/// Retry button on failure, then builds [builder] with the data.
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(
      BuildContext context, T data, Future<void> Function() reload) builder;

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  T? _data;
  bool _done = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _error = null);
    try {
      final d = await widget.load();
      if (mounted) {
        setState(() {
          _data = d;
          _done = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.builder(context, _data as T, _reload);
    if (_error == null) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return errorPanel(_error!, onRetry: _reload);
  }
}

/// A friendly error box. [note] adds advice, such as which plan or token
/// scope a page needs.
Widget errorPanel(Object error, {VoidCallback? onRetry, String? note}) {
  final text = error is ApiException
      ? error.message
      : error.toString().replaceFirst('Exception: ', '');
  return Center(
    child: Container(
      constraints: const BoxConstraints(maxWidth: 560),
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.lock_outline, color: AppColors.muted, size: 30),
        const SizedBox(height: 10),
        Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.text, fontSize: 14, height: 1.45)),
        if (note != null) ...[
          const SizedBox(height: 8),
          Text(note,
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: AppColors.muted, fontSize: 13, height: 1.45)),
        ],
        if (onRetry != null) ...[
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ]),
    ),
  );
}

/// Asks before doing something that changes GitHub. Returns true on yes.
Future<bool> confirmAction(BuildContext context,
    {required String title,
    required String message,
    String action = 'Confirm',
    bool danger = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(title, style: TextStyle(color: AppColors.text)),
      content: Text(message,
          style: TextStyle(color: AppColors.muted, height: 1.45)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.muted))),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: danger ? AppColors.danger : AppColors.button,
              foregroundColor: danger ? Colors.white : AppColors.onButton),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Runs a change on GitHub and reports the result in a snackbar.
Future<bool> runAction(BuildContext context, Future<void> Function() action,
    {required String done}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    messenger.showSnackBar(SnackBar(content: Text(done)));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text(e is ApiException ? e.message : '$e'),
      duration: const Duration(seconds: 6),
    ));
    return false;
  }
}

/// A row of choice chips used to switch between sub-views.
Widget segmentChips(
    List<String> labels, int selected, ValueChanged<int> onSelect) {
  return SizedBox(
    height: 44,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(labels[i]),
              selected: i == selected,
              onSelected: (_) => onSelect(i),
              labelStyle: TextStyle(
                  color: i == selected ? AppColors.onButton : AppColors.text,
                  fontSize: 13),
              selectedColor: AppColors.button,
              backgroundColor: AppColors.surface,
              side: BorderSide(color: AppColors.border),
              showCheckmark: false,
            ),
          ),
      ],
    ),
  );
}

/// Bordered box holding rows separated by thin lines.
Widget rowsBox(List<Widget> rows) {
  return Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(10),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, color: AppColors.border),
          rows[i],
        ],
      ],
    ),
  );
}

/// A small filled pill ("Owner", "critical" ...).
Widget pill(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(AppColors.isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.55)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );

/// Muted centered text for empty lists.
Widget emptyNote(String text) => Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.45))),
    );
