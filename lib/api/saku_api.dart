import 'api_client.dart';
import 'models.dart';

/// Typed wrappers around every endpoint the app uses.
class SakuApi {
  SakuApi(this.client);

  final ApiClient client;

  List<T> _list<T>(Object? v, T Function(Json) f) => (v as List).map((e) => f((e as Map).cast<String, dynamic>())).toList();
  Json _obj(Object? v) => (v as Map).cast<String, dynamic>();

  // ── Auth
  Future<bool> perluSetup() async => (await client.get<Json>('/auth/status'))['perluSetup'] == true;

  Future<Pengguna> login(String username, String password) async =>
      Pengguna.fromJson(_obj((await client.post<Json>('/auth/login', {'username': username, 'password': password}))['pengguna']));

  Future<Pengguna> setup(String username, String password, String nama) async =>
      Pengguna.fromJson(_obj((await client.post<Json>('/auth/setup', {'username': username, 'password': password, 'nama': nama}))['pengguna']));

  Future<void> logout() async {
    try {
      await client.post<dynamic>('/auth/logout');
    } finally {
      await client.clearToken();
    }
  }

  Future<Pengguna> me() async => Pengguna.fromJson(await client.get<Json>('/auth/me'));
  Future<void> gantiPassword(String lama, String baru) => client.put<dynamic>('/auth/password', {'passwordLama': lama, 'passwordBaru': baru});
  Future<Pengguna> ubahProfil(String nama) async => Pengguna.fromJson(await client.put<Json>('/auth/profil', {'nama': nama}));

  // ── Dashboard
  Future<Dashboard> dashboard() async => Dashboard.fromJson(await client.get<Json>('/dashboard'));

  // ── Akun & kategori
  Future<List<Akun>> akun({bool termasukNonaktif = false}) async =>
      _list(await client.get<List>('/akun', query: {'termasukNonaktif': '$termasukNonaktif'}), Akun.fromJson);
  Future<PilihanAkun> pilihanAkun() async => PilihanAkun.fromJson(await client.get<Json>('/akun/pilihan'));
  Future<void> simpanPilihanAkun(List<String> ids) => client.put<dynamic>('/akun/pilihan', {'ids': ids});

  Future<List<Kategori>> kategori({String? tipe, bool untukInput = false, bool termasukNonaktif = false}) async => _list(
        await client.get<List>('/kategori', query: {'tipe': tipe, 'untukInput': '$untukInput', 'termasukNonaktif': '$termasukNonaktif'}),
        Kategori.fromJson,
      );
  Future<List<KelompokKategori>> kelompokKategori() async => _list(await client.get<List>('/kelompok-kategori'), KelompokKategori.fromJson);

  // ── Periode & anggaran
  Future<List<Periode>> periode() async => _list(await client.get<List>('/periode'), Periode.fromJson);

