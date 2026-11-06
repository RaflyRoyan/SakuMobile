import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../app.dart';
import '../state/app_scope.dart';
import '../theme/app_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';

/// Login, or "Setup Admin" when the server has no users yet.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nama = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  bool? _perluSetup;
  String? _error;
  Map<String, List<String>> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cekStatus());
  }

  Future<void> _cekStatus() async {
    try {
      final perlu = await context.api.perluSetup();
      if (mounted) setState(() => _perluSetup = perlu);
    } catch (e) {
      if (mounted) setState(() => _perluSetup = false);
    }
  }

  @override
  void dispose() {
    _nama.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final setup = _perluSetup == true;
    if (_user.text.trim().isEmpty || _pass.text.isEmpty || (setup && _nama.text.trim().isEmpty)) {
      setState(() => _error = setup ? 'Isi nama, username, dan password.' : 'Isi username dan password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors = {};
    });
    try {
      final session = context.session;
      if (setup) {
        await session.setup(_user.text.trim().toLowerCase(), _pass.text, _nama.text.trim());
      } else {
        await session.login(_user.text.trim(), _pass.text);
      }
      if (mounted) Navigator.of(context).pushReplacementNamed(Routes.home);
    } on ApiException catch (e) {
      setState(() {
        _error = e.errors.isEmpty ? e.title : null;
        _fieldErrors = e.errors;
      });
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = _perluSetup == true;
    return Scaffold(
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Hero(setup: setup),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (setup) ...[
                          _Field(
                            label: 'Nama',
                            child: TextField(
                              controller: _nama,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(errorText: _fieldErrors['nama']?.first),
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                        _Field(
                          label: 'Username',
                          child: TextField(
                            controller: _user,
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            style: const TextStyle(fontSize: 15),
                            decoration: InputDecoration(errorText: _fieldErrors['username']?.first),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _Field(
                          label: 'Password',
                          child: TextField(
                            controller: _pass,
                            obscureText: _obscure,
                            autofillHints: [setup ? AutofillHints.newPassword : AutofillHints.password],
                            onSubmitted: (_) => _submit(),
                            style: const TextStyle(fontSize: 15),
                            decoration: InputDecoration(
                              errorText: _fieldErrors['password']?.first,
                              helperText: setup ? 'Minimal 8 karakter, berisi huruf dan angka.' : null,
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
                        SizedBox(
                          height: 54,
                          child: FilledButton(
                            onPressed: _busy || _perluSetup == null ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            child: _busy
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                                : Text(setup ? 'Buat admin & masuk' : 'Masuk'),
                          ),
                        ),
                        if (!setup) ...[
                          const SizedBox(height: 18),
                          const Text(
                            'Lupa password? Minta admin untuk reset.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (setup)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.dashed)),
                      child: const Text(
                        'Belum ada pengguna. Akun ini menjadi admin pertama dan bisa menambah pengguna lain.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.setup});

  final bool setup;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(28, 48 + MediaQuery.paddingOf(context).top, 28, 44),
      decoration: const BoxDecoration(color: AppColors.deep, borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset('assets/logo/saku_logo.png', width: 64, height: 64, semanticLabel: 'Logo Saku'),
          const SizedBox(height: 20),
          Text(setup ? 'Setup Admin' : 'Saku', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.7, color: Colors.white)),
          const SizedBox(height: 8),
          const Text('Catat uang masuk dan keluar,\ndari gajian ke gajian.', style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.mintText)),
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
