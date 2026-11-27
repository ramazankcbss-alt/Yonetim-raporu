import 'package:flutter/material.dart';

import '../bicim.dart';
import '../tema.dart';
import '../veri/esk_kaynak.dart';
import '../veri/model.dart';
import 'bilesenler.dart';
import 'esk.dart' show tl;

/// ESK › Kaynak tablolar: bakım hizmet alım tablosu, parti listesi, yem girişi ve ESK_Aylık ile mutabakat.
class EskKaynakGovde extends StatelessWidget {
  const EskKaynakGovde({super.key, required this.veri});
  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    final k = veri.eskKaynak;
    if (k.bos) {
      return const Padding(
          padding: EdgeInsets.all(16),
          child: BilgiKutusu(yazi: 'ESK kaynak tabloları henüz gelmedi. Apps Script güncel olmalı.'));
    }
    final mut = k.mutabakat(veri.eskAylik);
    final yem = k.yemAylik();
    final yemAylar = yem.keys.toList()..sort();
    final urunler = <String, double>{};
    for (final m in yem.values) {
      m.forEach((u, kg) => urunler[u] = (urunler[u] ?? 0) + kg);
    }
    final urunSira = urunler.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topKesim = k.aylar.fold(0.0, (t, a) => t + a.kesilen + a.sehirKesim);
    final topOlen = k.aylar.fold(0.0, (t, a) => t + a.olen);
    final topGelir = k.aylar.fold(0.0, (t, a) => t + (a.bakimGideri ?? 0));
    final gelen = k.partiler.fold(0.0, (t, p) => t + (p.ciftlik ?? 0));
    final nakliye = k.partiler.fold(0.0, (t, p) => t + (p.nakliyeOlen ?? 0));
    final hesapFark = [
      for (final a in k.aylar)
        if (a.hesaplananGider != null && a.bakimGideri != null && (a.hesaplananGider! - a.bakimGideri!).abs() > 1) a
    ];
    return ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 24), children: [
      const BilgiKutusu(
          yazi: 'Kaynak: ESK bakım hizmet alım tablosu (günlük kesim, ölüm, ahırdaki hayvan ve bakım bedeli), '
              'ithal erkek dana parti listesi ve gelen yem kayıtları. Yem kayıtlarından yalnızca tarih, ürün ve '
              'tonaj alınır; plaka, sürücü ve irsaliye bilgisi uygulamaya alınmaz.'),
      for (final h in k.hatalar)
        Padding(padding: const EdgeInsets.only(top: 6), child: BilgiKutusu(uyari: true, yazi: 'Okunamadı: $h')),
      const SizedBox(height: 8),
      GostergeIzgarasi(kartlar: [
        GostergeKarti(ikon: Icons.local_shipping_outlined, baslik: 'Gelen hayvan', deger: sayi(gelen),
            alt: '${k.partiler.length} parti · nakliyede ölen ${sayi(nakliye)}'),
        GostergeKarti(ikon: Icons.content_cut, baslik: 'Kesime giden', deger: sayi(topKesim), alt: '${k.aylar.length} ay'),
        GostergeKarti(ikon: Icons.warning_amber_outlined, baslik: 'Ölen', deger: sayi(topOlen),
            renk: Renk.kirmizi,
            alt: topKesim + topOlen > 0 ? '%${sayi(100 * topOlen / (topKesim + topOlen), ondalik: 2)} çıkışa göre' : null),
        GostergeKarti(ikon: Icons.payments_outlined, baslik: 'Bakım hizmet bedeli', deger: tl(topGelir),
            renk: Renk.yesil, alt: 'Panagro geliri'),
      ]),
      const BolumBasligi('Mutabakat: kaynak tablo – ESK aylık rapor', ikon: Icons.rule),
      if (veri.eskAylik.isEmpty)
        const BilgiKutusu(yazi: 'ESK_Aylık sayfası boş; karşılaştırma yapılamadı.')
      else if (mut.isEmpty)
        const BilgiKutusu(yazi: 'Hayvan-gün, kesim, ölüm ve bakım bedeli kaynak tabloyla aynı.')
      else
        VeriTablosu(
          basliklar: const ['Ay', 'Kalem', 'Kaynak', 'Rapor', 'Fark'],
          metinSutunlari: const {0, 1},
          ilkSutunGenislik: 110,
          satirlar: [
            for (final m in mut)
              [m.ay, m.kalem, sayi(m.kaynak), sayi(m.rapor), fark(m.fark)],
          ],
        ),
      if (hesapFark.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: BilgiKutusu(
              uyari: true,
              yazi: 'Bakım bedeli baş-gün × birim fiyattan farklı: '
                  '${hesapFark.map((a) => '${a.ad} (${tl(a.bakimGideri)} / hesaplanan ${tl(a.hesaplananGider)})').join(', ')}.'),
        ),
      const BolumBasligi('Aylık bakım hizmet tablosu', ikon: Icons.calendar_month),
      VeriTablosu(
        basliklar: const ['Ay', 'Baş-gün', 'Ort. baş', 'Kesim', 'Ölen', 'Birim', 'Bedel'],
        ilkSutunGenislik: 110,
        satirlar: [
          for (final a in k.aylar)
            [
              a.ad,
              sayi(a.basGun),
              sayi(a.basGun == null ? null : a.basGun! / DateUtils.getDaysInMonth(a.yil, a.ay)),
              sayi(a.kesilen + a.sehirKesim),
              sayi(a.olen),
              a.birimFiyat == null ? '—' : '${sayi(a.birimFiyat)} ₺',
              tl(a.bakimGideri),
            ],
        ],
      ),
      const BolumBasligi('İthal dana partileri', ikon: Icons.local_shipping_outlined,
          aciklama: 'Çiftliğe giren sayı ile ESK liman sayısı arasındaki fark ve nakliyede ölenler.'),
      VeriTablosu(
        basliklar: const ['Parti', 'Geliş', 'Çiftlik', 'Liman', 'Fark', 'Nakliye ölen'],
        metinSutunlari: const {0, 1},
        ilkSutunGenislik: 80,
        satirlar: [
          for (final p in k.partiler)
            [p.parti, p.gelis, sayi(p.ciftlik), sayi(p.liman), p.fark == null ? '—' : fark(p.fark!), sayi(p.nakliyeOlen, bos: '0')],
        ],
      ),
      if (yemAylar.isNotEmpty) ...[
        const BolumBasligi('Gelen yem (ton)', ikon: Icons.grass_outlined),
        VeriTablosu(
          basliklar: ['Ay', for (final u in urunSira.take(4)) u.key, 'Toplam'],
          ilkSutunGenislik: 90,
          satirlar: [
            for (final a in yemAylar)
              [
                a,
                for (final u in urunSira.take(4)) sayi((yem[a]![u.key] ?? 0) / 1000, ondalik: 1),
                sayi(yem[a]!.values.fold(0.0, (t, x) => t + x) / 1000, ondalik: 1),
              ],
          ],
        ),
      ],
    ]);
  }
}
