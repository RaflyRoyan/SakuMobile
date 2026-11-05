/// Formats an integer with Indonesian thousand separators: 1234567 -> "1.234.567".
String thousands(int value) {
  final s = value.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return value < 0 ? '-${buf.toString()}' : buf.toString();
}

/// "Rp 1.234.567"
String rupiah(int value) => 'Rp ${thousands(value)}';

/// Signed amount using a real minus sign, e.g. "−28.000" / "+750.000".
String signed(int value) =>
    value < 0 ? '−${thousands(-value)}' : '+${thousands(value)}';
