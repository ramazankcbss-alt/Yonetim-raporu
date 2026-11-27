import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/ciftlik_rapor.dart';
import 'package:yonetim_raporu/veri/gelir_gider.dart';
import 'package:yonetim_raporu/veri/havuz.dart';

// Yalnızca test için yapay örnek veri; gerçek şirket rakamı içermez.
Map<String, double> _ay(double ns, double smm, double fg, double net) => {
      'Net satışlar|1': ns,
      'Satışların maliyeti|1': smm,
      'Faaliyet giderleri|1': fg,
      'Dönem net kârı/zararı|1': net,
    };

Map<String, dynamic> _ciftlik(String ad, List<Map<String, double>> aylar) => {
      'ciftlik': ad,
      'sayfa': '',
      'kalemler': [],
      'aylik': [],
      'donemler': {
        '2040': {
          'ay_sayisi': aylar.length,
          'aylik': [
            for (var i = 0; i < aylar.length; i++) {'ay_no': i + 1, ...aylar[i]},
          ],
        },
      },
    };

void main() {
  final muhasebe = CiftlikRaporu.coz(jsonEncode({
    'baslik': 'Örnek',
    'kaynak': 'örnek.xlsx',
    'donem': 'Ocak–Üçüncü ay 2040',
    'gelir': [],
    'aylik': [
      for (var m = 1; m <= 3; m++) {'ciftlik': 'ESK-Taşağıl (Besi hizmeti)', 'yil': 2040, 'ay_no': m, 'ay': 'x', 'net_kar': 100.0, 'brut_kar': 0},
    ],
    'birim': [],
    'tarim': [
      {'ciftlik': 'Tarımsal Alan', 'urun': 'Buğday', 'yil': 2040, 'satis_kg': 100, 'satis_tl': 1000, 'smm_kg': 100, 'smm_tl': 600},
    ],
    'tesvik': [],
    'senaryo': {
      'aciklama': '',
      'donem': '',
      'kontrol': [],
      'ciftlikler': [
        _ciftlik('Çiftliklerimiz (ESK hariç)', [_ay(0, 0, 0, 1300), _ay(0, 0, 0, 1300), _ay(0, 0, 0, 1300)]),
        _ciftlik('Şekersüt', [_ay(1000, 900, 10, 200), _ay(1000, 900, 10, 200), _ay(1000, 900, 10, 200)]),
        _ciftlik('Tarımsal Alan', [_ay(500, 300, 0, 1100), _ay(500, 300, 0, 1100), _ay(500, 300, 0, 1100)]),
      ],
    },
  }));

  final faturalar = GelirGider.json({
    'gider': [
      for (var m = 1; m <= 4; m++) [2040, m, 'Şekersüt', 'Yem ve kaba yem', 'Grup dışı', 600, 660],
      [2040, 2, 'Şekersüt', 'Canlı hayvan alımı', 'Grup dışı', 5000, 5500],
      [2040, 3, 'Şekersüt', 'Gübre ve zirai ilaç', 'Grup dışı', 50, 55],
      [2040, 1, 'Tarımsal Alan', 'Gübre ve zirai ilaç', 'Grup dışı', 2000, 2200],
    ],
    'gelir': [
      for (var m = 1; m <= 3; m++) [2040, m, 'Şekersüt', 'Çiğ süt', 'Grup dışı', 'L', 10, 950, 1000],
      [2040, 4, 'Şekersüt', 'Çiğ süt', 'Grup dışı', 'L', 10, 1050, 1100],
      for (var m = 1; m <= 3; m++) [2040, m, 'Tarımsal Alan', 'Buğday', 'Grup dışı', 'KG', 50, 500, 550],
      [2040, 4, 'Tarımsal Alan', 'Buğday', 'Grup dışı', 'KG', 200, 2000, 2200],
      [2040, 4, 'Taşağıl (ESK)', 'ESK hayvan bakım hizmeti', 'Grup içi', 'ADT', 1, 400, 440],
    ],
  });

  final h = GelirGiderHavuzu.hesapla(faturalar: faturalar, muhasebe: muhasebe, mtKgMaliyet: const {'Buğday': 8});

  test('muhasebe ayları kesindir ve muhasebe konsolide net kârına eşittir', () {
    expect(h.yil, 2040);
    expect(h.sonMuhasebeAyi, 3);
    expect(h.sonFaturaAyi, 4);
    expect(h.toplam().kesinNet, 3 * (200 + 1100));
    expect(h.konsolideFark, 0);
    final a = h.aylar['Şekersüt']![0];
    expect(a.kesin, isTrue);
    expect(a.gider, 910);
    expect(a.faaliyetDisi, 200 - (1000 - 910));
  });

  test('hayvancılık tahmini: fatura geliri + ortalama fark, gider muhasebe ortalaması', () {
    final a = h.aylar['Şekersüt']![3];
    expect(a.kesin, isFalse);
    expect(a.gelir, 1050 + 50);
    expect(a.gider, 910);
    expect(a.net, 190);
  });

  test('tarım tahmini: satılan kg × muhasebe birim maliyeti', () {
    final a = h.aylar['Tarımsal Alan']![3];
    expect(a.gelir, 2000);
    expect(a.gider, 200 * 6);
    expect(h.tarimBirimMaliyet['Buğday']!.$2, 'Muhasebe');
  });

  test('yatırım ayrılır, kol uyuşmazlığı işaretlenir, ESK ayrı tutulur', () {
    expect(h.yatirimToplami, 5000);
    expect(h.aylar['Şekersüt']![1].faturaGider, 600);
    expect(h.kolUyusmazliklari[('Şekersüt', 'Gübre ve zirai ilaç')], 50);
    expect(h.esk[0].net, 100);
    expect(h.esk[3].net, 100);
    expect(h.toplam(kol: Kol.ziraat).kesinNet, 3300);
  });

  test('mutabakat: muhasebe ve fatura farkı', () {
    final m = h.mutabakat.firstWhere((x) => x.ciftlik == 'Şekersüt');
    expect(m.gelirFarki, 3 * 50);
    expect(m.giderFarki, 3 * 910 - (3 * 600 + 50));
  });

  test('olağandışı fatura geliri tahmine katılmaz', () {
    final f = GelirGider.json({
      'gider': [],
      'gelir': [
        [2040, 4, 'Şekersüt', 'Canlı hayvan', 'Grup dışı', 'ADT', 5, 9000, 9900],
      ],
    });
    final x = GelirGiderHavuzu.hesapla(faturalar: f, muhasebe: muhasebe);
    final a = x.aylar['Şekersüt']![3];
    expect(a.olagandisiGelir, 9000);
    expect(a.gelir, 1000);
  });
}
