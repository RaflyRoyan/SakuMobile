import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../state/app_scope.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import '../widgets/form_fields.dart';

/// Admin: list, add, edit, deactivate users and reset passwords.
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = AppScope.of(context).user;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          SubPageHeader(
            title: 'Kelola pengguna',
            trailing: IconButton(
              tooltip: 'Tambah pengguna',
              icon: const Icon(Icons.person_add_alt_rounded, color: AppColors.primary),
              onPressed: () => showSakuSheet<void>(context, builder: (_) => const _UserSheet()),
            ),
          ),
          Expanded(
            child: AsyncView<List<Pengguna>>(
              load: () => context.api.pengguna(),
              builder: (context, list, _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  SakuCard(
                    padding: EdgeInsets.zero,
                    child: DividedColumn(children: [
                      for (final u in list)
                        ListTile(
                          onTap: () => showSakuSheet<void>(context, builder: (_) => _UserSheet(existing: u, isSelf: u.id == me?.id)),
                          leading: CircleAvatar(
                            backgroundColor: u.aktif ? AppColors.deep : AppColors.track,
                            child: Text(u.inisial, style: TextStyle(color: u.aktif ? Colors.white : AppColors.muted, fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                          title: Text(u.nama, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '@${u.username}${u.lastLogin != null ? ' · login ${tglSedang(u.lastLogin!)}' : ''}',
                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                          trailing: !u.aktif
                              ? const Pill('Nonaktif')
                              : u.isAdmin
                                  ? const Pill('Admin', bg: AppColors.transferBg, fg: AppColors.transfer)
                                  : null,
                        ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _UserSheet extends StatefulWidget {
  const _UserSheet({this.existing, this.isSelf = false});

  final Pengguna? existing;
  final bool isSelf;

  @override
  State<_UserSheet> createState() => _UserSheetState();
}

class _UserSheetState extends State<_UserSheet> {
  late final _nama = TextEditingController(text: widget.existing?.nama ?? '');
  final _username = TextEditingController();
  final _password = TextEditingController();
  late String _peran = widget.existing?.peran ?? 'user';
  late bool _aktif = widget.existing?.aktif ?? true;
  bool _busy = false;
  Map<String, List<String>> _errors = {};
  String? _error;

  @override
  void dispose() {
    _nama.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() {
      _busy = true;
      _errors = {};
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      context.session.dataChanged();
      showToast(context, success);
      Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() {
        _errors = e.errors;
        _error = e.errors.isEmpty ? e.title : null;
      });
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.existing;
    final api = context.api;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(u == null ? 'Tambah pengguna' : 'Ubah ${u.nama}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      LabeledField(label: 'Nama', child: TextField(controller: _nama, textCapitalization: TextCapitalization.words, decoration: InputDecoration(errorText: _errors['nama']?.first))),
      if (u == null) ...[
        const SizedBox(height: 14),
        LabeledField(label: 'Username', child: TextField(controller: _username, autocorrect: false, decoration: InputDecoration(errorText: _errors['username']?.first))),
      ],
      const SizedBox(height: 14),
      LabeledField(
        label: u == null ? 'Password' : 'Reset password (opsional)',
        child: TextField(
          controller: _password,
          obscureText: true,
          decoration: InputDecoration(
            helperText: 'Minimal 8 karakter, berisi huruf dan angka.',
            errorText: (_errors['password'] ?? _errors['passwordBaru'])?.first,
          ),
        ),
      ),
      const SizedBox(height: 14),
      SegmentedTabs<String>(
        values: const ['user', 'admin'],
        selected: _peran,
        labelOf: (p) => p == 'admin' ? 'Admin' : 'Pengguna',
        onChanged: widget.isSelf ? null : (p) => setState(() => _peran = p),
      ),
      if (u != null && !widget.isSelf)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Aktif', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          value: _aktif,
          activeTrackColor: AppColors.primary,
          onChanged: (v) => setState(() => _aktif = v),
        ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        InfoNote(icon: Icons.error_outline_rounded, bg: AppColors.outBg, fg: AppColors.outText, child: Text(_error!)),
      ],
      const SizedBox(height: 16),
      BusyButton(
        label: 'Simpan',
        busy: _busy,
        height: 50,
        onPressed: () => u == null
            ? _run(() => api.tambahPengguna(username: _username.text.trim().toLowerCase(), password: _password.text, nama: _nama.text.trim(), peran: _peran), 'Pengguna ditambahkan.')
            : _run(() async {
                await api.ubahPengguna(u.id, nama: _nama.text.trim(), peran: _peran, aktif: _aktif);
                if (_password.text.isNotEmpty) await api.resetPassword(u.id, _password.text);
              }, 'Pengguna diperbarui.'),
      ),
    ]);
  }
}
