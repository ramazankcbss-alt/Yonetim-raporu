// Kaynak envanteri: piramidi besleyen bütün kaynak dosyaların her sayfası, sütunu ve notu
// (Apps Script › kaynakEnvanteriHazirla). Kullanılmayan sayfalar ve okunamayan dosyalar buradan görünür.
// KVKK: kişi bilgisi içeren sayfalar "kvkk" durumundadır ve açılmaz; kişi bilgisi sütunları maskelidir.

int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
double? _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');

/// Ana veri paketindeki kısa özet.
class KaynakEnvanterOzet {
  const KaynakEnvanterOzet({
    this.olusturma = '',
    this.tamam = true,
    this.dosya = 0,
    this.sayfa = 0,
    this.kullanilan = 0,
    this.kullanilmayan = 0,
    this.kvkk = 0,
    this.bos = 0,
    this.hata = 0,
    this.not = 0,
    this.formulHatasi = 0,
    this.liste = const [],
  });
  final String olusturma;
  final bool tamam;
  final int dosya, sayfa, kullanilan, kullanilmayan, kvkk, bos, hata, not, formulHatasi;

  /// [kaynak, dosya, sayfa, durum, açıklama]
  final List<List<String>> liste;
  bool get yok => dosya == 0;

  static KaynakEnvanterOzet json(Object? j) {
    if (j is! Map) return const KaynakEnvanterOzet();
    return KaynakEnvanterOzet(
      olusturma: '${j['olusturma'] ?? ''}',
      tamam: j['tamam'] != false,
      dosya: _i(j['dosya']),
      sayfa: _i(j['sayfa']),
      kullanilan: _i(j['kullanilan']),
      kullanilmayan: _i(j['kullanilmayan']),
      kvkk: _i(j['kvkk']),
      bos: _i(j['bos']),
      hata: _i(j['hata']),
      not: _i(j['not']),
      formulHatasi: _i(j['formulHatasi']),
      liste: [
        for (final r in (j['liste'] is List ? j['liste'] as List : const []))
          if (r is List) [for (final x in r) '$x'],
      ],
    );
  }
}

class KaynakSutun {
  const KaynakSutun(this.no, this.baslik, this.dolu, this.sayisal, this.toplam, this.hata, this.kvkk);
  final int no, dolu, sayisal, hata;
  final String baslik;
  final double? toplam;
  final bool kvkk;
}

class KaynakNot {
  const KaynakNot(this.hucre, this.not, this.metin);
  final String hucre, not;

  /// true: hücreye yazılmış açıklama; false: hücre notu.
  final bool metin;
}

class KaynakSayfa {
  const KaynakSayfa({
    required this.ad,
    this.satir = 0,
    this.sutun = 0,
    this.dolu = 0,
    this.hata = 0,
    this.baslikSatiri = 1,
    this.durum = '',
    this.kullanim = '',
    this.hataMetni = '',
    this.sutunlar = const [],
    this.notlar = const [],
  });
  final String ad, durum, kullanim, hataMetni;
  final int satir, sutun, dolu, hata, baslikSatiri;
  final List<KaynakSutun> sutunlar;
  final List<KaynakNot> notlar;

  String get durumAdi => switch (durum) {
        'kullaniliyor' => 'Piramitte kullanılıyor',
        'kullanilmiyor' => 'Okundu, piramitte henüz kullanılmıyor',
        'kvkk' => 'KVKK nedeniyle okunmuyor',
        'haric' => 'Kurum kararıyla kullanılmıyor',
        'bos' => 'Boş sayfa',
        'hata' => 'Okunamadı',
        _ => durum,
      };

  static KaynakSayfa json(Map j) => KaynakSayfa(
        ad: '${j['ad'] ?? ''}',
        satir: _i(j['satir']),
        sutun: _i(j['sutun']),
        dolu: _i(j['dolu']),
        hata: _i(j['hata']),
        baslikSatiri: _i(j['baslikSatiri'] ?? 1),
        durum: '${j['durum'] ?? ''}',
        kullanim: '${j['kullanim'] ?? ''}',
        hataMetni: '${j['hataMetni'] ?? ''}',
        sutunlar: [
          for (final c in (j['sutunlar'] is List ? j['sutunlar'] as List : const []))
            if (c is Map)
              KaynakSutun(_i(c['no']), '${c['baslik'] ?? ''}', _i(c['dolu']), _i(c['sayisal']), _d(c['toplam']), _i(c['hata']),
                  c['kvkk'] == true),
        ],
        notlar: [
          for (final n in (j['notlar'] is List ? j['notlar'] as List : const []))
            if (n is Map) KaynakNot('${n['hucre'] ?? ''}', '${n['not'] ?? ''}', n['metin'] == true),
        ],
      );
}

