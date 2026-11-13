import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/ozel.dart';

void main() {
  test('OzelVeri.json tüm bölümleri okur', () {
    final o = OzelVeri.json({
      'ozelNotlar': [
        ['11.11.2026', 'Uyuşmazlık', 'ESK farkı', 'Açıklama', 'Gmail'],
      ],
      'danismanlik': [
        ['11.11.2026', 'Vade', 'Ne yapmalı?', 'Yeni', '', ''],
        ['10.11.2026', 'Fiyat', 'Soru', 'Yanıtlandı', '11.11.2026', 'Şöyle yap', 3],
      ],
      'toplanti': [
        ['11.11.2026', 'Ofis', 'Ali, Veli', 'Bütçe', 'Konuşulanlar', '', ''],
      ],
      'gunluk': [
        ['11.11.2026', 'Başlık', 'İçerik', ''],
      ],
    });
    expect(o.ozelNotlar.single.tur, 'Uyuşmazlık');
    expect(o.ozelNotlar.single.tarih, DateTime(2026, 11, 11));
    expect(o.danismanlik.length, 2);
    expect(o.danismanlik.first.yanitlandi, isFalse);
    expect(o.danismanlik[1].yanitlandi, isTrue);
    expect(o.danismanlik[1].yanit, 'Şöyle yap');
    expect(o.danismanlik.first.satir, isNull);
    expect(o.danismanlik[1].satir, 3);
    expect(o.toplanti.single.yer, 'Ofis');
    expect(o.toplanti.single.katilimcilar, 'Ali, Veli');
    expect(o.gunce.single.baslik, 'Başlık');
    expect(o.gunce.single.icerik, 'İçerik');
  });

  test('Boş satırlar atlanır, eksik bölüm boş olur', () {
    final o = OzelVeri.json({
      'ozelNotlar': [
        ['', '', '', '', ''],
      ],
      'danismanlik': [
        ['11.11.2026', '', '', '', '', ''],
      ],
    });
    expect(o.ozelNotlar, isEmpty);
    expect(o.danismanlik, isEmpty);
    expect(o.toplanti, isEmpty);
    expect(o.gunce, isEmpty);
  });

  test('Kişi olayı: savunma değerlendirmesi ayrılır, mesaj metnine girmez', () {
    final o = KisiOlayi.oku(['13.11.2026', 'Ali Veli', 'Savunma', 'Isıtıcı',
        'Savunma alındı.\n⚖ Değerlendirme: Kısmen haklı — Fotoğrafta cihaz yanmış.\n📘 Hukuki ön bilgi: En fazla yazılı uyarı.',
        'Olumsuz', '', 'E-posta', 'x1'])!;
    expect(o.olayMetni, 'Savunma alındı.');
    expect(o.degerlendirme!.sonuc, 'Kısmen haklı');
    expect(o.degerlendirme!.gerekce, 'Fotoğrafta cihaz yanmış.');
    expect(o.degerlendirme!.hukuki, 'En fazla yazılı uyarı.');
    final y = KisiOlayi.oku(['13.11.2026', 'Ali Veli', 'Tutanak', 'X', 'Düz metin', 'Olumsuz'])!;
    expect(y.degerlendirme, isNull);
    expect(y.olayMetni, 'Düz metin');
  });
}
