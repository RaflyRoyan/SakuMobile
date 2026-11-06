import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saku_mobile/api/api_client.dart';
import 'package:saku_mobile/api/saku_api.dart';
import 'package:saku_mobile/split/qris.dart';

const _periode = {'id': 'PR-aktif', 'nama': 'Gajian Okt 2026', 'tanggalMulai': '2026-10-25', 'tanggalSelesai': null, 'keterangan': '', 'aktif': true};
const _pengguna = {'id': 'US-1', 'username': 'ryn', 'nama': 'Ryn', 'peran': 'admin', 'aktif': true, 'lastLogin': null};

Map<String, dynamic> _akunJson(String id, String nama, String jenis, int saldo) =>
    {'id': id, 'nama': nama, 'jenis': jenis, 'urutan': 1, 'aktif': true, 'saldo': saldo, 'dipilih': true, 'urutanSaya': 1};

final akunList = [
  _akunJson('AK-bca', 'BCA', 'bank', 2943500),
  _akunJson('AK-mdr', 'Mandiri', 'bank', 1800000),
  _akunJson('AK-jgo', 'Jago', 'bank', 1399000),
  _akunJson('AK-gp', 'GoPay', 'ewallet', 247000),
];

Map<String, dynamic> tx(String id, String tanggal, String tipe, int nominal, String desk, {String? kategori, String akun = 'GoPay', String? tujuan, int admin = 0}) => {
      'id': id,
      'periodeId': 'PR-aktif',
      'tanggal': tanggal,
      'tipe': tipe,
      'akunId': 'AK-x',
      'akunNama': akun,
      'akunTujuanId': tujuan == null ? null : 'AK-y',
      'akunTujuanNama': tujuan,
      'kategoriId': kategori == null ? null : 'KT-x',
      'kategoriNama': kategori,
      'kodeSistem': null,
      'nominal': nominal,
      'biayaAdmin': admin,
      'deskripsi': desk,
      'berulangId': null,
      'createdAt': null,
    };

/// Mutable so DELETE is visible to later GETs; reset per FakeServer.
List<Map<String, dynamic>> transaksiList = _seedTransaksi();

List<Map<String, dynamic>> _seedTransaksi() => [
  tx('TR-1', '2026-11-05', 'keluar', 28000, 'Kopi susu', kategori: 'Kopi'),
  tx('TR-2', '2026-11-04', 'keluar', 50000, 'Bensin motor', kategori: 'Bensin', akun: 'Jago'),
  tx('TR-3', '2026-11-03', 'masuk', 750000, 'Proyek freelance', kategori: 'Pemasukan lain', akun: 'Jago'),
  tx('TR-4', '2026-10-25', 'transfer', 2000000, 'Bagi gaji', akun: 'BCA', tujuan: 'Mandiri', admin: 2500),
];

final berulangJson = {
  'id': 'RB-gym',
  'nama': 'Gym Fit+',
  'akunId': 'AK-bca',
  'akunNama': 'BCA',
  'kategoriId': 'KT-olahraga',
  'kategoriNama': 'Olahraga',
  'nominal': 250000,
  'tglJatuhTempo': 1,
  'ingatkanHMin': 3,
  'mulai': '2026-01',
  'selesai': null,
  'aktif': true,
  'bulan': '2026-11',
  'jatuhTempo': '2026-11-01',
  'status': 'belum',
  'transaksiId': null,
  'berlaku': true,
};

final anggaranJson = {
  'periodeId': 'PR-aktif',
  'ada': true,
  'total': {'anggaran': 2340000, 'terpakai': 360500, 'sisa': 1979500, 'persen': 15, 'status': 'aman'},
  'kelompok': [
    {
      'kelompokId': 'KK-tr',
      'nama': 'Transportasi',
      'anggaranSendiri': 40000,
      'anggaran': 40000,
      'terpakai': 50000,
      'sisa': -10000,
      'persen': 125,
      'status': 'lewat',
      'sub': [
        {'kategoriId': 'KT-bensin', 'nama': 'Bensin', 'anggaran': null, 'terpakai': 50000, 'sisa': null, 'persen': null, 'status': null},
      ],
    },
  ],
};

