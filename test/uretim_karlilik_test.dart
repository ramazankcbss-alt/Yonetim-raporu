// Test, ÇİFTLİK BAZINDA sayfasının doğru okunduğunu sınar; depo herkese açık olduğu için
// şirket rakamları test dosyasına konmaz (uygulama gerçek rakamları Excel'den okur).
import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/uretim_karlilik.dart';

List<Object> r(List<Object> l) => [...l, ...List.filled(13 - l.length, '')];

void main() {
  final veri = {
    'dosya': 'Örnek Tarımsal Faaliyet',
    'urunBasligi': '2026 YILI ÇİFTLİKLER TARIMSAL ÜRETİMİ',
    'satirlar': [
      r([2]),
      r(['ÖRNEK YILI ÜRETİMİ']),
      r(['İŞLETMELER', 'ÜRÜN ADI', 'ÜRÜN TİCARİ İSİM', 'EKİLEN DEKAR', 'DEKARA VERİM', 'ÇIKAN TONAJ', 'BİRİM',
        'TOPLAM SATIŞ', 'DEKAR MALİYETİ', 'KG MALİYETİ', 'TOPLAM MALİYET', 'NET']),
      r(['ŞEKERSÜT ', 'SİLAJLIK MISIR', ' Ç1', 100, 5000, 500000, 2, 1000000, 8000, 1.6, 800000, 200000]),
      r(['', 'BUĞDAY', ' Ç2', 200, 600, 120000, 10, 1200000, 7000, 11, 1400000, -200000]),
      r(['', 'TOPLAM', '', 300, '', '', '', 2200000, '', '', 2200000, 0]),
      r(['ASLIM ', 'SİLAJLIK MISIR', ' Ç3', 50, 4000, 200000, 2, 400000, 6000, 1.5, 300000, 100000]),
      r(['TAŞAĞIL - ORMANLIK', 'PANCAR', ' Ç4', 10, 8000, 80000, 5, 400000, 20000, 2.5, 200000, 200000]),
      r(['FİDANLIK', 'ARPA', ' Ç5', 20, 400, 8000, 15, 120000, 5000, 12.5, 100000, 20000]),
      r(['TOPLAM', '', '', 380, '', '', '', 3120000, '', '', 2800000, 320000]),
      r(['', 'NET KAZANÇ', 320000]),
      r(['', 'SAP BALYALARI', 50000]),
      r(['', 'KÜSPE BEDELİ']),
      r(['', 'TOPLAM KAZANÇ', 370000]),
    ],
  };

  test('çiftlik ve ürün bazında toplamlar', () {
    final u = TarimsalUretim.json(veri);
    expect(u.yilBasligi, '2026');
    expect(u.ciftlikler.map((c) => c.ciftlik).toList(), ['Şekersüt', 'Aslım', 'Taşağıl', 'Fidanlık']);
    final s = u.ciftlikler.first.toplam;
    expect([s.dekar, s.satis, s.maliyet, s.netKazanc], [300, 2200000, 2200000, 0]);
    final misir = u.urunler.firstWhere((k) => k.ad == 'Silajlık Mısır');
    expect([misir.dekar, misir.toplamVerim, misir.satis, misir.maliyet, misir.netKazanc],
        [150, 700000, 1400000, 1100000, 300000]);
    expect(misir.dekaraVerim, closeTo(4666.67, 0.01));
    expect(u.ciftlikler[2].urunler.single.alt, 'Ormanlık');
    final g = u.genelToplam;
    expect([g.dekar, g.satis, g.maliyet, g.netKazanc], [380, 3120000, 2800000, 320000]);
    expect(u.ekGelirler, [('SAP BALYALARI', 50000.0)]);
    expect(u.excelToplamKazanc, 370000);
  });

  test('veri yoksa boş', () {
    expect(TarimsalUretim.json(null).bos, true);
  });
}
