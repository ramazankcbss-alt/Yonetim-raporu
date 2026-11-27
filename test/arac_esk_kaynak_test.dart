// Sentetik veriyle araç masrafı ve ESK kaynak tablosu testleri (gerçek veri kullanılmaz).
import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/arac_masraf.dart';
import 'package:yonetim_raporu/veri/esk_kaynak.dart';
import 'package:yonetim_raporu/veri/model.dart';

void main() {
  test('araç masrafları: toplamlar, üretim yeri ve tür', () {
    final d = AracMasraflari.coz('{"donem":"01.2030–02.2030","araclar":['
        '{"arac":"TRAKTÖR A","uy":"1605","aylik":{"2030-01":100,"2030-02":50},"toplam":150},'
        '{"arac":"BİNEK (KİRALIK)","uy":"","aylik":{"2030-02":30},"toplam":30},'
        '{"arac":"MANITOU X","uy":"1611","aylik":{"2030-01":20},"toplam":20}],'
        '"kontrol":{"genel_toplam":180,"araclar_toplami":200}}');
    expect(d.araclar.first.arac, 'TRAKTÖR A');
    expect(d.aylar, ['2030-01', '2030-02']);
    expect(d.ayToplami('2030-02'), 80);
    expect(d.genelToplam, 180);
    expect(d.araclarToplami, 200);
    expect(d.uretimYeriToplami()['Üretim yeri belirtilmemiş'], 30);
    expect(d.uretimYeriToplami()['Ortak giderler (Tarımsal Alan)'], 20);
    expect(d.turToplami()['Traktör'], 150);
    expect(d.turToplami()['Yükleyici / iş makinesi'], 20);
    expect(d.araclar.where((a) => a.kiralik).length, 1);
  });

  test('ESK kaynak: ayrıştırma ve ESK_Aylık mutabakatı', () {
    final k = EskKaynak.json({
      'aylar': [
        {'yil': 2030, 'ay': 2, 'birimFiyat': 10, 'kesilen': 5, 'sehirKesim': 1, 'olen': 2, 'basGun': 100, 'bakimGideri': 1000},
        {'yil': 2030, 'ay': 1, 'birimFiyat': 10, 'kesilen': 3, 'olen': 0, 'basGun': 50, 'bakimGideri': 400},
      ],
      'partiler': [
        {'parti': '1. PARTİ', 'gelis': '01.01.2030', 'ciftlik': 12, 'liman': 10, 'nakliyeOlen': 1}
      ],
      'yem': [
        {'yil': 2030, 'ay': 1, 'urun': 'YEM A', 'kg': 2000},
        {'yil': 2030, 'ay': 1, 'urun': 'YEM A', 'kg': 500},
      ],
    });
    expect(k.aylar.first.ad, 'Ocak 2030');
    expect(k.aylar.first.hesaplananGider, 500);
    expect(k.aylar.last.olumOrani, closeTo(0.25, 1e-9));
    expect(k.partiler.single.fark, 2);
    expect(k.yemAylik()['2030-01']!['YEM A'], 2500);
    final m = k.mutabakat([
      const EskAy(ay: 'Ocak 2030', hayvanGun: 50, kesim: 3, olen: 0, bakim: 400),
      const EskAy(ay: 'Şubat 2030', hayvanGun: 100, kesim: 4, disKesim: 1, olen: 2, bakim: 1000),
    ]);
    expect(m.length, 1);
    expect(m.single.kalem, 'Panagro kesim');
    expect(m.single.fark, 1);
  });
}
