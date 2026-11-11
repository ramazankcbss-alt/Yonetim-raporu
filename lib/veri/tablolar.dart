// Ekran ve PDF'te aynı görünen tabloların satırları.

import '../bicim.dart';
import 'model.dart';

const isletmeBasliklari = [
  'İşletme',
  'Personel',
  'Taşeron',
  'Hayvan',
  'Sağılan',
  'Süt (kg)',
  'Ort. Verim',
  'İnek/Düve Kesim-Satış',
  'Buzağı Ölümü',
  'Kesilen Dana',
];

List<String> _isletme(IsletmeSatiri s) => [
      s.ad,
      sayiTire(s.personel),
      sayiTire(s.taseron),
      sayiTire(s.hayvan),
      sayiTire(s.sagilan),
      sayiTire(s.sut),
      s.ortVerim > 0 ? sayi(s.ortVerim, ondalik: 1) : '—',
      sayiTire(s.kesimSatis),
      sayiTire(s.buzagiOlum),
      sayiTire(s.kesilenDana),
    ];

/// İşletmeler + Diğer + Çiftlikler Toplam (son satır).
List<List<String>> isletmeSatirlari(CanliHayvanOzeti o) =>
    [for (final s in o.satirlar) _isletme(s), _isletme(o.toplam)];

List<String> suruBasliklari(String ilk, String son) => [
      'Gösterge',
      'Fethiye $ilk',
      'Fethiye $son',
      'Fark',
      'Erentepe $ilk',
      'Erentepe $son',
      'Fark',
    ];

/// Fethiye ve Erentepe sürü/süt karşılaştırması (ilk → son gün).
List<List<String>> suruSatirlari(GunlukSatir? ilk, GunlukSatir? son) {
  const bos = Suru();
  final fi = ilk?.fethiye ?? bos, fs = son?.fethiye ?? bos;
  final ei = ilk?.erentepe ?? bos, es = son?.erentepe ?? bos;
  List<String> satir(String ad, double Function(Suru) f, {int ondalik = 0}) {
    String d(Suru s, GunlukSatir? g) =>
        g == null ? '—' : sayi(f(s), ondalik: ondalik);
    String fk(Suru a, Suru b) => ilk == null || son == null
        ? '—'
        : fark(f(b) - f(a), ondalik: ondalik);
    return [
      ad,
      d(fi, ilk),
      d(fs, son),
      fk(fi, fs),
      d(ei, ilk),
      d(es, son),
      fk(ei, es),
    ];
  }

  return [
    satir('Toplam hayvan', (s) => s.toplam),
    satir('Sağmal', (s) => s.sagmal),
    satir('Kuru gebe', (s) => s.kuruGebe),
    satir('Erkek', (s) => s.erkek),
    satir('Sağılan süt (kg)', (s) => s.sut),
    satir('Süt ortalaması (kg)', (s) => s.ortalama, ondalik: 2),
    satir('Satılan süt (kg)', (s) => s.satilan),
  ];
}

const gunlukSutBasliklari = [
  'Tarih',
  'Fethiye Süt',
  'Erentepe Süt',
  'Toplam Süt',
  'Sağmal',
  'Ort. Verim',
  'Satılan',
];

/// Haftanın günleri + Toplam satırı.
List<List<String>> gunlukSutSatirlari(List<GunlukSatir> gunler) {
  final satirlar = [
    for (final g in gunler)
      [
        '${tarihKisa(g.tarih)} ${gunKisa(g.tarih)}',
        sayi(g.fethiye.sut),
        sayi(g.erentepe.sut),
        sayi(g.sut),
        sayi(g.sagmal),
        g.sagmal > 0 ? sayi(g.sut / g.sagmal, ondalik: 1) : '—',
        sayi(g.satilan),
      ],
  ];
  if (gunler.isNotEmpty) {
    double t(double Function(GunlukSatir) f) =>
        gunler.fold(0.0, (a, g) => a + f(g));
    final sag = t((g) => g.sagmal);
    satirlar.add([
      'Hafta Toplamı',
      sayi(t((g) => g.fethiye.sut)),
      sayi(t((g) => g.erentepe.sut)),
      sayi(t((g) => g.sut)),
      sayi(sag),
      sag > 0 ? sayi(t((g) => g.sut) / sag, ondalik: 1) : '—',
      sayi(t((g) => g.satilan)),
    ]);
  }
  return satirlar;
}

const ekimBasliklari = ['Çiftlik', 'Ürün', 'Plan (da)', 'Ekilen (da)', '%'];

List<List<String>> ekimSatirlari(List<EkimSatir> ekim) {
  final (plan, ekilen) = ekimToplami(ekim);
  return [
    for (final e in ekim)
      [
        e.ciftlik,
        e.urun,
        sayi(e.plan),
        e.ekilen == null ? '—' : sayi(e.ekilen),
        e.oran == null ? '—' : '%${sayi(e.oran! * 100)}',
      ],
    [
      'GENEL TOPLAM',
      '',
      sayi(plan),
      sayi(ekilen),
      plan > 0 ? '%${sayi(ekilen / plan * 100)}' : '—',
    ],
  ];
}

const hasatBasliklari = [
  'Ürün',
  'Çiftlik',
  'Alan (da)',
  'Toplam (kg)',
  'Verim (kg/da)',
  'Kayıt Tarihi',
];

List<List<String>> hasatSatirlari(List<HasatSatir> hasat) => [
      for (final h in hasat)
        [
          h.urun,
          h.ciftlik,
          h.alan == null ? '—' : sayi(h.alan),
          h.toplam == null ? '—' : sayi(h.toplam),
          h.verim == null ? '—' : sayi(h.verim),
          h.tarih == null ? '—' : tarihKisa(h.tarih!),
        ],
    ];

const besiBasliklari = [
  'İşletme',
  'Yerli Dana',
  'Kesimi Planlanan Erkek Dana',
  'Kesimi Planlanan İnek',
];

List<List<String>> besiSatirlari(List<BesiSatir> besi) {
  double t(double Function(BesiSatir) f) => besi.fold(0.0, (a, b) => a + f(b));
  return [
    for (final b in besi)
      [b.isletme, sayiTire(b.yerli), sayiTire(b.erkek), sayiTire(b.inek)],
    if (besi.isNotEmpty)
      [
        'TOPLAM',
        sayi(t((b) => b.yerli)),
        sayi(t((b) => b.erkek)),
        sayi(t((b) => b.inek)),
      ],
  ];
}
