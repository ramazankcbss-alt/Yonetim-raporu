import 'package:flutter/material.dart';

import '../bicim.dart';
import '../tema.dart';
import '../veri/esk_kaynak.dart';
import '../veri/model.dart';
import 'bilesenler.dart';
import 'esk.dart' show tl;

const _ay = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
String _ayK(String k) {
  final p = k.split('-');
  return p.length == 2 ? '${_ay[int.parse(p[1]) - 1]} ${p[0].substring(2)}' : k;
}

String _ton(double kg) => sayi(kg / 1000, ondalik: 1);

/// ESK › Kaynak tablolar: bakım hizmet tablosu, kesim/ölüm listeleri, gelişler, yem-balya-gübre, gelir tablosu.
class EskKaynakGovde extends StatelessWidget {
  const EskKaynakGovde({super.key, required this.veri});
  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 5,
        child: Column(children: [
          const Material(
            color: Colors.white,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Renk.anaKoyu,
              unselectedLabelColor: Renk.soluk,
              indicatorColor: Renk.ana,
              tabs: [
                Tab(text: 'Özet ve mutabakat'),
                Tab(text: 'Kesim ve ölüm'),
                Tab(text: 'Gelişler'),
                Tab(text: 'Yem, balya, gübre'),
                Tab(text: 'Gelir tablosu'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(children: [
              _Ozet(veri: veri),
              _KesimOlum(veri: veri),
              _Gelisler(veri: veri),
              _YemBalyaGubre(veri: veri),
              _GelirTablosu(veri: veri),
            ]),
          ),
        ]),
      );
}

class _Ozet extends StatelessWidget {
  const _Ozet({required this.veri});
  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    final k = veri.eskKaynak;
    if (k.bos) {
      return const Padding(
          padding: EdgeInsets.all(16),
          child: BilgiKutusu(yazi: 'ESK kaynak tabloları henüz gelmedi. Apps Script güncel olmalı.'));
    }
    final mut = [...k.mutabakat(veri.eskAylik), ...veri.eskEk.mutabakat(k, veri.eskAylik)];
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
      for (final h in [...k.hatalar, ...veri.eskEk.hatalar])
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
    ]);
  }
}


class _Bos extends StatelessWidget {
  const _Bos(this.yazi);
  final String yazi;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(16), child: BilgiKutusu(yazi: yazi));
}

ListView _liste(List<Widget> c) => ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 24), children: c);

String _dagilim(Map<String, double> m) {
  final l = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  String b(String x) => x.isEmpty ? x : '${x[0]}${x.substring(1).toLowerCase()}';
  return l.map((e) => '${b(e.key)} ${sayi(e.value)}').join(', ');
}

