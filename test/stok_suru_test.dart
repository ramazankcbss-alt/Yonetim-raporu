import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/stok_suru.dart';

// Yalnızca test için yapay örnek veri; gerçek şirket rakamı içermez.
List<Object> _ay(List<num> l) => ['', ...l.map((x) => '$x'), ...List.filled(12 - l.length, '')];

void main() {
  test('sürü hareketleri: çiftlik başlıkları ve kalemler ayrılır', () {
    final s = SuruHareketleri.json({
      'dosya': 'SÜRÜ',
      'sayfalar': {
        '2040': [
          ['', 'not'],
          ['', 'Ocak 2040', 'Şubat 2040'],
          ['ŞEKERSÜT'],
          ['TÜM SÜRÜ', ..._ay([100, 110]).skip(1)],
          ['SAĞMAL', ..._ay([40, 42]).skip(1)],
          ['ÖLÜ DOĞUM', ..._ay([1, 0]).skip(1)],
          ['ABORT', ..._ay([2, 1]).skip(1)],
          ['ÖLEN BUZAĞI', ..._ay([1, 1]).skip(1)],
          ['İNEK KESİM', ..._ay([3, 0]).skip(1)],
          ['NORMAL DANA KESİM', ..._ay([5, 0]).skip(1)],
          [],
          ['PANGEV'],
          ['TÜM SÜRÜ', ..._ay([50, 51]).skip(1)],
          ['TAŞAĞIL', '0', '0'],
          ['TÜM SÜRÜ', ..._ay([0, 0]).skip(1)],
        ],
      },
    });
    expect(s.ciftlikler, ['Şekersüt', 'Pan-Gev', 'Taşağıl']);
    expect(s.deger('Şekersüt', 2040, 2, 'TÜM SÜRÜ'), 110);
    expect(s.deger('Pan-Gev', 2040, 1, 'TÜM SÜRÜ'), 50);
    expect(s.sonAy('Şekersüt', 2040), 2);
    expect(s.kayip('Şekersüt', 2040, 1), 4);
    expect(s.kesim('Şekersüt', 2040, 1), 8);
  });

  test('stok sayımı: başlığa göre sütunlar, birim ve grup', () {
    final s = StokSayimi.json({
      'dosya': 'Çiftlikler : 2040 Mart Stok Sayımları Ve Tüketimleri',
      'sayfalar': {
        '1613': [
          ['ÜY', 'DY', 'MALZ KOD', '', 'MALZ', 'ÖB', 'STOK', 'SAYIM', 'ANAÇ TÜKETİM', 'GENÇ TÜKETİM'],
          ['1613', '1', '1', 'YEMLER', 'MISIR SILAJI', 'KG', '', '7000000'],
          ['1613', '1', '2', 'İLAÇ AŞI', 'ÖRNEK İLAÇ', 'ADT', '10', '6', '3', '1'],
        ],
        '1611': [
          ['ÜY', 'DY', 'MALZ KOD', 'MALZ', 'ÖB', '', 'SAYIM'],
          ['1611', '5', '3', 'TOHUM ARPA', '1.250', 'KG', '1.250'],
        ],
      },
    });
    expect(s.donem, '2040 Mart');
    final a = s.sayfalar['1613']!;
    expect(a.first.grup, 'YEMLER');
    expect(a.first.sayim, 7000000);
    expect(a.last.anacTuketim, 3);
    expect(s.sayfalar['1611']!.first.sayim, 1250);
    expect(s.sayfalar['1611']!.first.birim, 'KG');
    expect(s.toplam('1613', (x) => x.ad.contains('SILAJ')), 7000000);
  });
}