/// Spending breakdown shared by `/dashboard` and `/periode/{id}/ringkasan`.
final ringkasanKategori = {
  'pengeluaranPerKategori': [
    {'kategoriId': 'KT-bensin', 'nama': 'Bensin', 'total': 50000, 'jumlah': 1},
    {'kategoriId': 'KT-kopi', 'nama': 'Kopi', 'total': 28000, 'jumlah': 1},
  ],
  'pengeluaranPerKelompok': [
    {
      'kelompokId': 'KK-tr',
      'nama': 'Transportasi',
      'total': 50000,
      'jumlah': 1,
      'sub': [
        {'kategoriId': 'KT-bensin', 'nama': 'Bensin', 'total': 50000, 'jumlah': 1},
      ],
    },
    {
      'kelompokId': 'KK-kh',
      'nama': 'Kebutuhan Harian',
      'total': 28000,
      'jumlah': 1,
      'sub': [
        {'kategoriId': 'KT-kopi', 'nama': 'Kopi', 'total': 28000, 'jumlah': 1},
      ],
    },
  ],
  'pemasukanPerKategori': [
    {'kategoriId': 'KT-lain', 'nama': 'Pemasukan lain', 'total': 750000, 'jumlah': 1},
  ],
};

String _tlv(String id, String v) => '$id${v.length.toString().padLeft(2, '0')}$v';

/// Valid static QRIS for TOKO SAKU / SURABAYA (not a real merchant).
final qrisContoh = () {
  final info = _tlv('00', 'ID.CO.QRIS.WWW') + _tlv('01', 'ID1023000000001');
  final body = '${_tlv('00', '01')}${_tlv('01', '11')}${_tlv('26', info)}${_tlv('52', '5812')}${_tlv('53', '360')}${_tlv('58', 'ID')}${_tlv('59', 'TOKO SAKU')}${_tlv('60', 'SURABAYA')}6304';
  return body + crc16(body);
}();

Map<String, dynamic> splitJson({bool budiLunas = false}) => {
      'id': 'SP-1',
      'nama': 'Bakmi GM',
      'tanggal': '2026-11-05',
      'akunId': 'AK-bca',
      'akunNama': 'BCA',
      'kategoriId': 'KT-kopi',
      'kategoriNama': 'Kopi',
      'akunTerimaId': 'AK-gp',
      'akunTerimaNama': 'GoPay',
      'subtotal': 60000,
      'pajak': 6000,
      'servis': 0,
      'diskon': 0,
      'total': 66000,
      'transaksiId': 'TR-sp',
      'items': [
        {'id': 'IT-1', 'nama': 'Bakmi Ayam', 'qty': 1, 'harga': 30000, 'peserta': ['PS-1']},
        {'id': 'IT-2', 'nama': 'Pangsit', 'qty': 2, 'harga': 20000, 'peserta': ['PS-2']},
        {'id': 'IT-3', 'nama': 'Es Teh', 'qty': 3, 'harga': 10000, 'peserta': ['PS-1', 'PS-2', 'PS-3']},
      ],
      'peserta': [
        {'id': 'PS-1', 'nama': 'Saya', 'saya': true, 'nominal': 36666, 'lunas': true, 'transaksiId': null},
        {'id': 'PS-2', 'nama': 'Budi', 'saya': false, 'nominal': 25667, 'lunas': budiLunas, 'transaksiId': budiLunas ? 'TR-b' : null},
        {'id': 'PS-3', 'nama': 'Sari', 'saya': false, 'nominal': 3667, 'lunas': false, 'transaksiId': null},
      ],
      'belumLunas': {'jumlah': budiLunas ? 1 : 2, 'nominal': budiLunas ? 3667 : 29334},
    };

/// Routes requests like the real API. Records every request for assertions.
class FakeServer {
  FakeServer() {
    transaksiList = _seedTransaksi();
  }

  final requests = <http.Request>[];
  bool loggedIn = false;

  /// Saved merchant QRIS payload (`/pengaturan/qris`); null = belum diatur.
  String? qrisPayload;
  bool budiLunas = false;

