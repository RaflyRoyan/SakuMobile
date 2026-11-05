import 'package:flutter/material.dart';

import '../app.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _submit() {
    // UI-only: accept any non-empty credentials until auth is wired.
    if (_user.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Username atau password salah.');
      return;
    }
    Navigator.of(context).pushReplacementNamed(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Hero(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Field(
                          label: 'Username',
                          child: TextField(
                            controller: _user,
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _Field(
                          label: 'Password',
                          child: TextField(
                            controller: _pass,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) => _submit(),
                            style: const TextStyle(fontSize: 15),
                            decoration: InputDecoration(
                              suffixIcon: IconButton(
                                tooltip: _obscure ? 'Tampilkan password' : 'Sembunyikan password',
                                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.muted),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 18),
                          InfoNote(
                            icon: Icons.error_outline_rounded,
                            bg: AppColors.outBg,
                            fg: AppColors.outText,
                            child: Text(_error!, style: const TextStyle(fontWeight: FontWeight.w500)),
                          ),
                        ],
                        const SizedBox(height: 24),
                        PrimaryButton('Masuk', onPressed: _submit),
                        const SizedBox(height: 18),
                        const Text(
                          'Lupa password? Minta admin untuk reset.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.dashed),
                    ),
                    child: const Text.rich(
                      TextSpan(children: [
                        TextSpan(text: 'Pertama kali? ', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                        TextSpan(text: 'Kalau belum ada pengguna, layar ini berubah jadi '),
                        TextSpan(text: 'Setup Admin', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                        TextSpan(text: ' (nama, username, password).'),
                      ]),
                      style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(28, 48 + MediaQuery.paddingOf(context).top, 28, 44),
      decoration: const BoxDecoration(
        color: AppColors.deep,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.account_balance_wallet_outlined, size: 30, color: AppColors.deep),
          ),
          const SizedBox(height: 20),
          const Text('Saku', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.7, color: Colors.white)),
          const SizedBox(height: 8),
          const Text(
            'Catat uang masuk dan keluar,\ndari gajian ke gajian.',
            style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.mintText),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
