import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../app.dart';
import '../services/platform_services.dart';
import '../state/app_scope.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import '../widgets/form_fields.dart';
import '../widgets/kategori_picker.dart';
import '../widgets/saku_rows.dart';

class _SettingsData {
  _SettingsData(this.pilihan, this.berulang, this.periode, this.kategori, this.kelompok);

  final PilihanAkun pilihan;
  final List<Berulang> berulang;
  final List<Periode> periode;
  final List<Kategori> kategori;
  final List<KelompokKategori> kelompok;
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<_SettingsData> _load(BuildContext context) async {
    final api = context.api;
    final r = await Future.wait([api.pilihanAkun(), api.berulang(), api.periode(), api.kategori(), api.kelompokKategori()]);
    return _SettingsData(r[0] as PilihanAkun, r[1] as List<Berulang>, r[2] as List<Periode>, r[3] as List<Kategori>, r[4] as List<KelompokKategori>);
  }

  void _push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    final nav = Navigator.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SubPageHeader(title: 'Pengaturan'),
            Expanded(
              child: AsyncView<_SettingsData>(
                load: () => _load(context),
                builder: (context, d, _) {
                  final dipilih = d.pilihan.akun.where((a) => a.dipilih).toList();
                  final lain = d.pilihan.akun.where((a) => !a.dipilih).toList();
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      SakuCard(
                        child: Row(children: [
                          Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(color: AppColors.deep, shape: BoxShape.circle),
                            child: Text(user?.inisial ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(user?.nama ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text('@${user?.username ?? ''} · ${user?.isAdmin == true ? 'Admin' : 'Pengguna'}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                            ]),
                          ),
                          OutlineBtn('Ubah', height: 36, radius: 10, onPressed: () => showSakuSheet<void>(context, builder: (_) => const _ProfilSheet())),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      const OverlineLabel('Akun saya'),
                      SakuCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Akun yang tampil di transaksi, urut sesuai pilihanmu.', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                          const SizedBox(height: 10),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            for (final (i, a) in dipilih.indexed) _AccChip('${i + 1} · ${a.nama}'),
                            for (final a in lain) _AccChip('${a.nama} (tidak dipilih)', dashed: true),
                          ]),
                          const SizedBox(height: 6),
                          TextLink('Atur akun & urutan', onTap: () => _push(context, AccountPickerScreen(pilihan: d.pilihan))),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      const OverlineLabel('Keuangan'),
                      SakuCard(
                        padding: EdgeInsets.zero,
                        child: DividedColumn(children: [
                          _MenuItem(icon: Icons.category_outlined, label: 'Kategori & sub kategori', value: '${d.kategori.length}', onTap: () => _push(context, CategoryListScreen(kategori: d.kategori, kelompok: d.kelompok))),
                          _MenuItem(icon: Icons.repeat_rounded, label: 'Langganan', value: '${d.berulang.where((b) => b.aktif).length} aktif', onTap: () => nav.pushNamed(Routes.subscriptions)),
                          _MenuItem(icon: Icons.history_rounded, label: 'Riwayat periode', value: '${d.periode.length}', onTap: () => _push(context, PeriodListScreen(periode: d.periode))),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      const OverlineLabel('Lainnya'),
                      SakuCard(
                        padding: EdgeInsets.zero,
                        child: DividedColumn(children: [
                          _MenuItem(icon: Icons.call_split_rounded, label: 'Split Bill', onTap: () => nav.pushNamed(Routes.split)),
                          _MenuItem(icon: Icons.qr_code_2_rounded, label: 'Terima QRIS', onTap: () => nav.pushNamed(Routes.terimaQris)),
                          _MenuItem(icon: Icons.storefront_outlined, label: 'QRIS untuk tagihan', onTap: () => nav.pushNamed(Routes.qrisSettings)),
                        ]),
                      ),
                      if (user?.isAdmin == true) ...[
                        const SizedBox(height: 20),
                        const OverlineLabel('Admin'),
                        SakuCard(
                          padding: EdgeInsets.zero,
                          child: DividedColumn(children: [
                            _MenuItem(icon: Icons.group_outlined, label: 'Kelola pengguna', onTap: () => nav.pushNamed(Routes.users)),
                            _MenuItem(
                              icon: Icons.account_balance_outlined,
                              label: 'Master akun & kategori',
                              value: 'versi web',
                              onTap: () => showToast(context, 'Master akun, kategori, dan kelompok dikelola lewat versi web Saku.'),
                            ),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 20),
                      const OverlineLabel('Perangkat ini'),
                      const _DeviceSettings(),
                      const SizedBox(height: 20),
                      const OverlineLabel('Keamanan'),
                      SakuCard(
                        padding: EdgeInsets.zero,
                        child: DividedColumn(children: [
                          _MenuItem(icon: Icons.key_outlined, label: 'Ganti password', onTap: () => showSakuSheet<void>(context, builder: (_) => const _PasswordSheet())),
                          _MenuItem(
                            icon: Icons.logout_rounded,
                            label: 'Keluar',
                            danger: true,
                            onTap: () async {
                              await context.session.logout();
                              if (context.mounted) nav.pushNamedAndRemoveUntil(Routes.login, (_) => false);
                            },
                          ),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      const Text('Saku · data tersimpan di Google Sheets', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilSheet extends StatefulWidget {
  const _ProfilSheet();

  @override
  State<_ProfilSheet> createState() => _ProfilSheetState();
}

class _ProfilSheetState extends State<_ProfilSheet> {
  late final _nama = TextEditingController(text: context.session.user?.nama ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nama.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final u = await context.api.ubahProfil(_nama.text.trim());
      if (!mounted) return;
      context.session.setUser(u);
      showToast(context, 'Nama diperbarui.');
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Ubah nama', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      LabeledField(
        label: 'Nama',
        child: TextField(controller: _nama, autofocus: true, textCapitalization: TextCapitalization.words, decoration: InputDecoration(errorText: _error)),
      ),
      const SizedBox(height: 16),
      BusyButton(label: 'Simpan', busy: _busy, height: 50, onPressed: _save),
    ]);
  }
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _lama = TextEditingController();
  final _baru = TextEditingController();
  bool _busy = false;
  Map<String, List<String>> _errors = {};
  String? _error;

  @override
  void dispose() {
    _lama.dispose();
    _baru.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _errors = {};
      _error = null;
    });
    try {
      await context.api.gantiPassword(_lama.text, _baru.text);
      if (!mounted) return;
      showToast(context, 'Password diganti. Sesi di perangkat lain otomatis keluar.');
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Ganti password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      LabeledField(
        label: 'Password lama',
        child: TextField(controller: _lama, obscureText: true, autofillHints: const [AutofillHints.password], decoration: InputDecoration(errorText: _errors['passwordLama']?.first)),
      ),
      const SizedBox(height: 14),
      LabeledField(
        label: 'Password baru',
        child: TextField(
          controller: _baru,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(helperText: 'Minimal 8 karakter, berisi huruf dan angka.', errorText: _errors['passwordBaru']?.first),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        InfoNote(icon: Icons.error_outline_rounded, bg: AppColors.outBg, fg: AppColors.outText, child: Text(_error!)),
      ],
      const SizedBox(height: 16),
      BusyButton(label: 'Ganti password', busy: _busy, height: 50, onPressed: _save),
    ]);
  }
}

/// Choose which master accounts the user uses, and their order.
class AccountPickerScreen extends StatefulWidget {
  const AccountPickerScreen({super.key, required this.pilihan});

  final PilihanAkun pilihan;

  @override
  State<AccountPickerScreen> createState() => _AccountPickerScreenState();
}

class _AccountPickerScreenState extends State<AccountPickerScreen> {
  late final List<Akun> _items = [...widget.pilihan.akun];
  late final Set<String> _on = {for (final a in widget.pilihan.akun) if (a.dipilih) a.id};
  bool _busy = false;

  Future<void> _save() async {
    final ids = [for (final a in _items) if (_on.contains(a.id)) a.id];
    if (ids.isEmpty) {
      showToast(context, 'Pilih minimal 1 akun.', error: true);
      return;
    }
    setState(() => _busy = true);
    final ok = await runAction(context, () => context.api.simpanPilihanAkun(ids), success: 'Pilihan akun tersimpan.');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const SubPageHeader(title: 'Akun saya'),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text('Centang akun yang kamu pakai, tahan dan geser untuk mengatur urutan. Akun yang masih bersaldo tidak bisa dilepas.',
                style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5)),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              itemCount: _items.length,
              onReorderItem: (from, to) => setState(() => _items.insert(to, _items.removeAt(from))),
              itemBuilder: (context, i) {
                final a = _items[i];
                return Padding(
                  key: ValueKey(a.id),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SakuCard(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(children: [
                      Checkbox(
                        value: _on.contains(a.id),
                        activeColor: AppColors.primary,
                        onChanged: (v) => setState(() => v == true ? _on.add(a.id) : _on.remove(a.id)),
                      ),
                      AkunBadge(a.nama),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.nama, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text('${jenisAkunLabel(a.jenis)}${a.saldo != null ? ' · ${rupiah(a.saldo!)}' : ''}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        ]),
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_handle_rounded, color: AppColors.muted)),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), child: BusyButton(label: 'Simpan', busy: _busy, onPressed: _save)),
        ]),
      ),
    );
  }
}

class PeriodListScreen extends StatelessWidget {
  const PeriodListScreen({super.key, required this.periode});

  final List<Periode> periode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const SubPageHeader(title: 'Riwayat periode'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                if (periode.isEmpty) const Text('Belum ada periode.', style: TextStyle(color: AppColors.muted)),
                if (periode.isNotEmpty)
                  SakuCard(
                    padding: EdgeInsets.zero,
                    child: DividedColumn(children: [
                      for (final p in periode)
                        ListTile(
                          title: Text(p.nama, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text('${tglSedang(p.tanggalMulai)} – ${p.tanggalSelesai == null ? 'sekarang' : tglSedang(p.tanggalSelesai!)}',
                              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          trailing: p.aktif ? const Pill('Aktif', bg: AppColors.inBg, fg: AppColors.primaryDark) : const Pill('Ditutup'),
                        ),
                    ]),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class CategoryListScreen extends StatelessWidget {
  const CategoryListScreen({super.key, required this.kategori, required this.kelompok});

  final List<Kategori> kategori;
  final List<KelompokKategori> kelompok;

  @override
  Widget build(BuildContext context) {
    final keluarList = kategori.where((k) => k.tipe == 'keluar').toList();
    final keluar = {
      for (final g in indukUntuk(keluarList, kelompok)) g.nama: keluarList.where((k) => indukId(k) == g.id).toList(),
    };
    final masuk = kategori.where((k) => k.tipe == 'masuk').toList();
    Widget group(String title, List<Kategori> items) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            OverlineLabel(title),
            SakuCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final k in items) _AccChip(k.kodeSistem != null ? '${k.nama} · sistem' : k.nama),
              ]),
            ),
          ]),
        );
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const SubPageHeader(title: 'Kategori'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                const Text('Kategori dipakai bersama semua pengguna. Admin menambah atau mengubahnya lewat versi web.',
                    style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5)),
                const SizedBox(height: 16),
                for (final e in keluar.entries) group('Pengeluaran · ${e.key}', e.value),
                if (masuk.isNotEmpty) group('Pemasukan', masuk),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _AccChip extends StatelessWidget {
  const _AccChip(this.label, {this.dashed = false});

  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: dashed ? AppColors.surface : AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: dashed ? Border.all(color: AppColors.dashed) : null,
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: dashed ? AppColors.muted : AppColors.ink)),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, this.value, this.danger = false, required this.onTap});

  final IconData icon;
  final String label;
  final String? value;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? AppColors.out : AppColors.ink;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            IconTile(icon: icon, bg: danger ? AppColors.outBg : AppColors.background, fg: danger ? AppColors.out : AppColors.primary, size: 34, radius: 10),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg))),
            if (value != null) Text(value!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            if (!danger) ...[const SizedBox(width: 6), const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.muted)],
          ]),
        ),
      ),
    );
  }
}

