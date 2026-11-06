import 'package:flutter/material.dart';

import '../api/models.dart';
import '../theme/app_colors.dart';
import 'form_fields.dart';

/// Id the API uses for the implicit "Lainnya" parent group.
const kLainnya = 'LAINNYA';

String indukId(Kategori k) => k.kelompokId ?? kLainnya;

/// Parent groups that have at least one of [kategori], in the API's order
/// (`/kelompok-kategori` urutan, "Lainnya" last). Names come from the API.
List<({String id, String nama})> indukUntuk(List<Kategori> kategori, List<KelompokKategori> kelompok) {
  final pos = {for (final (i, g) in kelompok.indexed) g.id: i};
  final namaApi = {for (final g in kelompok) g.id: g.nama};
  final seen = <String, String>{};
  for (final k in kategori) {
    final id = indukId(k);
    seen.putIfAbsent(id, () => namaApi[id] ?? k.kelompokNama ?? namaApi[kLainnya] ?? id);
  }
  final list = [for (final e in seen.entries) (id: e.key, nama: e.value)];
  list.sort((a, b) {
    final r = (pos[a.id] ?? 1 << 30).compareTo(pos[b.id] ?? 1 << 30);
    return r != 0 ? r : a.nama.compareTo(b.nama);
  });
  return list;
}

/// Sheet-picker options grouped and ordered like the API.
List<PickOption<String>> kategoriPickOptions(List<Kategori> kategori, List<KelompokKategori> kelompok) {
  final induk = indukUntuk(kategori, kelompok);
  return [
    for (final g in induk)
      for (final k in kategori.where((k) => indukId(k) == g.id)) PickOption(k.id, k.nama, group: g.nama),
  ];
}

/// Two-step chip picker (kategori induk → sub kategori), same as the web form.
/// For income categories (no parent) it shows a single row of chips.
class KategoriBertingkat extends StatefulWidget {
  const KategoriBertingkat({super.key, required this.kategori, required this.kelompok, required this.value, required this.onChanged, required this.bertingkat, this.error, this.enabled = true});

  final List<Kategori> kategori;
  final List<KelompokKategori> kelompok;
  final String? value;
  final ValueChanged<String?> onChanged;

  /// true for expenses (grouped by parent), false for income.
  final bool bertingkat;
  final String? error;
  final bool enabled;

  @override
  State<KategoriBertingkat> createState() => _KategoriBertingkatState();
}

class _KategoriBertingkatState extends State<KategoriBertingkat> {
  String? _induk;

  @override
  void initState() {
    super.initState();
    _syncInduk();
  }

  @override
  void didUpdateWidget(KategoriBertingkat old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value || old.bertingkat != widget.bertingkat) _syncInduk();
  }

  void _syncInduk() {
    final k = widget.kategori.where((k) => k.id == widget.value).firstOrNull;
    if (k != null) _induk = indukId(k);
    if (widget.value == null && !widget.bertingkat) _induk = null;
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if (widget.bertingkat) {
      final induk = indukUntuk(widget.kategori, widget.kelompok);
      children.add(_Label('Kategori'));
      children.add(_Chips(
        options: [for (final g in induk) (g.id, g.nama)],
        value: _induk,
        enabled: widget.enabled,
        onTap: (id) {
          if (id == _induk) return;
          setState(() => _induk = id);
          final isi = widget.kategori.where((k) => indukId(k) == id).toList();
          widget.onChanged(isi.length == 1 ? isi.first.id : null);
        },
      ));
      if (_induk != null) {
        children.add(const SizedBox(height: 12));
        children.add(_Label('Sub kategori'));
        children.add(_Chips(
          options: [for (final k in widget.kategori.where((k) => indukId(k) == _induk)) (k.id, k.nama)],
          value: widget.value,
          enabled: widget.enabled,
          onTap: widget.onChanged,
        ));
      }
    } else {
      children.add(_Label('Kategori'));
      children.add(_Chips(options: [for (final k in widget.kategori) (k.id, k.nama)], value: widget.value, enabled: widget.enabled, onTap: widget.onChanged));
    }
    if (widget.kategori.isEmpty) {
      children.add(const Text('Belum ada kategori. Admin menambahkannya lewat versi web.', style: TextStyle(fontSize: 13, color: AppColors.muted)));
    }
    if (widget.error != null) {
      children.add(Padding(padding: const EdgeInsets.only(top: 6), child: Text(widget.error!, style: const TextStyle(fontSize: 12, color: AppColors.out))));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted)),
      );
}

class _Chips extends StatelessWidget {
  const _Chips({required this.options, required this.value, required this.onTap, required this.enabled});

  final List<(String, String)> options;
  final String? value;
  final ValueChanged<String> onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (id, nama) in options)
          Semantics(
            selected: id == value,
            button: true,
            child: Material(
              color: id == value ? AppColors.deep : AppColors.surface,
              shape: StadiumBorder(side: BorderSide(color: id == value ? AppColors.deep : AppColors.borderStrong)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: enabled ? () => onTap(id) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Text(nama, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: id == value ? Colors.white : AppColors.ink)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
