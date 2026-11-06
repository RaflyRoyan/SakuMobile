// DTOs mirroring the Saku API (see saku-web-vercel src/hooks/*.ts).
// Money is int rupiah. Dates are `yyyy-MM-dd`, months `yyyy-MM`.

typedef Json = Map<String, dynamic>;

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
int? _intOrNull(Object? v) => v == null ? null : _int(v);
String _str(Object? v) => v == null ? '' : '$v';
String? _strOrNull(Object? v) => v == null || (v is String && v.isEmpty) ? null : '$v';
List<T> _list<T>(Object? v, T Function(Json) f) => v is List ? v.whereType<Map>().map((e) => f(e.cast<String, dynamic>())).toList() : <T>[];

enum TipeTransaksi {
  keluar,
  masuk,
  transfer;

  String get label => switch (this) { keluar => 'Keluar', masuk => 'Masuk', transfer => 'Transfer' };
  static TipeTransaksi parse(Object? v) => values.firstWhere((t) => t.name == v, orElse: () => keluar);
}

enum StatusAnggaran {
  aman,
  hampir,
  lewat;

  String get label => switch (this) { aman => 'Aman', hampir => 'Hampir', lewat => 'Lewat' };
  static StatusAnggaran? parse(Object? v) => values.where((s) => s.name == v).firstOrNull;
}

class Pengguna {
  Pengguna({required this.id, required this.username, required this.nama, required this.peran, required this.aktif, this.lastLogin});

  factory Pengguna.fromJson(Json j) => Pengguna(
        id: _str(j['id']),
        username: _str(j['username']),
        nama: _str(j['nama']),
        peran: _str(j['peran']),
        aktif: j['aktif'] != false,
        lastLogin: _strOrNull(j['lastLogin']),
      );

  final String id;
  final String username;
  final String nama;
  final String peran;
  final bool aktif;
  final String? lastLogin;

  bool get isAdmin => peran == 'admin';

