import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/gelir_gider.dart';
import 'package:yonetim_raporu/veri/maliyet_takip.dart';
import 'package:yonetim_raporu/veri/urun_karlilik.dart';
import 'package:yonetim_raporu/veri/uretim_karlilik.dart';

// Yalnızca test için yapay örnek veri; gerçek şirket rakamı içermez.
void main() {
  final plan = TarimsalUretim.json({
    'dosya': 'Örnek Faaliyet',
    'urunBasligi': '2040 ÜRÜN BAZINDA',
    'satirlar': [
      ['İŞLETMELER', 'ÜRÜN', 'ÇEŞİT', 'DEKAR'],
      ['ASLIM', 'BUĞDAY', 'A', 100, 500, 50000, 10, 500000, 0, 0, 300000, 200000],
      ['', 'PANCAR', 'B', 100, 8000, 800000, 2, 1600000, 0, 0, 900000, 700000],
      ['FİDANLIK', 'ARPA', 'C', 200, 400, 80000, 5, 400000, 0, 0, 350000, 50000],
      ['', 'NET KAZANÇ', 950000],
      ['', 'SAP BALYALARI', 1000],
    ],
  });
  final mt = MaliyetTakip.coz(jsonEncode({
    'kaynak': 'Örnek MT',
    'hayvancilik': [],
    'tarim_ortak': [
      {'yil': 2039, 'ay': 9, 'iscilik': 100000, 'amortisman': 50000, 'diger': 50000},
      {'yil': 2040, 'ay': 5, 'iscilik': 100000, 'amortisman': 0, 'diger': 100000},
    ],
    'tarim_ekilis': [
      {'ciftlik': 'Aslım', 'urun': 'Buğday', 'dekar': 100, 'aylik': {'2039-11': 100000, '2040-07': 150000}, 'toplam': 250000},
      {'ciftlik': 'Aslım', 'urun': 'Şeker pancarı', 'dekar': 110, 'aylik': {'2040-04': 700000}, 'toplam': 700000},
    ],
    'sut_litre': [],
    'karkas': [],
    'canli': [],
    'yem': [],
    'yem_genel': [],
    'kontrol': {
      'ref_hatalari': [],
      'ozet_ref': 0,
      'toplam_2025_pangev_kopya': 0,
      'sut_tablo_disi_hucre': [],
      'yem_toplama_alinmayan': [],
      'tarim_ortak_toplam_yazili': 350000,
    },
  }));
  final gelir = GelirGider.json({
    'gelir': [
      [2040, 8, 'Tarımsal Alan', 'Buğday', 'Grup dışı', 'KG', 48000, 480000, 528000],
      [2040, 2, 'Tarımsal Alan', 'Şeker pancarı', 'Grup dışı', 'KG', 100000, 30000, 33000],
      [2040, 10, 'Tarımsal Alan', 'Şeker pancarı', 'Grup dışı', 'KG', 400000, 800000, 880000],
      [2040, 7, 'Taşağıl (ESK)', 'Sap balyası', 'Grup içi', 'KG', 1000, 5000, 5500],
      [2040, 7, 'Şekersüt', 'Çiğ süt', 'Grup içi', 'L', 1000, 9000, 9900],
    ],
  });

  test('maliyet takibindeki gerçekleşen maliyet, yoksa plan tahmini kullanılır', () {
    final k = UrunKarlilik.hesapla(plan: plan, mt: mt, gelir: gelir);
    expect(k.hasatYili, 2040);
    final b = k.urunler.firstWhere((u) => u.urun == 'Buğday');
    final p = k.urunler.firstWhere((u) => u.urun == 'Şeker Pancarı');
    final a = k.urunler.firstWhere((u) => u.urun == 'Arpa');
    expect(b.maliyet, 250000);
    expect(p.maliyet, 700000);
    expect(a.maliyet, 350000);
    expect(a.tahminiMaliyetVar, isTrue);
    expect(b.tahminiMaliyetVar, isFalse);
    // Ortak giderler kalemlerin toplamı (400.000), dosyadaki TOPLAM 350.000 → fark işaretlenir
    expect(k.ortakToplam, 400000);
    expect(k.ortakFark, 50000);
    // Dekara göre: 400 da toplam → buğday %25
    expect(b.ortakPay, 100000);
    expect(b.netKar, 500000 - 250000 - 100000);
    expect(k.netKar, closeTo(2500000 - 1300000 - 400000, 0.001));
    expect(k.alanFarklari, [('Şeker Pancarı', 'Aslım', 100.0, 110.0)]);
  });

  test('faturalar sezona göre ayrılır; ürün dışı tarım geliri ayrı listelenir', () {
    final k = UrunKarlilik.hesapla(plan: plan, mt: mt, gelir: gelir);
    final b = k.urunler.firstWhere((u) => u.urun == 'Buğday');
    final p = k.urunler.firstWhere((u) => u.urun == 'Şeker Pancarı');
    expect(b.faturaKg, 48000);
    expect(b.faturaTutar, 480000);
    expect(p.faturaTutar, 800000);
    expect(p.oncekiTutar, 30000);
    expect(p.faturalanmamis, 800000);
    expect(k.faturaTutar, 1280000);
    expect(k.digerGelir, [('Sap balyası', 'Taşağıl (ESK)', 5000.0)]);
  });

  test('ortak giderler doğrudan maliyete göre de dağıtılabilir', () {
    final k = UrunKarlilik.hesapla(plan: plan, mt: mt, gelir: gelir, anahtar: OrtakAnahtar.maliyet);
    final p = k.urunler.firstWhere((u) => u.urun == 'Şeker Pancarı');
    expect(p.ortakPay, closeTo(400000 * 700000 / 1300000, 0.001));
    expect(k.ortakPay, closeTo(400000, 0.001));
  });

  test('işletme içinde kullanılan yem bitkileri plan fiyatıyla değerlenir', () {
    final k = UrunKarlilik.hesapla(plan: plan, mt: mt, gelir: gelir);
    final a = k.urunler.firstWhere((u) => u.urun == 'Arpa');
    expect(a.icKullanim, isTrue);
    expect(a.icKg, 80000);
    expect(a.icPiyasaDegeri, 400000);
    expect(a.icMaliyet, 350000);
    expect(k.icPiyasaDegeri, 400000);
    expect(k.urunler.firstWhere((u) => u.urun == 'Buğday').icKg, 0);
    expect(k.muhasebeVar, isFalse);
    // Maliyet bedeliyle: iç kullanılan arpa doğrudan maliyetiyle (350.000) satış sayılır; ortak pay 200.000
    expect(a.icTransferMaliyeti, 350000);
    expect(a.netKarMaliyetBedeli, 350000 - 350000 - 200000);
    expect(a.netKar, 400000 - 350000 - 200000);
  });
}