/// Per-device switches: subscription notifications and app lock.
class _DeviceSettings extends StatefulWidget {
  const _DeviceSettings();

  @override
  State<_DeviceSettings> createState() => _DeviceSettingsState();
}

class _DeviceSettingsState extends State<_DeviceSettings> {
  bool _busy = false;

  Future<void> _setNotif(bool on) async {
    final s = context.services;
    setState(() => _busy = true);
    try {
      if (on && !await s.pengingat.mintaIzin()) {
        if (mounted) showToast(context, 'Izin notifikasi ditolak. Aktifkan di pengaturan HP untuk Saku.');
        return;
      }
      await s.prefs.setNotifAktif(on);
      await s.prefs.setNotifSudahDiminta(true);
      if (!mounted) return;
      await context.session.syncPengingat();
      if (mounted) showToast(context, on ? 'Pengingat langganan aktif.' : 'Pengingat langganan dimatikan.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setKunci(bool on) async {
    final s = context.services;
    setState(() => _busy = true);
    try {
      if (on) {
        if (!await s.auth.didukung()) {
          if (mounted) showToast(context, 'Atur kunci layar (PIN, pola, atau sidik jari) di HP dulu.');
          return;
        }
        try {
          if (!await s.auth.autentikasi('Aktifkan kunci Saku')) return;
        } on DeviceAuthException catch (e) {
          if (mounted) showToast(context, e.message);
          return;
        }
      }
      await s.prefs.setKunciAktif(on);
      if (mounted) showToast(context, on ? 'Saku akan terkunci saat dibuka lagi.' : 'Kunci aplikasi dimatikan.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return SakuCard(
      padding: EdgeInsets.zero,
      child: DividedColumn(children: [
        if (s.pengingat.didukung)
          _SwitchItem(
            icon: Icons.notifications_active_outlined,
            label: 'Pengingat langganan',
            hint: 'Notifikasi pukul 08.00 sebelum dan saat jatuh tempo.',
            value: s.prefs.notifAktif,
            onChanged: _busy ? null : _setNotif,
          ),
        _SwitchItem(
          icon: Icons.fingerprint_rounded,
          label: 'Kunci aplikasi',
          hint: 'Minta sidik jari / PIN HP saat Saku dibuka.',
          value: s.prefs.kunciAktif,
          onChanged: _busy ? null : _setKunci,
        ),
      ]),
    );
  }
}

class _SwitchItem extends StatelessWidget {
  const _SwitchItem({required this.icon, required this.label, required this.hint, required this.value, required this.onChanged});

  final IconData icon;
  final String label;
  final String hint;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            IconTile(icon: icon, bg: AppColors.background, fg: AppColors.primary, size: 34, radius: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(hint, style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted)),
              ]),
            ),
            const SizedBox(width: 8),
            Switch(value: value, onChanged: onChanged, activeTrackColor: AppColors.primary),
          ]),
        ),
      ),
    );
  }
}
