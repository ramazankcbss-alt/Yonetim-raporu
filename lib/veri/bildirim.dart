// Piramit 12. adım: bildirimler. Yalnızca karar gerektiren durumlar; kritikler telefona sistem bildirimi
// olarak da gönderilir, diğerleri uygulama içi bildirim merkezinde toplanır.
// KVKK: bildirim metinlerinde kişi adı, küpe numarası ve kişi bazında tutar yer almaz.

import 'karne_sapma.dart';
import 'stok_suru.dart';

enum BildirimOnceligi { kritik, ozet, bilgi }

String oncelikAdi(BildirimOnceligi o) =>
    switch (o) { BildirimOnceligi.kritik => 'Kritik', BildirimOnceligi.ozet => 'Günlük özet', BildirimOnceligi.bilgi => 'Bilgi' };

/// Bildirime dokununca açılacak ekran.
enum BildirimHedefi { yonetimOzeti, veriKalitesi, stokSuru, aylikRapor }

class UygulamaBildirimi {
  const UygulamaBildirimi(this.anahtar, this.baslik, this.metin, this.oncelik, this.hedef);

  /// Aynı durum için aynı kalan anahtar (tekrar bildirim gönderilmez).
  final String anahtar;
  final String baslik, metin;
  final BildirimOnceligi oncelik;
  final BildirimHedefi hedef;
}

const _aylar = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

List<UygulamaBildirimi> bildirimleriUret({
  required List<Sapma> sapmalar,
  required int yil,
  required int sonMuhasebeAyi,
  SuruHareketleri? suru,
  List<String> eskiKaynaklar = const [],
  List<String> eksikDonemler = const [],
  int acikKonu = 0,
  int? sonRaporlananAy,
}) {
  final out = <UygulamaBildirimi>[];
  // Kritik: birim maliyet satış fiyatının üstünde (son kesin ay)
  for (final s in sapmalar) {
    if (!s.alarm || s.yil != yil || s.ay != sonMuhasebeAyi) continue;
    out.add(UygulamaBildirimi('alarm|${s.ciftlik}|${s.yil}-${s.ay}|${s.baslik.split(':').first}', '${s.ciftlik}: ${s.baslik.split(':').first}',
        '${s.donem}. ${s.baslik.contains(':') ? s.baslik.split(':').last.trim() : ''}'.trim(), BildirimOnceligi.kritik, BildirimHedefi.yonetimOzeti));
  }
  // Günlük özet: son kesin aydaki sapmalar
  for (final s in sapmalar) {
    if (s.alarm || s.yil != yil || s.ay != sonMuhasebeAyi) continue;
    out.add(UygulamaBildirimi('sapma|${s.ciftlik}|${s.yil}-${s.ay}|${s.baslik.split(' ').take(2).join(' ')}', '${s.ciftlik}: sapma (${s.donem})',
        '${s.baslik}${s.nedenler.isEmpty ? '' : '. ${s.nedenler.first}'}', s.tekSeferlik ? BildirimOnceligi.bilgi : BildirimOnceligi.ozet,
        BildirimHedefi.yonetimOzeti));
  }
  // Kritik: sürü kaybı son 12 ayın ortalamasının belirgin üstünde
  if (suru != null) {
    for (final c in suru.ciftlikler) {
      final ay = suru.sonAy(c, yil);
      if (ay == 0) continue;
      final k = suru.kayip(c, yil, ay);
      final once = <double>[];
      for (var i = 1; i <= 12; i++) {
        final t = DateTime(yil, ay - i);
        if (suru.sonAy(c, t.year) >= t.month) once.add(suru.kayip(c, t.year, t.month));
      }
      if (once.length < 3) continue;
      final ort = once.reduce((a, b) => a + b) / once.length;
      if (k >= 5 && k > ort * 1.5) {
        out.add(UygulamaBildirimi('kayip|$c|$yil-$ay', '$c: hayvan kaybı arttı (${_aylar[ay - 1]})',
            '${k.toStringAsFixed(0)} baş (ölü doğum, abort, ölüm); son 12 ay ortalaması ${ort.toStringAsFixed(1)}.', BildirimOnceligi.kritik,
            BildirimHedefi.stokSuru));
      }
    }
  }
  for (final k in eskiKaynaklar) {
    out.add(UygulamaBildirimi('eski|$k', 'Kaynak güncellendi: $k', 'Uygulamadaki kopya eski; yenilenmesi gerekiyor.', BildirimOnceligi.ozet,
        BildirimHedefi.veriKalitesi));
  }
  for (final e in eksikDonemler) {
    out.add(UygulamaBildirimi('eksik|$e', 'Eksik dönem', e, BildirimOnceligi.ozet, BildirimHedefi.veriKalitesi));
  }
  if (acikKonu > 0) {
    out.add(UygulamaBildirimi('acik|$acikKonu', 'Personelde bekleyen düzeltmeler', '$acikKonu açık konu (dosyalar arası tutarsızlık).',
        BildirimOnceligi.bilgi, BildirimHedefi.veriKalitesi));
  }
  if (sonMuhasebeAyi > 0 && (sonRaporlananAy ?? 0) < yil * 12 + sonMuhasebeAyi) {
    out.add(UygulamaBildirimi('rapor|$yil-$sonMuhasebeAyi', '${_aylar[sonMuhasebeAyi - 1]} $yil aylık yönetim raporu hazırlanabilir',
        'Muhasebe ${_aylar[sonMuhasebeAyi - 1]} ayını kapattı; rapor Yönetim Özeti\'nden oluşturulur.', BildirimOnceligi.bilgi,
        BildirimHedefi.aylikRapor));
  }
  return out;
}