  String get inisial {
    final parts = nama.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

class Akun {
  Akun({required this.id, required this.nama, required this.jenis, required this.urutan, required this.aktif, this.saldo, required this.dipilih});

  factory Akun.fromJson(Json j) => Akun(
        id: _str(j['id']),
        nama: _str(j['nama']),
        jenis: _str(j['jenis']),
        urutan: _int(j['urutan']),
        aktif: j['aktif'] != false,
        saldo: _intOrNull(j['saldo']),
        dipilih: j['dipilih'] != false,
      );

  final String id;
  final String nama;
  final String jenis;
  final int urutan;
  final bool aktif;
  final int? saldo;
  final bool dipilih;
}

class PilihanAkun {
  PilihanAkun({required this.eksplisit, required this.akun});

  factory PilihanAkun.fromJson(Json j) => PilihanAkun(eksplisit: j['eksplisit'] == true, akun: _list(j['akun'], Akun.fromJson));

  final bool eksplisit;
  final List<Akun> akun;
}

class Kategori {
  Kategori({required this.id, required this.nama, required this.tipe, this.kodeSistem, required this.aktif, this.kelompokId, this.kelompokNama});

  factory Kategori.fromJson(Json j) => Kategori(
        id: _str(j['id']),
        nama: _str(j['nama']),
        tipe: _str(j['tipe']),
        kodeSistem: _strOrNull(j['kodeSistem']),
        aktif: j['aktif'] != false,
        kelompokId: _strOrNull(j['kelompokId']),
        kelompokNama: _strOrNull(j['kelompokNama']),
      );

  final String id;
  final String nama;
  final String tipe;
  final String? kodeSistem;
  final bool aktif;
  final String? kelompokId;
  final String? kelompokNama;
}

class KelompokKategori {
  KelompokKategori({required this.id, required this.nama, required this.urutan, required this.aktif, required this.sistem});

  factory KelompokKategori.fromJson(Json j) => KelompokKategori(
        id: _str(j['id']),
        nama: _str(j['nama']),
        urutan: _int(j['urutan']),
        aktif: j['aktif'] != false,
        sistem: j['sistem'] == true,
      );

  final String id;
  final String nama;
  final int urutan;
  final bool aktif;
  final bool sistem;
}

class Periode {
  Periode({required this.id, required this.nama, required this.tanggalMulai, this.tanggalSelesai, required this.keterangan, required this.aktif, this.saldoAwal = const []});

  factory Periode.fromJson(Json j) => Periode(
        id: _str(j['id']),
        nama: _str(j['nama']),
        tanggalMulai: _str(j['tanggalMulai']),
        tanggalSelesai: _strOrNull(j['tanggalSelesai']),
        keterangan: _str(j['keterangan']),
        aktif: j['aktif'] == true,
        saldoAwal: _list(j['saldoAwal'], (s) => (akunId: _str(s['akunId']), saldo: _int(s['saldo']))),
      );

  final String id;
  final String nama;
  final String tanggalMulai;
  final String? tanggalSelesai;
  final String keterangan;
  final bool aktif;
  final List<({String akunId, int saldo})> saldoAwal;
}

class PerKategori {
  PerKategori({required this.id, required this.nama, required this.total, required this.jumlah, this.sub = const []});

  /// Also parses a `PerKelompok` (kelompokId + `sub` per kategori).
  factory PerKategori.fromJson(Json j) => PerKategori(
        id: _str(j['kategoriId'] ?? j['kelompokId']),
        nama: _str(j['nama']),
        total: _int(j['total']),
        jumlah: _int(j['jumlah']),
        sub: _list(j['sub'], PerKategori.fromJson),
      );

  final String id;
  final String nama;
  final int total;
  final int jumlah;

  /// Per sub kategori, largest first (only for kelompok rows).
  final List<PerKategori> sub;
}

class RingkasanAkun {
  RingkasanAkun({
    required this.akunId,
    required this.nama,
    required this.jenis,
    required this.saldoAwal,
    required this.masuk,
    required this.keluar,
    required this.biayaAdmin,
    required this.saldoAkhir,
  });

  factory RingkasanAkun.fromJson(Json j) => RingkasanAkun(
        akunId: _str(j['akunId']),
        nama: _str(j['nama']),
        jenis: _str(j['jenis']),
        saldoAwal: _int(j['saldoAwal']),
        masuk: _int(j['masuk']),
        keluar: _int(j['keluar']),
        biayaAdmin: _int(j['biayaAdmin']),
        saldoAkhir: _int(j['saldoAkhir']),
      );

  final String akunId;
  final String nama;
  final String jenis;
  final int saldoAwal;
  final int masuk;
  final int keluar;
  final int biayaAdmin;
  final int saldoAkhir;
}

class Ringkasan {
  Ringkasan({
    required this.periode,
    required this.totalSaldoAwal,
    required this.totalMasuk,
    required this.totalPengeluaran,
    required this.totalSaldoAkhir,
    required this.perAkun,
    this.pengeluaranPerKategori = const [],
    this.pengeluaranPerKelompok = const [],
    this.pemasukanPerKategori = const [],
  });

  factory Ringkasan.fromJson(Json j) => Ringkasan(
        periode: Periode.fromJson((j['periode'] as Map).cast<String, dynamic>()),
        totalSaldoAwal: _int(j['totalSaldoAwal']),
        totalMasuk: _int(j['totalMasuk']),
        totalPengeluaran: _int(j['totalPengeluaran']),
        totalSaldoAkhir: _int(j['totalSaldoAkhir']),
        perAkun: _list(j['perAkun'], RingkasanAkun.fromJson),
        pengeluaranPerKategori: _list(j['pengeluaranPerKategori'], PerKategori.fromJson),
        pengeluaranPerKelompok: _list(j['pengeluaranPerKelompok'], PerKategori.fromJson),
        pemasukanPerKategori: _list(j['pemasukanPerKategori'], PerKategori.fromJson),
      );

  final Periode periode;
  final int totalSaldoAwal;
  final int totalMasuk;
  final int totalPengeluaran;
  final int totalSaldoAkhir;
  final List<RingkasanAkun> perAkun;

  /// Spending per kategori / per kelompok (with `sub`) and income per kategori, largest first.
  final List<PerKategori> pengeluaranPerKategori;
  final List<PerKategori> pengeluaranPerKelompok;
  final List<PerKategori> pemasukanPerKategori;
}

class Transaksi {
  Transaksi({
    required this.id,
    required this.periodeId,
    required this.tanggal,
    required this.tipe,
    required this.akunId,
    required this.akunNama,
    this.akunTujuanId,
    this.akunTujuanNama,
    this.kategoriId,
    this.kategoriNama,
    this.kodeSistem,
    required this.nominal,
    required this.biayaAdmin,
    required this.deskripsi,
    this.berulangId,
    this.createdAt,
    this.peringatan = const [],
  });

  factory Transaksi.fromJson(Json j) => Transaksi(
        id: _str(j['id']),
        periodeId: _str(j['periodeId']),
        tanggal: _str(j['tanggal']),
        tipe: TipeTransaksi.parse(j['tipe']),
        akunId: _str(j['akunId']),
        akunNama: _str(j['akunNama']),
        akunTujuanId: _strOrNull(j['akunTujuanId']),
        akunTujuanNama: _strOrNull(j['akunTujuanNama']),
        kategoriId: _strOrNull(j['kategoriId']),
        kategoriNama: _strOrNull(j['kategoriNama']),
        kodeSistem: _strOrNull(j['kodeSistem']),
        nominal: _int(j['nominal']),
        biayaAdmin: _int(j['biayaAdmin']),
        deskripsi: _str(j['deskripsi']),
        berulangId: _strOrNull(j['berulangId']),
        createdAt: _strOrNull(j['createdAt']),
        peringatan: (j['peringatan'] as List?)?.map((e) => '$e').toList() ?? const [],
      );

  final String id;
  final String periodeId;
  final String tanggal;
  final TipeTransaksi tipe;
  final String akunId;
  final String akunNama;
  final String? akunTujuanId;
  final String? akunTujuanNama;
  final String? kategoriId;
  final String? kategoriNama;
  final String? kodeSistem;
  final int nominal;
  final int biayaAdmin;
  final String deskripsi;
  final String? berulangId;
  final String? createdAt;
  final List<String> peringatan;

  bool get isTarikTabungan => kodeSistem == 'TARIK_TABUNGAN';

  /// Text shown as the row title.
  String get judul {
    if (deskripsi.isNotEmpty) return deskripsi;
    if (tipe == TipeTransaksi.transfer) return 'Transfer';
    return kategoriNama ?? tipe.label;
  }
}

class HalamanTransaksi {
  HalamanTransaksi({required this.data, required this.total, required this.halaman, required this.ukuran});

  factory HalamanTransaksi.fromJson(Json j) =>
      HalamanTransaksi(data: _list(j['data'], Transaksi.fromJson), total: _int(j['total']), halaman: _int(j['halaman']), ukuran: _int(j['ukuran']));

  final List<Transaksi> data;
  final int total;
  final int halaman;
  final int ukuran;
}

class PosAnggaran {
  PosAnggaran({required this.id, required this.nama, this.anggaran, required this.terpakai, this.sisa, this.persen, this.status, this.anggaranSendiri, this.sub = const []});

  factory PosAnggaran.fromJson(Json j) => PosAnggaran(
        id: _str(j['kelompokId'] ?? j['kategoriId']),
        nama: _str(j['nama']),
        anggaran: _intOrNull(j['anggaran']),
        terpakai: _int(j['terpakai']),
        sisa: _intOrNull(j['sisa']),
        persen: _intOrNull(j['persen']),
        status: StatusAnggaran.parse(j['status']),
        anggaranSendiri: _intOrNull(j['anggaranSendiri']),
        sub: _list(j['sub'], PosAnggaran.fromJson),
      );

  final String id;
  final String nama;
  final int? anggaran;
  final int terpakai;
  final int? sisa;
  final int? persen;
  final StatusAnggaran? status;
  final int? anggaranSendiri;
  final List<PosAnggaran> sub;
}

class AnggaranPeriode {
  AnggaranPeriode({required this.periodeId, required this.ada, required this.total, required this.kelompok});

  factory AnggaranPeriode.fromJson(Json j) => AnggaranPeriode(
        periodeId: _str(j['periodeId']),
        ada: j['ada'] == true,
        total: PosAnggaran.fromJson((j['total'] as Map? ?? {}).cast<String, dynamic>()),
        kelompok: _list(j['kelompok'], PosAnggaran.fromJson),
      );

  final String periodeId;
  final bool ada;
  final PosAnggaran total;
  final List<PosAnggaran> kelompok;
}

class Berulang {
  Berulang({
    required this.id,
    required this.nama,
    required this.akunId,
    required this.akunNama,
    required this.kategoriId,
    required this.kategoriNama,
    required this.nominal,
    required this.tglJatuhTempo,
    required this.ingatkanHMin,
    required this.mulai,
    this.selesai,
    required this.aktif,
    required this.bulan,
    required this.jatuhTempo,
    required this.status,
    this.transaksiId,
    required this.berlaku,
  });

  factory Berulang.fromJson(Json j) => Berulang(
        id: _str(j['id']),
        nama: _str(j['nama']),
        akunId: _str(j['akunId']),
        akunNama: _str(j['akunNama']),
        kategoriId: _str(j['kategoriId']),
        kategoriNama: _str(j['kategoriNama']),
        nominal: _int(j['nominal']),
        tglJatuhTempo: _int(j['tglJatuhTempo']),
        ingatkanHMin: _int(j['ingatkanHMin']),
        mulai: _str(j['mulai']),
        selesai: _strOrNull(j['selesai']),
        aktif: j['aktif'] != false,
        bulan: _str(j['bulan']),
        jatuhTempo: _str(j['jatuhTempo']),
        status: _str(j['status']),
        transaksiId: _strOrNull(j['transaksiId']),
        berlaku: j['berlaku'] != false,
      );

  final String id;
  final String nama;
  final String akunId;
  final String akunNama;
  final String kategoriId;
  final String kategoriNama;
  final int nominal;
  final int tglJatuhTempo;
  final int ingatkanHMin;
  final String mulai;
  final String? selesai;
  final bool aktif;

  /// Month the status refers to (`yyyy-MM`).
  final String bulan;
  final String jatuhTempo;

  /// `belum` / `dibayar` / `dilewati`.
  final String status;
  final String? transaksiId;
  final bool berlaku;
}

class Pengingat {
  Pengingat({required this.berulangId, required this.bulan, required this.jatuhTempo, required this.status, required this.sisaHari, required this.berulang});

  factory Pengingat.fromJson(Json j) => Pengingat(
        berulangId: _str(j['berulangId']),
        bulan: _str(j['bulan']),
        jatuhTempo: _str(j['jatuhTempo']),
        status: _str(j['status']),
        sisaHari: _int(j['sisaHari']),
        berulang: Berulang.fromJson((j['berulang'] as Map).cast<String, dynamic>()),
      );

  final String berulangId;
  final String bulan;
  final String jatuhTempo;

  /// `akan_datang` / `hari_ini` / `terlambat`.
  final String status;
  final int sisaHari;
  final Berulang berulang;
}

class Dashboard {
  Dashboard({this.ringkasan, this.anggaran, required this.totalTabungan, required this.pengingat, required this.transaksiTerakhir});

  factory Dashboard.fromJson(Json j) => Dashboard(
        ringkasan: j['ringkasan'] == null ? null : Ringkasan.fromJson((j['ringkasan'] as Map).cast<String, dynamic>()),
        anggaran: j['anggaran'] == null ? null : AnggaranPeriode.fromJson((j['anggaran'] as Map).cast<String, dynamic>()),
        totalTabungan: _int(j['totalTabungan']),
        pengingat: _list(j['pengingat'], Pengingat.fromJson),
        transaksiTerakhir: _list(j['transaksiTerakhir'], Transaksi.fromJson),
      );

  final Ringkasan? ringkasan;
  final AnggaranPeriode? anggaran;
  final int totalTabungan;
  final List<Pengingat> pengingat;
  final List<Transaksi> transaksiTerakhir;
}

class RiwayatTabungan {
  RiwayatTabungan({
    required this.id,
    required this.tanggal,
    required this.jenis,
    required this.periodeNama,
    required this.akunId,
    required this.akunNama,
    required this.nominal,
    required this.keterangan,
    this.transaksiId,
    required this.bisaHapus,
  });

  factory RiwayatTabungan.fromJson(Json j) => RiwayatTabungan(
        id: _str(j['id']),
        tanggal: _str(j['tanggal']),
        jenis: _str(j['jenis']),
        periodeNama: _str(j['periodeNama']),
        akunId: _str(j['akunId']),
        akunNama: _str(j['akunNama']),
        nominal: _int(j['nominal']),
        keterangan: _str(j['keterangan']),
        transaksiId: _strOrNull(j['transaksiId']),
        bisaHapus: j['bisaHapus'] == true,
      );

  final String id;
  final String tanggal;

  /// `setor` / `tarik`.
  final String jenis;
  final String periodeNama;
  final String akunId;
  final String akunNama;
  final int nominal;
  final String keterangan;
  final String? transaksiId;
  final bool bisaHapus;
}

class TabunganAkun {
  TabunganAkun({required this.akunId, required this.nama, required this.setor, required this.tarik, required this.saldo});

  factory TabunganAkun.fromJson(Json j) =>
      TabunganAkun(akunId: _str(j['akunId']), nama: _str(j['nama']), setor: _int(j['setor']), tarik: _int(j['tarik']), saldo: _int(j['saldo']));

  final String akunId;
  final String nama;
  final int setor;
  final int tarik;
  final int saldo;
}

class Tabungan {
  Tabungan({required this.total, required this.perAkun, required this.riwayat});

  factory Tabungan.fromJson(Json j) =>
      Tabungan(total: _int(j['total']), perAkun: _list(j['perAkun'], TabunganAkun.fromJson), riwayat: _list(j['riwayat'], RiwayatTabungan.fromJson));

  final int total;
  final List<TabunganAkun> perAkun;
  final List<RiwayatTabungan> riwayat;
}

class PratinjauTutup {
  PratinjauTutup({required this.periode, required this.sisa, required this.total});

  factory PratinjauTutup.fromJson(Json j) => PratinjauTutup(
        periode: Periode.fromJson((j['periode'] as Map).cast<String, dynamic>()),
        sisa: _list(j['sisa'], (s) => (akunId: _str(s['akunId']), nama: _str(s['nama']), nominal: _int(s['nominal']))),
        total: _int(j['total']),
      );

  final Periode periode;
  final List<({String akunId, String nama, int nominal})> sisa;
  final int total;
}

class HasilMulaiPeriode {
  HasilMulaiPeriode({required this.periode, required this.anggaranDisalin, required this.transaksiTetapDiPeriodeLama, required this.totalTabungan});

  factory HasilMulaiPeriode.fromJson(Json j) => HasilMulaiPeriode(
        periode: Periode.fromJson((j['periode'] as Map).cast<String, dynamic>()),
        anggaranDisalin: _int(j['anggaranDisalin']),
        transaksiTetapDiPeriodeLama: _int(j['transaksiTetapDiPeriodeLama']),
        totalTabungan: _int(j['totalTabungan']),
      );

  final Periode periode;
  final int anggaranDisalin;
  final int transaksiTetapDiPeriodeLama;
  final int totalTabungan;
}

/// Request body for POST/PUT /transaksi.
class TransaksiInput {
  TransaksiInput({
    required this.tipe,
    required this.tanggal,
    required this.akunId,
    this.akunTujuanId,
    this.kategoriId,
    required this.nominal,
    this.biayaAdmin = 0,
    this.deskripsi = '',
  });

  final TipeTransaksi tipe;
  final String tanggal;
  final String akunId;
  final String? akunTujuanId;
  final String? kategoriId;
  final int nominal;
  final int biayaAdmin;
  final String deskripsi;

  Json toJson() => {
        'tipe': tipe.name,
        'tanggal': tanggal,
        'akunId': akunId,
        if (tipe == TipeTransaksi.transfer) 'akunTujuanId': akunTujuanId,
        if (tipe != TipeTransaksi.transfer) 'kategoriId': kategoriId,
        'nominal': nominal,
        if (tipe == TipeTransaksi.transfer) 'biayaAdmin': biayaAdmin,
        'deskripsi': deskripsi,
      };
}

/// Request body for POST/PUT /berulang.
class BerulangInput {
  BerulangInput({
    required this.nama,
    required this.akunId,
    required this.kategoriId,
    required this.nominal,
    required this.tglJatuhTempo,
    required this.ingatkanHMin,
    required this.mulai,
    this.selesai,
    this.aktif = true,
  });

  final String nama;
  final String akunId;
  final String kategoriId;
  final int nominal;
  final int tglJatuhTempo;
  final int ingatkanHMin;
  final String mulai;
  final String? selesai;
  final bool aktif;

  Json toJson({bool withAktif = false}) => {
        'nama': nama,
        'akunId': akunId,
        'kategoriId': kategoriId,
        'nominal': nominal,
        'tglJatuhTempo': tglJatuhTempo,
        'ingatkanHMin': ingatkanHMin,
        'mulai': mulai,
        'selesai': selesai,
        if (withAktif) 'aktif': aktif,
      };
}

// ── Split bill

class BelumLunas {
  const BelumLunas({required this.jumlah, required this.nominal});

  factory BelumLunas.fromJson(Object? v) {
    final j = v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};
    return BelumLunas(jumlah: _int(j['jumlah']), nominal: _int(j['nominal']));
  }

  final int jumlah;
  final int nominal;
}

class SplitRingkas {
  SplitRingkas({required this.id, required this.nama, required this.tanggal, required this.total, required this.jumlahPeserta, required this.belumLunas});