class _KesimOlum extends StatelessWidget {
  const _KesimOlum({required this.veri});
  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    final e = veri.eskEk;
    if (e.kesim.isEmpty && e.olum.isEmpty) return const _Bos('Aylık ithal kesim / ölüm listeleri henüz gelmedi.');
    final supheli = e.kesim.fold(0, (t, x) => t + x.supheli);
    return _liste([
      const BilgiKutusu(
          yazi: 'Kaynak: aylık "İthal Ölüm / Kesim" listeleri (kesilen sayı, kesim nedeni, canlı ağırlık, kesim yeri; '
              'ölüm tarihi ve nedeni). Plaka, sürücü, kantar fişi ve kulak küpesi alınmaz.'),
      if (supheli > 0)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: BilgiKutusu(
              uyari: true,
              yazi: '$supheli satırda baş başına canlı ağırlık 150–900 kg aralığı dışında (yazım hatası olabilir); '
                  'bu satırlar ortalama ağırlığa katılmadı.'),
        ),
      const BolumBasligi('Kesim', ikon: Icons.content_cut),
      VeriTablosu(
        basliklar: const ['Ay', 'Kesilen', 'Ort. canlı kg', 'Nedenler'],
        metinSutunlari: const {0, 3},
        ilkSutunGenislik: 100,
        satirlar: [
          for (final x in e.kesim)
            [x.ad, sayi(x.adet), sayi(x.ortKg), _dagilim(x.neden)],
        ],
      ),
      const BolumBasligi('Ölüm', ikon: Icons.warning_amber_outlined),
      VeriTablosu(
        basliklar: const ['Ay', 'Ölen', 'Maliyete yansıyan', 'Nedenler'],
        metinSutunlari: const {0, 3},
        ilkSutunGenislik: 100,
        satirlar: [
          for (final x in e.olum)
            [x.ad, sayi(x.adet), sayi(x.maliyete), _dagilim(x.neden)],
        ],
      ),
      if (e.nakliye.isNotEmpty) ...[
        const BolumBasligi('Kesime nakliye', ikon: Icons.local_shipping_outlined),
        VeriTablosu(
          basliklar: const ['Ay', 'Sefer', 'Taşınan hayvan', 'Sefer başı'],
          ilkSutunGenislik: 100,
          satirlar: [
            for (final x in e.nakliye)
              [x.ad, sayi(x.sefer), sayi(x.hayvan), sayi(x.sefer > 0 ? x.hayvan / x.sefer : null, ondalik: 1)],
          ],
        ),
      ],
    ]);
  }
}

class _Gelisler extends StatelessWidget {
  const _Gelisler({required this.veri});
  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    final k = veri.eskKaynak, e = veri.eskEk;
    if (k.partiler.isEmpty && e.kasaplik.isEmpty) return const _Bos('Parti listeleri henüz gelmedi.');
    return _liste([
      const BilgiKutusu(
          yazi: 'İthal dana partileri: çiftliğe giren sayı, ESK liman sayısı ve nakliyede ölenler. Kasaplık listesi: '
              'parti başına çiftlik kantarı net ağırlığı (araç bazında tartım toplamı). Plaka ve bilet numarası alınmaz.'),
      if (k.partiler.isNotEmpty) ...[
        const BolumBasligi('İthal dana partileri', ikon: Icons.local_shipping_outlined),
        VeriTablosu(
          basliklar: const ['Parti', 'Geliş', 'Çiftlik', 'Liman', 'Fark', 'Nakliye ölen'],
          metinSutunlari: const {0, 1},
          ilkSutunGenislik: 80,
          satirlar: [
            for (final p in k.partiler)
              [p.parti, p.gelis, sayi(p.ciftlik), sayi(p.liman), p.fark == null ? '—' : fark(p.fark!), sayi(p.nakliyeOlen, bos: '0')],
          ],
        ),
      ],
      if (e.kasaplik.isNotEmpty) ...[
        const BolumBasligi('Geliş tartımları (kasaplık listesi)', ikon: Icons.scale_outlined),
        VeriTablosu(
          basliklar: const ['Parti', 'Tarih', 'Araç', 'Hayvan', 'Net kg', 'Ort. kg', 'Liman fire %'],
          metinSutunlari: const {0, 1},
          ilkSutunGenislik: 60,
          satirlar: [
            for (final p in e.kasaplik.reversed)
              [
                '${p.parti}.',
                p.tarih,
                '${p.arac}',
                sayi(p.adet),
                sayi(p.netKg),
                sayi(p.ortKg, ondalik: 1),
                p.fireYuzde == null ? '—' : sayi(p.fireYuzde, ondalik: 1),
              ],
          ],
        ),
      ],
    ]);
  }
}

class _YemBalyaGubre extends StatelessWidget {
  const _YemBalyaGubre({required this.veri});
  final RaporVerisi veri;

