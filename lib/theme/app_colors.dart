import 'package:flutter/material.dart';

/// Palette taken from the Saku design mockup.
abstract final class AppColors {
  // Base
  static const background = Color(0xFFF2F4F1);
  static const surface = Colors.white;
  static const ink = Color(0xFF15201B);
  static const inkSoft = Color(0xFF3E4C45);
  static const muted = Color(0xFF5A6A62);
  static const border = Color(0xFFE3E7E2);
  static const borderStrong = Color(0xFFCBD3CC);
  static const divider = Color(0xFFEEF1ED);
  static const track = Color(0xFFE6EAE5);
  static const dashed = Color(0xFFA9B6AE);
  static const hover = Color(0xFFF8FAF7);

  // Brand
  static const primary = Color(0xFF0E6B47);
  static const primaryDark = Color(0xFF0A5236);
  static const deep = Color(0xFF0B3B2A);
  static const mint = Color(0xFFC8F0D8);
  static const mintText = Color(0xFFB9D4C6);
  static const mintBright = Color(0xFF9BE7BC);
  static const peachBright = Color(0xFFFFC2A8);

  // Semantic: out / in / transfer
  static const out = Color(0xFFB1431A);
  static const outBg = Color(0xFFFBE6DC);
  static const outText = Color(0xFF8A3313);
  static const inBg = Color(0xFFDFF3EA);
  static const transfer = Color(0xFF1D4E89);
  static const transferBg = Color(0xFFE3EEF9);
  static const infoText = Color(0xFF173F6E);

  // Warning
  static const warn = Color(0xFFC98A00);
  static const warnBg = Color(0xFFFFF1CF);
  static const warnText = Color(0xFF5E3F00);
  static const warnStrong = Color(0xFF7A5200);

  // Overlay
  static const scrim = Color(0x730B1410);
}