  factory SplitRingkas.fromJson(Json j) => SplitRingkas(
        id: _str(j['id']),
        nama: _str(j['nama']),
        tanggal: _str(j['tanggal']),
        total: _int(j['total']),
        jumlahPeserta: _int(j['jumlahPeserta']),
        belumLunas: BelumLunas.fromJson(j['belumLunas']),
      );

  final String id;
  final String nama;
  final String tanggal;
  final int total;
  final int jumlahPeserta;
  final BelumLunas belumLunas;
}

class SplitItem {
  SplitItem({required this.id, required this.nama, required this.qty, required this.harga, required this.peserta});

  factory SplitItem.fromJson(Json j) => SplitItem(
        id: _str(j['id']),
        nama: _str(j['nama']),
        qty: _int(j['qty']),
        harga: _int(j['harga']),
        peserta: (j['peserta'] as List?)?.map((e) => '$e').toList() ?? const [],
      );

  final String id;
  final String nama;
  final int qty;

  /// Harga total baris.
  final int harga;

  /// ID peserta pemilik.
  final List<String> peserta;
}

class SplitPeserta {
  SplitPeserta({required this.id, required this.nama, required this.saya, required this.nominal, required this.lunas, this.transaksiId});

  factory SplitPeserta.fromJson(Json j) => SplitPeserta(
        id: _str(j['id']),
        nama: _str(j['nama']),
        saya: j['saya'] == true,
        nominal: _int(j['nominal']),
        lunas: j['lunas'] == true,
        transaksiId: _strOrNull(j['transaksiId']),
      );

