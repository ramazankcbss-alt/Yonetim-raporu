import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/arac_masraf.dart';
import '../veri/dosyalar.dart';
import '../veri/model.dart';
import 'bilesenler.dart';
import 'esk.dart' show tl;
import 'gonder.dart';

String? _sonMetin;
AracMasraflari? _son;

/// arac_masraf_2026 dosyası (sunucudan gelen uygulama verisi); yoksa null.
AracMasraflari? aracMasrafVerisi() {
  final m = UygulamaDosyalari.metin('arac_masraf_2026');
  if (m == null) return null;
  if (m != _sonMetin) {
    _sonMetin = m;
    try {
      _son = AracMasraflari.coz(m);
    } catch (_) {
      _son = null;
    }
  }
  return _son;
}

const _ayKisa = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
String _ay(String k) {
  final p = k.split('-');
  return p.length == 2 ? '${_ayKisa[int.parse(p[1]) - 1]} ${p[0].substring(2)}' : k;
}

/// Makine ve Bakım › Araç Masrafları: araç, üretim yeri ve ay kırılımında muhasebe gideri (KDV hariç).
class AracMasrafEkran extends StatelessWidget {
  const AracMasrafEkran({super.key, required this.veri});
  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: VeriDeposu.ben,
        builder: (context, _) {
          final d = aracMasrafVerisi();
          return Scaffold(
            appBar: AppBar(title: const Text('Araç Masrafları'), actions: const [TabloGuncelleButonu()]),
            body: d == null || d.bos
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: BilgiKutusu(
                        yazi: 'Araç masrafı verisi henüz gelmedi. Apps Script güncel olmalı '
                            '(arac_masraf_2026 dosyası).'))
                : GonderAlani(konu: 'Araç Masrafları', child: _Govde(d: d)),
          );
        },
      );
}

class _Govde extends StatelessWidget {
  const _Govde({required this.d});
  final AracMasraflari d;

  @override
  Widget build(BuildContext context) {
    final aylar = d.aylar;
    final uy = d.uretimYeriToplami().entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final tur = d.turToplami().entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final kiralik = d.araclar.where((a) => a.kiralik).fold(0.0, (t, a) => t + a.toplam);
    final fark = d.genelToplam == null ? 0.0 : d.araclarToplami - d.genelToplam!;
    return ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 24), children: [
      BilgiKutusu(
          yazi: 'Kaynak: Çiftlikler Araç Masrafları listesi (muhasebe, ${d.donem}). Tutarlar KDV hariç matrahtır; '
              'tamir-bakım, akaryakıt, araç kirası ve muayene giderlerini kapsar. Plaka ve tedarikçi bilgisi '
              'uygulamaya alınmaz.'),
      const SizedBox(height: 8),
      GostergeIzgarasi(kartlar: [
        GostergeKarti(ikon: Icons.payments_outlined, baslik: 'Dönem toplamı', deger: tl(d.araclarToplami), alt: '${d.araclar.length} araç'),
        GostergeKarti(
            ikon: Icons.calendar_month,
            baslik: 'Aylık ortalama',
            deger: tl(aylar.isEmpty ? null : d.araclarToplami / aylar.length),
            alt: '${aylar.length} ay'),
        GostergeKarti(ikon: Icons.key_outlined, baslik: 'Kiralık araçlar', deger: tl(kiralik), alt: 'kira dahil bakım giderleri'),
      ]),
      if (fark.abs() > 1)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: BilgiKutusu(
              uyari: true,
              yazi: 'Kaynak dosyadaki GENEL TOPLAM (${tl(d.genelToplam)}) araç satırlarının toplamından '
                  '${tl(fark.abs())} ${fark > 0 ? 'düşük' : 'yüksek'}; toplam formülüne dahil edilmeyen satır var. '
                  'Uygulama araç satırlarının toplamını esas alır.'),
        ),
      const BolumBasligi('Aylık gider', ikon: Icons.calendar_month),
      VeriTablosu(
        basliklar: const ['Ay', 'Tutar'],
        satirlar: [
          for (final a in aylar) [_ay(a), tl(d.ayToplami(a))],
          ['Toplam', tl(d.araclarToplami)],
        ],
        vurguluSonSatir: true,
      ),
      const BolumBasligi('Üretim yerine göre', ikon: Icons.place_outlined,
          aciklama: 'Aracın kayıtlı olduğu iş alanı; ortak giderler dağıtım anahtarıyla kollara paylaştırılır.'),
      VeriTablosu(
        basliklar: const ['Üretim yeri', 'Tutar', 'Pay'],
        satirlar: [
          for (final e in uy)
            [e.key, tl(e.value), '%${sayi(100 * e.value / d.araclarToplami, ondalik: 1)}'],
        ],
        ilkSutunGenislik: 190,
      ),
      const BolumBasligi('Araç türüne göre', ikon: Icons.category_outlined),
      VeriTablosu(
        basliklar: const ['Tür', 'Tutar'],
        satirlar: [for (final e in tur) [e.key, tl(e.value)]],
        ilkSutunGenislik: 190,
      ),
      const BolumBasligi('En yüksek giderli araçlar', ikon: Icons.agriculture_outlined),
      VeriTablosu(
        basliklar: const ['Araç', 'Üretim yeri', 'Tutar'],
        metinSutunlari: const {0, 1},
        ilkSutunGenislik: 190,
        satirlar: [
          for (final a in d.araclar)
            [a.arac, AracMasraflari.uretimYeriAdi(a.uretimYeri), tl(a.toplam)],
        ],
      ),
      const SizedBox(height: 8),
      const Text('Aynı ada sahip araçlar ayrı kayıtlardır (farklı araç kodları).',
          style: TextStyle(fontSize: 12, color: Renk.soluk)),
    ]);
  }
}