  Widget _tablo(Map<String, Map<String, double>> m) {
    final aylar = m.keys.toList()..sort();
    final top = <String, double>{};
    for (final x in m.values) {
      x.forEach((u, kg) => top[u] = (top[u] ?? 0) + kg);
    }
    final sira = (top.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((e) => e.key).take(4).toList();
    return VeriTablosu(
      basliklar: ['Ay', ...sira, if (top.length > sira.length) 'Diğer', 'Toplam'],
      ilkSutunGenislik: 70,
      satirlar: [
        for (final a in aylar)
          [
            _ayK(a),
            for (final u in sira) _ton(m[a]![u] ?? 0),
            if (top.length > sira.length)
              _ton(m[a]!.entries.where((e) => !sira.contains(e.key)).fold(0.0, (t, e) => t + e.value)),
            _ton(m[a]!.values.fold(0.0, (t, x) => t + x)),
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = veri.eskKaynak, e = veri.eskEk;
    final yem = k.yemAylik();
    if (yem.isEmpty && e.balya.isEmpty && e.gubre.isEmpty) return const _Bos('Yem, balya ve gübre kayıtları henüz gelmedi.');
    final balyaYer = <String, double>{};
    for (final b in e.balya) {
      balyaYer[b.yer] = (balyaYer[b.yer] ?? 0) + b.kg;
    }
    return _liste([
      const BilgiKutusu(
          yazi: 'Tonaj (ton) olarak: gelen yem (ESK adına), gelen balya (mısır, yonca, sap; çiftliklerden iç transfer dahil) '
              've gübre çıkışı (ahır temizliği, cüruf, biyogaz). Plaka ve sürücü bilgisi alınmaz.'),
      if (yem.isNotEmpty) ...[
        const BolumBasligi('Gelen yem (ton)', ikon: Icons.grass_outlined),
        _tablo(yem),
      ],
      if (e.balya.isNotEmpty) ...[
        const BolumBasligi('Gelen balya (ton)', ikon: Icons.agriculture_outlined,
            aciklama: 'Ürün adına göre; geldiği yer dağılımı aşağıda.'),
        _tablo(EskEk.aylik(e.balya)),
        const SizedBox(height: 6),
        Text('Geldiği yer: ${balyaYer.entries.map((x) => '${x.key} ${_ton(x.value)} t').join(' · ')}',
            style: const TextStyle(fontSize: 12.5, color: Renk.soluk)),
      ],
      if (e.gubre.isNotEmpty) ...[
        const BolumBasligi('Gübre çıkışı (ton)', ikon: Icons.compost_outlined, aciklama: 'Gittiği yere göre.'),
        _tablo(EskEk.aylik(e.gubre, yereGore: true)),
      ],
    ]);
  }
}

class _GelirTablosu extends StatelessWidget {
  const _GelirTablosu({required this.veri});
  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    final g = veri.eskEk.gelir;
    if (g.isEmpty) return const _Bos('ESK gelir tablosu çalışması henüz gelmedi.');
    double t(double? Function(EskGelirAyi) f) => g.fold(0.0, (s, x) => s + (f(x) ?? 0));
    return _liste([
      const BilgiKutusu(
          yazi: 'Kaynak: "Esk çalışma" dosyasındaki gelir tablosuna göre aylık sonuç (muhasebe çalışması). '
              'Kâr/zarar ESK aylık raporuyla karşılaştırılır; fark "Özet ve mutabakat" sekmesinde görünür.'),
      const SizedBox(height: 8),
      VeriTablosu(
        basliklar: const ['Ay', 'Bakım geliri', 'Sap satışı', 'Kira', 'Toplam satış', 'Toplam gider', 'Kâr / zarar'],
        ilkSutunGenislik: 100,
        vurguluSonSatir: true,
        satirlar: [
          for (final x in g) [x.ad, tl(x.bakim), tl(x.sap), tl(x.kira), tl(x.satis), tl(x.gider), tl(x.kazanc)],
          ['Toplam', tl(t((x) => x.bakim)), tl(t((x) => x.sap)), tl(t((x) => x.kira)), tl(t((x) => x.satis)),
            tl(t((x) => x.gider)), tl(t((x) => x.kazanc))],
        ],
      ),
    ]);
  }
}
