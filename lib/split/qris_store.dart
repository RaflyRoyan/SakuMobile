import '../api/models.dart';
import '../api/saku_api.dart';
import '../services/app_prefs.dart';
import 'qris.dart';

/// Merchant QRIS from the cache (offline) — merchant/kota re-parsed from the payload.
QrisTersimpan? qrisDariCache(AppPrefs prefs) {
  final p = prefs.qrisPayload;
  if (p == null) return null;
  final h = parseQris(p);
  return h.ok ? QrisTersimpan(payload: h.payload, merchant: h.merchant, kota: h.kota) : null;
}

/// Server copy when online (and refreshes the cache), else the cached one.
Future<QrisTersimpan?> muatQris(SakuApi api, AppPrefs prefs) async {
  try {
    final q = await api.qris();
    await prefs.setQrisPayload(q?.payload);
    return q;
  } catch (_) {
    return qrisDariCache(prefs);
  }
}
