import 'package:flutter/material.dart';

import '../api/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// White rounded card with a hairline border.
class SakuCard extends StatelessWidget {
  const SakuCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// Puts a 1px divider between [children].
class DividedColumn extends StatelessWidget {
  const DividedColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.divider),
          children[i],
        ],
      ],
    );
  }
}

/// "Title ........ Link" row above a section.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          if (action != null) TextLink(action!, onTap: onAction),
        ],
      ),
    );
  }
}

class TextLink extends StatelessWidget {
  const TextLink(this.label, {super.key, this.onTap, this.fontSize = 13, this.color = AppColors.primary});

  final String label;
  final VoidCallback? onTap;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }
}

/// Uppercase small grey label.
class OverlineLabel extends StatelessWidget {
  const OverlineLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.bg = AppColors.background, this.fg = AppColors.inkSoft, this.fontSize = 11});

  final String label;
  final Color bg;
  final Color fg;
  final double fontSize;

  factory Pill.budget(StatusAnggaran s, String label) => switch (s) {
        StatusAnggaran.aman => Pill(label, bg: AppColors.inBg, fg: AppColors.primaryDark),
        StatusAnggaran.hampir => Pill(label, bg: AppColors.warnBg, fg: AppColors.warnText),
        StatusAnggaran.lewat => Pill(label, bg: AppColors.outBg, fg: AppColors.outText),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

Color budgetColor(StatusAnggaran s) => switch (s) {
      StatusAnggaran.aman => AppColors.primary,
      StatusAnggaran.hampir => AppColors.warn,
      StatusAnggaran.lewat => AppColors.out,
    };

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, required this.color, this.height = 6});

  /// 0..1 (clamped).
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: value.clamp(0, 1),
          color: color,
          backgroundColor: AppColors.track,
        ),
      ),
    );
  }
}

/// 40x40 rounded tile with an icon or initials.
class IconTile extends StatelessWidget {
  const IconTile({super.key, this.icon, this.text, required this.bg, required this.fg, this.size = 40, this.radius = 12});

  final IconData? icon;
  final String? text;
  final Color bg;
  final Color fg;
  final double size;
  final double radius;

  factory IconTile.forTx(TipeTransaksi type, String initials) => switch (type) {
        TipeTransaksi.keluar => IconTile(text: initials, bg: AppColors.outBg, fg: AppColors.out),
        TipeTransaksi.masuk => IconTile(text: initials, bg: AppColors.inBg, fg: AppColors.primary),
        TipeTransaksi.transfer => IconTile(text: initials, bg: AppColors.transferBg, fg: AppColors.transfer),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius)),
      child: icon != null
          ? Icon(icon, size: 20, color: fg)
          : Text(text ?? '', style: TextStyle(fontSize: size < 38 ? 11 : 12, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

Color txColor(TipeTransaksi t) => switch (t) {
      TipeTransaksi.keluar => AppColors.out,
      TipeTransaksi.masuk => AppColors.primary,
      TipeTransaksi.transfer => AppColors.transfer,
    };

/// Grey segmented control (Keluar / Masuk / Transfer).
class SegmentedTabs<T> extends StatelessWidget {
  const SegmentedTabs({super.key, required this.values, required this.selected, required this.labelOf, this.onChanged});

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (final v in values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _Segment(
                  label: labelOf(v),
                  on: v == selected,
                  onTap: onChanged == null ? null : () => onChanged!(v),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.on, this.onTap});

  final String label;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: on,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: on ? const [BoxShadow(color: Color(0x1F000000), blurRadius: 3, offset: Offset(0, 1))] : null,
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: on ? AppColors.ink : AppColors.inkSoft),
          ),
        ),
      ),
    );
  }
}

/// Coloured info/warning box with leading icon.
class InfoNote extends StatelessWidget {
  const InfoNote({super.key, required this.icon, required this.bg, required this.fg, required this.child, this.borderColor});

  final IconData icon;
  final Color bg;
  final Color fg;
  final Color? borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 18, color: fg)),
          const SizedBox(width: 10),
          Expanded(
            child: DefaultTextStyle.merge(
              style: TextStyle(fontSize: 13, height: 1.45, color: fg),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, this.onPressed, this.height = 54, this.color = AppColors.primary});

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed ?? () {},
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}

class OutlineBtn extends StatelessWidget {
  const OutlineBtn(this.label, {super.key, this.onPressed, this.height = 40, this.color = AppColors.ink, this.borderColor = AppColors.borderStrong, this.radius = 12, this.fontSize = 13});

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final Color color;
  final Color borderColor;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed ?? () {},
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          backgroundColor: AppColors.surface,
          side: BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Centered-title header used by pushed (non-tab) screens.
class SubPageHeader extends StatelessWidget {
  const SubPageHeader({super.key, required this.title, this.leadingIcon = Icons.chevron_left_rounded, this.leadingLabel = 'Kembali', this.trailing});

  final String title;
  final IconData leadingIcon;
  final String leadingLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: leadingLabel,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(leadingIcon, size: 26, color: AppColors.ink),
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          ),
          Expanded(
            child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          SizedBox(width: 44, height: 44, child: trailing),
        ],
      ),
    );
  }
}

/// Big amount display: "Rp 25.000".
class AmountDisplay extends StatelessWidget {
  const AmountDisplay({super.key, required this.amount, required this.color});

  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        const TextSpan(text: 'Rp  ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.muted)),
        TextSpan(text: amount, style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: color)),
      ]),
      textAlign: TextAlign.center,
      style: const TextStyle(fontFeatures: AppTheme.tabular),
    );
  }
}

/// Key/value row inside a form-like card (Tanggal, Kategori, ...).
class FieldRow extends StatelessWidget {
  const FieldRow({super.key, required this.label, required this.value, this.trailing, this.onTap, this.valueWeight = FontWeight.w600});

  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final FontWeight valueWeight;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              SizedBox(width: 96, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted))),
              const SizedBox(width: 12),
              Expanded(child: Text(value, style: TextStyle(fontSize: 14, fontWeight: valueWeight))),
              if (trailing != null) ...[const SizedBox(width: 8), Flexible(child: trailing!)],
            ],
          ),
        ),
      ),
    );
  }
}

/// Grabber + rounded top container for modal bottom sheets.
Future<T?> showSakuSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    barrierColor: AppColors.scrim,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 28 + MediaQuery.viewInsetsOf(ctx).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 14),
          builder(ctx),
        ],
      ),
    ),
  );
}

/// Primary button that shows a spinner while [busy].
class BusyButton extends StatelessWidget {
  const BusyButton({super.key, required this.label, required this.busy, required this.onPressed, this.height = 54, this.color = AppColors.primary});

  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : Text(label),
      ),
    );
  }
}
