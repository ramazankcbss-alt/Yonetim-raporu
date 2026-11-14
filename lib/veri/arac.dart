// Araç Takip uygulamasının verisi (ayrı tablo; Kod.gs salt okunur aktarır).

String _m(Object? v) => (v ?? '').toString().trim();
double? _s(Object? v) {
  if (v is num) return v.toDouble();
  final t = _m(v).replaceAll(' ', '');
  if (t.isEmpty) return null;
  return double.tryParse(t.contains(',') && t.contains('.') ? t.replaceAll('.', '').replaceAll(',', '.') : t.replaceAll(',', '.'));
}

List<List<Object?>> _satirlar(Object? v) =>
    v is List ? v.whereType<List>().map((r) => r.cast<Object?>()).toList() : const [];

Object? _h(List<Object?> r, int i) => i < r.length ? r[i] : null;

/// "dd.MM.yyyy HH:mm" ya da "dd.MM.yyyy" → DateTime.
DateTime? zamanOku(String s) {
  final m = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})(?:\s+(\d{1,2}):(\d{2}))?').firstMatch(s.trim());
  if (m == null) return null;
  return DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!),
      int.parse(m[4] ?? '0'), int.parse(m[5] ?? '0'));
}

class AracKaydi {
  const AracKaydi(this.no, this.tur, this.model, this.plaka, this.ciftlik, this.sayac, this.durum);
  final String no, tur, model, plaka, ciftlik, durum;
  final double? sayac;
  static AracKaydi? oku(List<Object?> r) {
    final no = _m(_h(r, 0));
    if (no.isEmpty) return null;
    final d = _m(_h(r, 6));
    return AracKaydi(no, _m(_h(r, 1)), _m(_h(r, 2)), _m(_h(r, 3)), _m(_h(r, 4)), _s(_h(r, 5)), d.isEmpty ? 'Aktif' : d);
  }

  String get baslik => [no, tur].where((x) => x.isNotEmpty).join(' · ');
  String get alt => [model, plaka, ciftlik].where((x) => x.isNotEmpty).join(' · ');
}

class AracKullanim {
  const AracKullanim(this.r);
  final List<Object?> r;
  String get no => _m(_h(r, 0));
  String get tarih => _m(_h(r, 1));
  String get arac => _m(_h(r, 2));
  String get personel => _m(_h(r, 3));
  String get ciftlik => _m(_h(r, 5));
  String get baslangic => _m(_h(r, 6));
  String get bitis => _m(_h(r, 7));
  double? get sayac1 => _s(_h(r, 8));
  double? get sayac2 => _s(_h(r, 9));
  double? get saat => _s(_h(r, 10));
  String get is_ => _m(_h(r, 11));
  bool _yapildi(int i) => _m(_h(r, i)) == 'Yapıldı';
  String get not => _m(_h(r, 16));
  String get durum => _m(_h(r, 17));
  String get onaylayan => _m(_h(r, 18));
  String get sekil => _m(_h(r, 20));
  DateTime? get bas => zamanOku(baslangic);
  DateTime? get son => zamanOku(bitis);
  bool get devamEdiyor => durum == 'Devam ediyor';
  List<String> get eksikKontroller => devamEdiyor
      ? const []
      : [
          if (!_yapildi(12)) 'Gresleme',
          if (!_yapildi(13)) 'Hava filtresi',
          if (!_yapildi(14)) 'Motor yağı',
          if (!_yapildi(15)) 'Radyatör',
        ];
}

class AracBakimPlani {
  const AracBakimPlani(this.arac, this.bakim, this.periyot, this.son, this.sonTarih);
  final String arac, bakim, sonTarih;
  final double? periyot, son;
  static AracBakimPlani? oku(List<Object?> r) {
    final a = _m(_h(r, 0));
    if (a.isEmpty) return null;
    return AracBakimPlani(a, _m(_h(r, 1)), _s(_h(r, 2)), _s(_h(r, 3)), _m(_h(r, 4)));
  }
}

class AracBakimKaydi {
  const AracBakimKaydi(this.r);
  final List<Object?> r;
  String get tarih => _m(_h(r, 1));
  String get arac => _m(_h(r, 2));
  String get kayitTuru => _m(_h(r, 3));
  String get bakim => _m(_h(r, 4));
  double? get sayac => _s(_h(r, 5));
  String get is_ => _m(_h(r, 6));
  String get parca => _m(_h(r, 7));
  String get firma => _m(_h(r, 8));
  String get tutar => _m(_h(r, 9));
  String get belge => _m(_h(r, 10));
  String get giren => _m(_h(r, 11));
}

class AracAriza {
  const AracAriza(this.r);
  final List<Object?> r;
  String get no => _m(_h(r, 0));
  String get zaman => _m(_h(r, 1));
  String get arac => _m(_h(r, 2));
  String get bildiren => _m(_h(r, 3));
  String get ciftlik => _m(_h(r, 5));
  String get aciklama => _m(_h(r, 6));
  String get foto => _m(_h(r, 7));
  String get durum => _m(_h(r, 8));
  String get guncelleyen => _m(_h(r, 9));
  String get not => _m(_h(r, 11));
  String get kapanis => _m(_h(r, 12));
  bool get kapali => durum == 'Onarıldı' || durum == 'Geçersiz bildirim';