  final String id;
  final String nama;
  final bool saya;
  final int nominal;
  final bool lunas;
  final String? transaksiId;
}

class SplitBill {
  SplitBill({
    required this.id,
    required this.nama,
    required this.tanggal,
    required this.akunId,
    required this.akunNama,
    required this.kategoriId,
    required this.kategoriNama,
    required this.akunTerimaId,
    required this.akunTerimaNama,
    required this.subtotal,
    required this.pajak,
    required this.servis,
    required this.diskon,
    required this.total,
    this.transaksiId,
    required this.items,
    required this.peserta,
    required this.belumLunas,
    this.peringatan = const [],
  });

  factory SplitBill.fromJson(Json j) => SplitBill(
        id: _str(j['id']),
        nama: _str(j['nama']),
        tanggal: _str(j['tanggal']),
        akunId: _str(j['akunId']),
        akunNama: _str(j['akunNama']),
        kategoriId: _str(j['kategoriId']),
        kategoriNama: _str(j['kategoriNama']),
        akunTerimaId: _str(j['akunTerimaId']),
        akunTerimaNama: _str(j['akunTerimaNama']),
        subtotal: _int(j['subtotal']),
        pajak: _int(j['pajak']),
        servis: _int(j['servis']),
        diskon: _int(j['diskon']),
        total: _int(j['total']),
        transaksiId: _strOrNull(j['transaksiId']),
        items: _list(j['items'], SplitItem.fromJson),
        peserta: _list(j['peserta'], SplitPeserta.fromJson),
        belumLunas: BelumLunas.fromJson(j['belumLunas']),
        peringatan: (j['peringatan'] as List?)?.map((e) => '$e').toList() ?? const [],
      );

