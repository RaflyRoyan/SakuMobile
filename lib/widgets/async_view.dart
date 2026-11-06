import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../state/app_scope.dart';
import '../theme/app_colors.dart';
import 'common.dart';

/// Loads data with [load], shows a spinner / error with retry, supports
/// pull-to-refresh, and reloads whenever [SessionController.dataChanged] fires.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;
  int _version = -1;
  int _token = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final v = AppScope.of(context).dataVersion;
    if (v != _version) {
      _version = v;
      _reload();
    }
  }

  Future<void> _reload() async {
    final my = ++_token;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await widget.load();
      if (!mounted || my != _token) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || my != _token) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null && _loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_data == null && _error != null) {
      return ErrorState(message: errorMessage(_error!), onRetry: _reload);
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _reload,
      child: widget.builder(context, _data as T, _reload),
    );
  }
}

String errorMessage(Object e) => e is ApiException ? e.message : 'Terjadi kesalahan. Coba lagi.';

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.inkSoft)),
            const SizedBox(height: 16),
            OutlineBtn('Coba lagi', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action, this.onAction});

  final IconData icon;
  final String title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SakuCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          IconTile(icon: icon, bg: AppColors.inBg, fg: AppColors.primary, size: 48, radius: 14),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.45)),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            PrimaryButton(action!, height: 46, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// Snackbar helpers.
void showToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? AppColors.outText : AppColors.deep,
    ));
}

/// Shows server `peringatan[]` (negative balance, budget exceeded) after a save.
Future<void> showPeringatan(BuildContext context, List<String> peringatan) async {
  if (peringatan.isEmpty) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Tersimpan, dengan peringatan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in peringatan)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InfoNote(icon: Icons.warning_amber_rounded, bg: AppColors.warnBg, fg: AppColors.warnText, child: Text(p)),
            ),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Oke'))],
    ),
  );
}

/// Runs [action], showing a toast on error. Returns true on success.
Future<bool> runAction(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (context.mounted) {
      context.session.dataChanged();
      if (success != null) showToast(context, success);
    }
    return true;
  } catch (e) {
    if (context.mounted) showToast(context, errorMessage(e), error: true);
    return false;
  }
}