  /// Arızalı kalınan süre (gün); açık arızada bugüne kadar.
  int? get gun {
    final b = zamanOku(zaman);
    if (b == null) return null;
    final k = zamanOku(kapanis) ?? DateTime.now();
    return k.difference(b).inHours ~/ 24;
  }
}

class AracMutabakat {
  const AracMutabakat(this.r);
  final List<Object?> r;
  String get tarih => _m(_h(r, 0));
  String get sonuc => _m(_h(r, 1));
  String get arac => _m(_h(r, 2));
  String get konu => _m(_h(r, 3));
  String get aciklama => _m(_h(r, 4));
  String get kaynaklar => _m(_h(r, 5));
  String get personel => _m(_h(r, 6));
}

/// Periyodik bakım durumu (plan + güncel sayaç).
class BakimDurumu {
  const BakimDurumu(this.arac, this.plan, this.kalan);
  final AracKaydi arac;
  final AracBakimPlani plan;
  final double kalan;
  bool get gecikti => kalan < 0;
}

class AracVerisi {
  const AracVerisi({
    this.araclar = const [],
    this.kullanim = const [],
    this.plan = const [],
    this.bakim = const [],
    this.ariza = const [],
    this.mutabakat = const [],
  });

  factory AracVerisi.json(Map<String, dynamic> j) => AracVerisi(
        araclar: _satirlar(j['aracListe']).map(AracKaydi.oku).whereType<AracKaydi>().toList(),
        kullanim: _satirlar(j['aracKullanim']).map(AracKullanim.new).where((x) => x.no.isNotEmpty).toList(),
        plan: _satirlar(j['aracPlan']).map(AracBakimPlani.oku).whereType<AracBakimPlani>().toList(),
        bakim: _satirlar(j['aracBakim']).map(AracBakimKaydi.new).where((x) => x.arac.isNotEmpty).toList(),
        ariza: _satirlar(j['aracAriza']).map(AracAriza.new).where((x) => x.no.isNotEmpty).toList(),
        mutabakat: _satirlar(j['aracMutabakat']).map(AracMutabakat.new).where((x) => x.sonuc.isNotEmpty).toList(),
      );

  final List<AracKaydi> araclar;
  final List<AracKullanim> kullanim;
  final List<AracBakimPlani> plan;
  final List<AracBakimKaydi> bakim;
  final List<AracAriza> ariza;
  final List<AracMutabakat> mutabakat;

  bool get bos => araclar.isEmpty && kullanim.isEmpty;

  AracKaydi? arac(String no) {
    for (final a in araclar) {
      if (a.no == no) return a;
    }
    return null;
  }

  List<AracKullanim> get aktif => kullanim.where((x) => x.devamEdiyor).toList();

  /// Bir aracın kullanım geçmişi, yeniden eskiye.
  List<AracKullanim> aracGecmisi(String no) {
    final l = kullanim.where((x) => x.arac == no).toList();
    l.sort((a, b) => (b.bas ?? DateTime(0)).compareTo(a.bas ?? DateTime(0)));
    return l;
  }

  /// Bir personelin kullanım geçmişi, yeniden eskiye.
  List<AracKullanim> personelGecmisi(String ad) {
    final l = kullanim.where((x) => x.personel == ad).toList();
    l.sort((a, b) => (b.bas ?? DateTime(0)).compareTo(a.bas ?? DateTime(0)));
    return l;
  }

  List<String> get personeller => {for (final x in kullanim) x.personel}.where((s) => s.isNotEmpty).toList()..sort();

  /// Olay Sorgulama: verilen anda aracı kullanan, ondan önceki ve sonraki kullanıcı.
  ({AracKullanim? once, AracKullanim? sirada, AracKullanim? sonra}) olaySorgula(String no, DateTime an) {
    final l = aracGecmisi(no).reversed.toList(); // eskiden yeniye
    AracKullanim? once, sirada, sonra;
    for (final x in l) {
      final b = x.bas;
      if (b == null) continue;
      final s = x.son ?? DateTime.now();
      if (!b.isAfter(an) && !s.isBefore(an)) {
        sirada = x;
      } else if (s.isBefore(an)) {
        once = x;
      } else if (b.isAfter(an) && sonra == null) {
        sonra = x;
      }
    }
    return (once: once, sirada: sirada, sonra: sonra);
  }

  /// Periyodik bakımı gecikmiş ya da yaklaşmış araçlar (kalan ≤ %10 periyot, en az 25 saat).
  List<BakimDurumu> bakimUyarilari() {
    final out = <BakimDurumu>[];
    for (final p in plan) {
      final a = arac(p.arac);
      if (a == null || a.durum == 'Pasif' || a.sayac == null || p.periyot == null) continue;
      final kalan = (p.son ?? 0) + p.periyot! - a.sayac!;
      final esik = p.periyot! * 0.1 > 25 ? p.periyot! * 0.1 : 25;
      if (kalan <= esik) out.add(BakimDurumu(a, p, kalan));
    }
    out.sort((x, y) => x.kalan.compareTo(y.kalan));
    return out;
  }
}