  final String id;
  final String nama;
  final String tanggal;
  final String akunId;
  final String akunNama;
  final String kategoriId;
  final String kategoriNama;
  final String akunTerimaId;
  final String akunTerimaNama;
  final int subtotal;
  final int pajak;
  final int servis;
  final int diskon;
  final int total;
  final String? transaksiId;
  final List<SplitItem> items;
  final List<SplitPeserta> peserta;
  final BelumLunas belumLunas;

  /// Non-blocking server warnings after create/update.
  final List<String> peringatan;
}

class SplitInput {
  SplitInput({
    required this.nama,
    required this.tanggal,
    required this.akunId,
    required this.kategoriId,
    required this.akunTerimaId,
    required this.pajak,
    required this.servis,
    required this.diskon,
    required this.peserta,
    required this.items,
  });

  final String nama;
  final String tanggal;
  final String akunId;
  final String kategoriId;
  final String akunTerimaId;
  final int pajak;
  final int servis;
  final int diskon;
  final List<({String? id, String nama, bool saya})> peserta;

  /// `peserta` are INDICES into [peserta].
  final List<({String nama, int qty, int harga, List<int> peserta})> items;

  Json toJson() => {
        'nama': nama,
        'tanggal': tanggal,
        'akunId': akunId,
        'kategoriId': kategoriId,
        'akunTerimaId': akunTerimaId,
        'pajak': pajak,
        'servis': servis,
        'diskon': diskon,
        'peserta': [
          for (final p in peserta) {'id': ?p.id, 'nama': p.nama, 'saya': p.saya},
        ],
        'items': [
          for (final it in items) {'nama': it.nama, 'qty': it.qty, 'harga': it.harga, 'peserta': it.peserta},
        ],
      };
}

/// Merchant QRIS saved for bills (`/pengaturan/qris`).
class QrisTersimpan {
  const QrisTersimpan({required this.payload, required this.merchant, required this.kota});

  factory QrisTersimpan.fromJson(Json j) => QrisTersimpan(payload: _str(j['payload']), merchant: _str(j['merchant']), kota: _str(j['kota']));

  final String payload;
  final String merchant;
  final String kota;
}
