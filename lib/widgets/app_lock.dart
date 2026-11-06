import 'package:flutter/material.dart';

import '../services/platform_services.dart';
import '../state/app_scope.dart';
import '../theme/app_colors.dart';

/// Covers the app with a lock screen when "Kunci aplikasi" is on: at cold
/// start (resumed session) and after the app was in the background for
/// [jeda]. Unlocks with the device's biometrics / screen-lock PIN.
class AppLock extends StatefulWidget {
  const AppLock({super.key, required this.session, required this.onLogout, required this.child, this.jeda = const Duration(seconds: 30)});

  final SessionController session;
  final VoidCallback onLogout;
  final Widget child;
  final Duration jeda;

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  late bool _locked = widget.session.services.prefs.kunciAktif;
  bool _hadUser = false;
  bool _busy = false;
  bool _autoTried = false;
  bool _hidden = false;
  DateTime? _hiddenAt;
  String? _error;

  SessionController get _s => widget.session;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _s.addListener(_onSession);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _s.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    final hasUser = _s.user != null;
    if (hasUser && !_hadUser && _s.viaPassword) {
      // Just typed the password: no need to ask again.
      _locked = false;
    }
    _hadUser = hasUser;
    if (mounted) setState(() {});
    _maybeAutoPrompt();
  }

  bool get _showing => _locked && _s.user != null && _s.services.prefs.kunciAktif;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_busy) return;
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _hiddenAt ??= DateTime.now();
        if (!_hidden && _s.services.prefs.kunciAktif) setState(() => _hidden = true);
      case AppLifecycleState.resumed:
        final at = _hiddenAt;
        _hiddenAt = null;
        if (at != null && _s.services.prefs.kunciAktif && DateTime.now().difference(at) >= widget.jeda) {
          _locked = true;
          _autoTried = false;
        }
        setState(() => _hidden = false);
        _maybeAutoPrompt();
        if (at != null) _s.syncPengingat();
      default:
        break;
    }
  }

  void _maybeAutoPrompt() {
    if (!_showing || _autoTried || _busy) return;
    _autoTried = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = _s.services.auth;
    try {
      if (!await auth.didukung()) {
        // Screen lock removed from the phone: nothing to verify against.
        await _s.services.prefs.setKunciAktif(false);
        _locked = false;
        return;
      }
      if (await auth.autentikasi('Buka Saku')) _locked = false;
    } on DeviceAuthException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showLock = _showing;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(excluding: showLock, child: TickerMode(enabled: !showLock, child: widget.child)),
        if (showLock)
          _LockScreen(busy: _busy, error: _error, onUnlock: _unlock, onLogout: widget.onLogout)
        else if (_hidden)
          // Hides balances from the recent-apps preview.
          const ColoredBox(color: AppColors.deep),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.busy, required this.error, required this.onUnlock, required this.onLogout});

  final bool busy;
  final String? error;
  final VoidCallback onUnlock;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.deep,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const Spacer(),
              Image.asset('assets/logo/saku_logo.png', width: 72, height: 72, semanticLabel: 'Logo Saku'),
              const SizedBox(height: 20),
              const Text('Saku terkunci', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 8),
              const Text(
                'Buka dengan sidik jari, wajah, atau PIN HP.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.mintText),
              ),
              if (error != null) ...[
                const SizedBox(height: 16),
                Text(error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.peachBright)),
              ],
              const Spacer(),
              SizedBox(
                height: 54,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : onUnlock,
                  icon: busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.deep))
                      : const Icon(Icons.fingerprint_rounded),
                  label: const Text('Buka kunci'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.mint,
                    foregroundColor: AppColors.deep,
                    disabledBackgroundColor: AppColors.mint.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: busy ? null : onLogout,
                style: TextButton.styleFrom(foregroundColor: AppColors.mintText),
                child: const Text('Keluar dan login dengan password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
