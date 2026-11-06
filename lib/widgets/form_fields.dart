import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../utils/format.dart';
import 'common.dart';

/// Formats digits with thousand separators while typing ("1500000" -> "1.500.000").
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final n = parseNominal(newValue.text);
    if (n == null) return const TextEditingValue();
    final text = thousands(n);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Label above a field.
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Text field for rupiah amounts.
class NominalField extends StatelessWidget {
  const NominalField({super.key, required this.controller, this.errorText, this.hint = '0', this.onChanged, this.autofocus = false, this.dense = false});

  final TextEditingController controller;
  final String? errorText;
  final String hint;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [ThousandsFormatter()],
      textAlign: dense ? TextAlign.right : TextAlign.start,
      onChanged: onChanged,
      style: TextStyle(fontSize: dense ? 14 : 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        errorText: errorText,
        isDense: dense,
        prefixText: dense ? null : 'Rp ',
        contentPadding: dense ? const EdgeInsets.symmetric(horizontal: 10, vertical: 10) : null,
      ),
    );
  }
}

/// Option for [pickOne].
class PickOption<T> {
  const PickOption(this.value, this.label, {this.subtitle, this.group});

  final T value;
  final String label;
  final String? subtitle;
  final String? group;
}

/// Bottom-sheet list picker. Returns the chosen value or null.
Future<T?> pickOne<T>(BuildContext context, {required String title, required List<PickOption<T>> options, T? selected}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    barrierColor: AppColors.scrim,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      final rows = <Widget>[];
      String? lastGroup;
      for (final o in options) {
        if (o.group != null && o.group != lastGroup) {
          lastGroup = o.group;
          rows.add(Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Text(o.group!.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5)),
          ));
        }
        final on = o.value == selected;
        rows.add(ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: Text(o.label, style: TextStyle(fontSize: 15, fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
          subtitle: o.subtitle == null ? null : Text(o.subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          trailing: on ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
          onTap: () => Navigator.pop(ctx, o.value),
        ));
      }
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(2)))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              if (options.isEmpty)
                const Padding(padding: EdgeInsets.all(20), child: Text('Tidak ada pilihan.', style: TextStyle(color: AppColors.muted))),
              Flexible(child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 12), children: rows)),
            ],
          ),
        ),
      );
    },
  );
}

/// Material date picker restricted to a sensible range.
Future<DateTime?> pickDate(BuildContext context, DateTime initial, {DateTime? first, DateTime? last}) {
  final today = todayWib();
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first ?? DateTime(today.year - 3),
    lastDate: last ?? today.add(const Duration(days: 31)),
    helpText: 'Pilih tanggal',
    cancelText: 'Batal',
    confirmText: 'Pilih',
  );
}

/// Read-only field that opens a picker, styled like the mockup's form rows.
class SelectRow extends StatelessWidget {
  const SelectRow({super.key, required this.label, required this.value, this.hint = 'Pilih', this.trailing, this.onTap, this.error});

  final String label;
  final String? value;
  final String hint;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldRow(
          label: label,
          value: value ?? hint,
          valueWeight: value == null ? FontWeight.w500 : FontWeight.w600,
          trailing: trailing ?? (onTap == null ? null : const Icon(Icons.expand_more_rounded, size: 20, color: AppColors.muted)),
          onTap: onTap,
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(124, 0, 16, 10),
            child: Text(error!, style: const TextStyle(fontSize: 12, color: AppColors.out)),
          ),
      ],
    );
  }
}
