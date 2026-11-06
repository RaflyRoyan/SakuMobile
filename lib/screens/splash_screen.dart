import 'package:flutter/material.dart';

import '../app.dart';
import '../state/app_scope.dart';
import '../theme/app_colors.dart';
import '../widgets/async_view.dart';

/// Resumes a stored session, then routes to home or login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      final ok = await context.session.restore();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(ok ? Routes.home : Routes.login);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deep,
      body: _error != null
          ? ColoredBox(color: AppColors.background, child: ErrorState(message: errorMessage(_error!), onRetry: _start))
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/logo/saku_logo.png', width: 88, height: 88, semanticLabel: 'Logo Saku'),
                  const SizedBox(height: 16),
                  const Text('Saku', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 24),
                  const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.mint)),
                ],
              ),
            ),
    );
  }
}