  late final client = MockClient((req) async {
    requests.add(req);
    final path = req.url.path.replaceFirst('/api', '');
    final m = req.method;
    http.Response json(Object? body, [int status = 200, Map<String, String> headers = const {}]) =>
        http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8', ...headers});

    if (path == '/auth/status') return json({'perluSetup': false});
    if (path == '/auth/login' && m == 'POST') {
      final body = jsonDecode(req.body) as Map;
      if (body['password'] != 'rahasia123') return json({'title': 'Username atau password salah.', 'status': 401}, 401);
      loggedIn = true;
      return json({'pengguna': _pengguna, 'expiresAt': '2026-12-05T00:00:00Z'}, 200, {'set-cookie': 'saku_token=jwt-abc; Path=/; HttpOnly; SameSite=Lax'});
    }
    if (!loggedIn || req.headers['Cookie'] != 'saku_token=jwt-abc') {
      return json({'title': 'Sesi berakhir, silakan login ulang.', 'status': 401}, 401);
    }

    if (m == 'DELETE' && path.startsWith('/transaksi/')) {
      final id = path.split('/').last;
      transaksiList.removeWhere((t) => t['id'] == id);
      return http.Response('', 204);
    }

    switch ((m, path)) {
      case ('GET', '/split'):
        return json([
          {'id': 'SP-1', 'nama': 'Bakmi GM', 'tanggal': '2026-11-05', 'total': 66000, 'jumlahPeserta': 3, 'belumLunas': splitJson(budiLunas: budiLunas)['belumLunas']},
        ]);
      case ('GET', '/split/nama'):
        return json(['Budi', 'Sari']);
      case ('GET', '/split/SP-1'):
        return json(splitJson(budiLunas: budiLunas));
      case ('POST', '/split'):
        return json({...splitJson(), 'peringatan': <String>[]}, 201);
      case ('PUT', '/split/SP-1'):
        return json({...splitJson(budiLunas: budiLunas), 'peringatan': <String>[]});
      case ('PUT', '/split/SP-1/peserta/PS-2/lunas'):
        budiLunas = (jsonDecode(req.body) as Map)['lunas'] == true;
        return json(splitJson(budiLunas: budiLunas));
      case ('DELETE', '/split/SP-1'):
        return http.Response('', 204);
      case ('GET', '/pengaturan/qris'):
        return json(qrisPayload == null ? null : {'payload': qrisPayload, 'merchant': 'TOKO SAKU', 'kota': 'SURABAYA'});
      case ('PUT', '/pengaturan/qris'):
        qrisPayload = (jsonDecode(req.body) as Map)['payload'] as String?;
        return json(qrisPayload == null ? null : {'payload': qrisPayload, 'merchant': 'TOKO SAKU', 'kota': 'SURABAYA'});
      case ('GET', '/auth/me'):
        return json(_pengguna);
      case ('POST', '/auth/logout'):
        loggedIn = false;
        return http.Response('', 204, headers: {'set-cookie': 'saku_token=; Max-Age=0; Path=/'});
      case ('GET', '/dashboard'):
        return json({
          'ringkasan': {
            'periode': _periode,
            'totalSaldoAwal': 6000000,
            'totalMasuk': 750000,
            'totalPengeluaran': 360500,
            'totalSaldoAkhir': 6389500,
            'perAkun': [
              for (final a in akunList)
                {'akunId': a['id'], 'nama': a['nama'], 'jenis': a['jenis'], 'aktif': true, 'saldoAwal': 0, 'masuk': 0, 'keluar': 0, 'biayaAdmin': 0, 'transferMasuk': 0, 'transferKeluar': 0, 'saldoAkhir': a['saldo'], 'jumlahTransaksi': 0},
            ],
            ...ringkasanKategori,
          },
          'anggaran': anggaranJson,
          'totalTabungan': 5971500,
          'pengingat': [
            {'berulangId': 'RB-gym', 'bulan': '2026-11', 'jatuhTempo': '2026-11-01', 'status': 'terlambat', 'sisaHari': -4, 'berulang': berulangJson},
          ],
          'transaksiTerakhir': transaksiList.take(3).toList(),
        });
      case ('GET', '/transaksi'):
        final tipe = req.url.queryParameters['tipe'];
        final data = transaksiList.where((t) => tipe == null || t['tipe'] == tipe).toList();
        return json({'data': data, 'total': data.length, 'halaman': 1, 'ukuran': 50});
      case ('GET', '/transaksi/TR-1'):
        return json(transaksiList.first);
      case ('POST', '/transaksi'):
        return json({...transaksiList.first, 'id': 'TR-new', 'peringatan': <String>[]}, 201);
      case ('GET', '/akun'):
        return json(akunList);
      case ('GET', '/akun/pilihan'):
        return json({'eksplisit': true, 'akun': akunList});
      case ('GET', '/kategori'):
        return json([
          {'id': 'KT-kopi', 'nama': 'Kopi', 'tipe': 'keluar', 'kodeSistem': null, 'aktif': true, 'kelompokId': 'KK-kh', 'kelompokNama': 'Kebutuhan Harian'},
          {'id': 'KT-lain', 'nama': 'Pemasukan lain', 'tipe': 'masuk', 'kodeSistem': null, 'aktif': true, 'kelompokId': null, 'kelompokNama': null},
        ]);
      case ('GET', '/kelompok-kategori'):
        return json([
          {'id': 'KK-kh', 'nama': 'Kebutuhan Harian', 'urutan': 1, 'aktif': true, 'sistem': false},
          {'id': 'LAINNYA', 'nama': 'Lainnya', 'urutan': 99, 'aktif': true, 'sistem': true},
        ]);
      case ('GET', '/periode'):
        return json([_periode]);
      case ('GET', '/periode/aktif'):
        return json({..._periode, 'saldoAwal': []});
      case ('GET', '/periode/aktif/pratinjau-tutup'):
        return json({
          'periode': _periode,
          'sisa': [for (final a in akunList) {'akunId': a['id'], 'nama': a['nama'], 'nominal': a['saldo']}],
          'total': 6389500,
        });
      case ('GET', '/periode/PR-aktif/ringkasan'):
        return json({
          'periode': _periode,
          'totalSaldoAwal': 6000000,
          'totalMasuk': 750000,
          'totalPengeluaran': 360500,
          'totalSaldoAkhir': 6389500,
          'perAkun': [
            {'akunId': 'AK-jgo', 'nama': 'Jago', 'jenis': 'bank', 'aktif': true, 'saldoAwal': 0, 'masuk': 750000, 'keluar': 50000, 'biayaAdmin': 0, 'transferMasuk': 0, 'transferKeluar': 0, 'saldoAkhir': 0, 'jumlahTransaksi': 2},
          ],
          ...ringkasanKategori,
        });
      case ('GET', '/periode/PR-aktif/anggaran'):
        return json(anggaranJson);
      case ('GET', '/tabungan'):
        return json({
          'total': 5971500,
          'perAkun': [
            {'akunId': 'AK-bca', 'nama': 'BCA', 'setor': 2997500, 'tarik': 0, 'saldo': 2997500},
          ],
          'riwayat': [
            {'id': 'TB-1', 'tanggal': '2026-10-24', 'jenis': 'setor', 'periodeId': 'PR-old', 'periodeNama': 'Gajian Sep 2026', 'akunId': 'AK-bca', 'akunNama': 'BCA', 'nominal': 2997500, 'keterangan': 'Sisa Gajian Sep 2026', 'transaksiId': null, 'bisaHapus': false},
          ],
        });
      case ('GET', '/berulang'):
        return json([berulangJson]);
      case ('GET', '/berulang/pengingat'):
        return json([
          {'berulangId': 'RB-gym', 'bulan': '2026-11', 'jatuhTempo': '2026-11-01', 'status': 'terlambat', 'sisaHari': -4, 'berulang': berulangJson},
        ]);
      case ('GET', '/pengguna'):
        return json([_pengguna]);
    }
    return json({'title': 'Tidak ditemukan: $m $path', 'status': 404}, 404);
  });

  /// [token] pre-seeds a stored cookie (resumed session); pair with `loggedIn = true`.
  SakuApi api({String? token}) => SakuApi(ApiClient(httpClient: client, tokenStore: MemoryTokenStore(token), baseUrl: 'https://test/api'));
}