class KaynakDosya {
  const KaynakDosya({
    required this.id,
    required this.ad,
    this.guncelleme = '',
    this.tablo = true,
    this.hata = '',
    this.ayni = '',
    this.not = '',
    this.yarim = false,
    this.sayfalar = const [],
  });
  final String id, ad, guncelleme, hata, ayni, not;
  final bool tablo, yarim;
  final List<KaynakSayfa> sayfalar;

  static KaynakDosya json(Map j) => KaynakDosya(
        id: '${j['id'] ?? ''}',
        ad: '${j['ad'] ?? ''}',
        guncelleme: '${j['guncelleme'] ?? ''}',
        tablo: j['tablo'] != false,
        hata: '${j['hata'] ?? ''}',
        ayni: '${j['ayni'] ?? ''}',
        not: '${j['not'] ?? ''}',
        yarim: j['yarim'] == true,
        sayfalar: [
          for (final s in (j['sayfalar'] is List ? j['sayfalar'] as List : const []))
            if (s is Map) KaynakSayfa.json(s),
        ],
      );
}

class KaynakGrubu {
  const KaynakGrubu(this.ad, this.dosyalar, this.hata);
  final String ad, hata;
  final List<KaynakDosya> dosyalar;
}

class KaynakEnvanteri {
  const KaynakEnvanteri({this.olusturma = '', this.tamam = true, this.kaynaklar = const []});
  final String olusturma;
  final bool tamam;
  final List<KaynakGrubu> kaynaklar;

  static KaynakEnvanteri json(Object? j) {
    if (j is! Map) return const KaynakEnvanteri();
    return KaynakEnvanteri(
      olusturma: '${j['olusturma'] ?? ''}',
      tamam: j['tamam'] != false,
      kaynaklar: [
        for (final k in (j['kaynaklar'] is List ? j['kaynaklar'] as List : const []))
          if (k is Map)
            KaynakGrubu(
              '${k['ad'] ?? ''}',
              [
                for (final d in (k['dosyalar'] is List ? k['dosyalar'] as List : const []))
                  if (d is Map) KaynakDosya.json(d),
              ],
              '${k['hata'] ?? ''}',
            ),
      ],
    );
  }

  /// Bir kaynak grubundaki durum sayıları.
  static Map<String, int> sayac(KaynakGrubu k) {
    final m = <String, int>{};
    for (final d in k.dosyalar) {
      for (final s in d.sayfalar) {
        m[s.durum] = (m[s.durum] ?? 0) + 1;
      }
    }
    return m;
  }
}

/// Ayrı bir analize bağlanmamış kaynak sayfaları, bütün hücreleriyle (Apps Script › kaynakTablolari_).
class KaynakTablo {
  const KaynakTablo(this.grup, this.dosya, this.sayfa, this.bloklar);
  final String grup, dosya, sayfa;

  /// Boş satırlarla ayrılmış tablo blokları; her blok satırların listesi.
  final List<List<List<String>>> bloklar;
}

class KaynakTablolari {
  const KaynakTablolari({this.menuler = const {}, this.hatalar = const []});
  final Map<String, List<KaynakTablo>> menuler;
  final List<String> hatalar;

  List<KaynakTablo> menu(String m) => menuler[m] ?? const [];

  static KaynakTablolari json(Object? j) {
    if (j is! Map) return const KaynakTablolari();
    final m = <String, List<KaynakTablo>>{};
    final mj = j['menuler'];
    if (mj is Map) {
      mj.forEach((k, v) {
        m['$k'] = [
          for (final t in (v is List ? v : const []))
            if (t is Map)
              KaynakTablo('${t['grup'] ?? ''}', '${t['dosya'] ?? ''}', '${t['sayfa'] ?? ''}', [
                for (final b in (t['bloklar'] is List ? t['bloklar'] as List : const []))
                  if (b is Map)
                    [
                      for (final r in (b['satirlar'] is List ? b['satirlar'] as List : const []))
                        if (r is List) [for (final x in r) '$x'],
                    ],
              ]),
        ];
      });
    }
    return KaynakTablolari(menuler: m, hatalar: [for (final h in (j['hatalar'] is List ? j['hatalar'] as List : const [])) '$h']);
  }
}
