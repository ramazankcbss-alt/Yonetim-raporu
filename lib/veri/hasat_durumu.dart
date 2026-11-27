// Hasat durumu: hasadı / teslimatı tamamlanan ürünler (sunucu › "Hasat Durumu" sayfası).
// Ürün "Tümü" o sezonun bütün ürünlerini kapsar.
import 'uretim_karlilik.dart' show TarimsalUretim;

class HasatKaydi {
  const HasatKaydi({required this.sezon, required this.urun, required this.tamam, this.tarih = ''});
  final int sezon;
  final String urun, tarih;
  final bool tamam;

  static List<HasatKaydi> liste(Object? j) => [
        if (j is List)
          for (final x in j)
            if (x is Map && x['sezon'] is num && '${x['urun'] ?? ''}'.trim().isNotEmpty)
              HasatKaydi(sezon: (x['sezon'] as num).toInt(), urun: '${x['urun']}'.trim(), tamam: x['tamam'] == true,
                  tarih: '${x['tarih'] ?? ''}'),
      ];
}

const kTumUrunler = 'Tümü';

/// Ürünün hasadı tamamlandı mı: ürüne özel kayıt önceliklidir; yoksa "Tümü" kaydına bakılır.
bool hasatTamam(List<HasatKaydi> l, int sezon, String urun) {
  final u = TarimsalUretim.urunAdi(urun);
  HasatKaydi? ozel, tum;
  for (final k in l) {
    if (k.sezon != sezon) continue;
    if (k.urun == kTumUrunler) {
      tum = k;
    } else if (TarimsalUretim.urunAdi(k.urun) == u) {
      ozel = k;
    }
  }
  return (ozel ?? tum)?.tamam ?? false;
}

/// "2026" ya da "2026-2027" başlığından sezon yılı.
int? sezonYili(String baslik) => int.tryParse(RegExp(r'20\d\d').firstMatch(baslik)?.group(0) ?? '');