  /// Null when there is no active period (404).
  Future<Periode?> periodeAktif() async {
    try {
      return Periode.fromJson(await client.get<Json>('/periode/aktif'));
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// Null when there is no active period (404).
  Future<PratinjauTutup?> pratinjauTutup() async {
    try {
      return PratinjauTutup.fromJson(await client.get<Json>('/periode/aktif/pratinjau-tutup'));
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<HasilMulaiPeriode> mulaiPeriode({
    String? nama,
    required String tanggalMulai,
    required List<({String akunId, int saldo})> saldoAwal,
    required List<({String akunId, int nominal})> teruskan,
    required bool salinAnggaran,
  }) async =>
      HasilMulaiPeriode.fromJson(await client.post<Json>('/periode/mulai', {
        if (nama != null && nama.isNotEmpty) 'nama': nama,
        'tanggalMulai': tanggalMulai,
        'saldoAwal': [for (final s in saldoAwal) {'akunId': s.akunId, 'saldo': s.saldo}],
        'teruskan': [for (final t in teruskan) {'akunId': t.akunId, 'nominal': t.nominal}],
        'salinAnggaran': salinAnggaran,
      }));

  Future<Ringkasan> ringkasanPeriode(String periodeId) async => Ringkasan.fromJson(await client.get<Json>('/periode/$periodeId/ringkasan'));

  Future<AnggaranPeriode> anggaran(String periodeId) async => AnggaranPeriode.fromJson(await client.get<Json>('/periode/$periodeId/anggaran'));

  Future<AnggaranPeriode> simpanAnggaran(String periodeId, List<({String? kelompokId, String? kategoriId, int nominal})> items) async =>
      AnggaranPeriode.fromJson(await client.put<Json>('/periode/$periodeId/anggaran', {
        'items': [
          for (final i in items)
            {if (i.kelompokId != null) 'kelompokId': i.kelompokId, if (i.kategoriId != null) 'kategoriId': i.kategoriId, 'nominal': i.nominal},
        ],
      }));

  // ── Split bill
  Future<List<SplitRingkas>> split() async => _list(await client.get<List>('/split'), SplitRingkas.fromJson);
  Future<List<String>> namaPesertaSplit() async => (await client.get<List>('/split/nama')).map((e) => '$e').toList();
  Future<SplitBill> detailSplit(String id) async => SplitBill.fromJson(await client.get<Json>('/split/$id'));
  Future<SplitBill> buatSplit(SplitInput input) async => SplitBill.fromJson(await client.post<Json>('/split', input.toJson()));
  Future<SplitBill> ubahSplit(String id, SplitInput input) async => SplitBill.fromJson(await client.put<Json>('/split/$id', input.toJson()));
  Future<void> hapusSplit(String id) => client.delete<dynamic>('/split/$id');
  Future<SplitBill> setLunas(String id, String pesertaId, bool lunas, {String? tanggal}) async =>
      SplitBill.fromJson(await client.put<Json>('/split/$id/peserta/$pesertaId/lunas', {'lunas': lunas, 'tanggal': ?tanggal}));

  // ── Pengaturan QRIS (null = belum diatur)
  Future<QrisTersimpan?> qris() async {
    final j = await client.get<Json?>('/pengaturan/qris');
    return j == null ? null : QrisTersimpan.fromJson(j);
  }

  Future<QrisTersimpan?> simpanQris(String? payload) async {
    final j = await client.put<Json?>('/pengaturan/qris', {'payload': payload});
    return j == null ? null : QrisTersimpan.fromJson(j);
  }

  // ── Transaksi
  Future<HalamanTransaksi> transaksi({String? periodeId, String? akunId, String? tipe, String? q, int halaman = 1, int ukuran = 50}) async =>
      HalamanTransaksi.fromJson(await client.get<Json>('/transaksi', query: {
        'periodeId': periodeId,
        'akunId': akunId,
        'tipe': tipe,
        'q': q,
        'halaman': '$halaman',
        'ukuran': '$ukuran',
      }));

  Future<Transaksi> detailTransaksi(String id) async => Transaksi.fromJson(await client.get<Json>('/transaksi/$id'));
  Future<Transaksi> buatTransaksi(TransaksiInput input) async => Transaksi.fromJson(await client.post<Json>('/transaksi', input.toJson()));
  Future<Transaksi> ubahTransaksi(String id, TransaksiInput input) async => Transaksi.fromJson(await client.put<Json>('/transaksi/$id', input.toJson()));
  Future<void> hapusTransaksi(String id) => client.delete<dynamic>('/transaksi/$id');

  // ── Tabungan
  Future<Tabungan> tabungan() async => Tabungan.fromJson(await client.get<Json>('/tabungan'));
  Future<void> tarikTabungan({required String akunId, required int nominal, required String keterangan, String? tanggal}) =>
      client.post<dynamic>('/tabungan/tarik', {'akunId': akunId, 'nominal': nominal, 'keterangan': keterangan, 'tanggal': ?tanggal});
  Future<void> hapusTabungan(String id) => client.delete<dynamic>('/tabungan/$id');

  // ── Berulang
  Future<List<Berulang>> berulang({bool termasukNonaktif = false}) async =>
      _list(await client.get<List>('/berulang', query: {'termasukNonaktif': '$termasukNonaktif'}), Berulang.fromJson);
  Future<List<Pengingat>> pengingat() async => _list(await client.get<List>('/berulang/pengingat'), Pengingat.fromJson);
  Future<void> buatBerulang(BerulangInput input) => client.post<dynamic>('/berulang', input.toJson());
  Future<void> ubahBerulang(String id, BerulangInput input) => client.put<dynamic>('/berulang/$id', input.toJson(withAktif: true));
  Future<Transaksi> konfirmasiBerulang(String id, String bulan) async => Transaksi.fromJson(await client.post<Json>('/berulang/$id/konfirmasi', {'bulan': bulan}));
  Future<void> lewatiBerulang(String id, String bulan) => client.post<dynamic>('/berulang/$id/lewati', {'bulan': bulan});
  Future<void> batalLewati(String id, String bulan) => client.delete<dynamic>('/berulang/$id/lewati/$bulan');

  // ── Pengguna (admin)
  Future<List<Pengguna>> pengguna() async => _list(await client.get<List>('/pengguna'), Pengguna.fromJson);
  Future<void> tambahPengguna({required String username, required String password, required String nama, required String peran}) =>
      client.post<dynamic>('/pengguna', {'username': username, 'password': password, 'nama': nama, 'peran': peran});
  Future<void> ubahPengguna(String id, {required String nama, required String peran, required bool aktif}) =>
      client.put<dynamic>('/pengguna/$id', {'nama': nama, 'peran': peran, 'aktif': aktif});
  Future<void> resetPassword(String id, String passwordBaru) => client.post<dynamic>('/pengguna/$id/reset-password', {'passwordBaru': passwordBaru});
}
