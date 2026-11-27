// Piramit 11. adım: duyarlılık analizi. Temel değişkenlerden biri yüzde olarak değiştiğinde net sonucun
// ne kadar değişeceği. Baz tutarlar gerçek veriden hesaplanır (gelir / gider tabloları, Maliyet Takip,
// Tarımsal Faaliyet); varsayım değildir.
// KVKK: yalnızca kalem toplamları.

import 'dart:convert';

import 'gelir_gider.dart';
import 'maliyet_takip.dart';
import 'urun_karlilik.dart';

const _aylar = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

class DuyarlilikDegiskeni {
  const DuyarlilikDegiskeni(this.anahtar, this.ad, this.baz, this.donem, {this.gelir = true});
  final String anahtar, ad, donem;

  /// Baz tutar (₺).
  final double baz;

  /// Gelir kalemi mi (artış net sonucu artırır) yoksa gider mi.
  final bool gelir;

  double etki(double yuzde) => (gelir ? 1 : -1) * baz * yuzde / 100;
}

class DuyarlilikSenaryosu {
  const DuyarlilikSenaryosu(this.ad, this.yuzdeler);
  final String ad;
  final Map<String, double> yuzdeler;

  double etki(List<DuyarlilikDegiskeni> d) =>
      d.fold(0.0, (s, x) => s + x.etki(yuzdeler[x.anahtar] ?? 0));

  Map<String, Object> json() => {'ad': ad, 'yuzdeler': yuzdeler};

  static List<DuyarlilikSenaryosu> listeOku(String? metin) {
    if (metin == null || metin.isEmpty) return const [];
    try {
      return [
        for (final x in jsonDecode(metin) as List)
          DuyarlilikSenaryosu('${x['ad']}', {
            for (final e in (x['yuzdeler'] as Map).entries) '${e.key}': (e.value as num).toDouble(),
          }),
      ];
    } catch (_) {
      return const [];
    }
  }

  static String listeYaz(List<DuyarlilikSenaryosu> l) => jsonEncode([for (final s in l) s.json()]);
}

/// Hazır senaryo: süt fiyatı −%10 ve yem fiyatı +%15.
const kOrnekSenaryo = DuyarlilikSenaryosu('Süt −%10, yem +%15', {'sut_fiyat': -10, 'yem': 15});

List<DuyarlilikDegiskeni> duyarlilikDegiskenleri({required GelirGider faturalar, UrunKarlilik? tarim, MaliyetTakip? mt, int? yil}) {
  var y = yil ?? 0;
  if (y == 0) {
    for (final g in faturalar.gelir) {
      if (g.yil > y) y = g.yil;
    }
  }
  var sonAy = 0;
  double gelir(bool Function(GelirSatiri) f) {
    var t = 0.0;
    for (final g in faturalar.gelir) {
      if (g.yil == y && f(g)) {
        t += g.net;
        if (g.ay > sonAy) sonAy = g.ay;
      }
    }
    return t;
  }

  double gider(String kategori) {
    var t = 0.0;
    for (final g in faturalar.gider) {
      if (g.yil == y && g.kategori == kategori) {
        t += g.net;
        if (g.ay > sonAy) sonAy = g.ay;
      }
    }
    return t;
  }

  final sut = gelir((g) => g.urun == 'Çiğ süt');
  final yem = gider('Yem ve kaba yem'), yakit = gider('Akaryakıt'), gubre = gider('Gübre ve zirai ilaç');
  final donem = sonAy == 0 ? '$y' : 'Ocak–${_aylar[sonAy - 1]} $y, gelir / gider tabloları';
  final out = <DuyarlilikDegiskeni>[
    if (sut > 0) DuyarlilikDegiskeni('sut_fiyat', 'Çiğ süt fiyatı', sut, donem),
    if (yem > 0) DuyarlilikDegiskeni('yem', 'Yem ve kaba yem fiyatı', yem, donem, gelir: false),
    if (gubre > 0) DuyarlilikDegiskeni('gubre', 'Gübre ve zirai ilaç fiyatı', gubre, donem, gelir: false),
    if (yakit > 0) DuyarlilikDegiskeni('akaryakit', 'Akaryakıt fiyatı', yakit, donem, gelir: false),
  ];
  if (mt != null) {
    var isc = 0.0;
    for (final h in mt.hayvan) {
      if (h.yil == y) isc += h.iscilik ?? 0;
    }
    for (final o in mt.ortak) {
      if (o.yil == y) isc += o.iscilik ?? 0;
    }
    if (isc > 0) out.add(DuyarlilikDegiskeni('iscilik', 'İşçilik', isc, '$y, Maliyet Takip (hayvancılık + tarım ortak)', gelir: false));
  }
  if (tarim != null) {
    for (final u in tarim.urunler) {
      if (u.icKullanim || u.planSatis <= 0) continue;
      out.add(DuyarlilikDegiskeni('fiyat_${u.urun}', '${u.urun} fiyatı', u.planSatis, '${tarim.hasatYili} hasat sezonu, plan satış'));
    }
  }
  return out;
}
