import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/model.dart';
import '../veri/uretim_karlilik.dart';
import 'bilesenler.dart';
import 'gonder.dart';

String _tl(double v) => '${v < 0 ? '−' : ''}${sayi(v.abs())} ₺';

/// Tarımsal Üretim ve Kârlılık: Tarımsal Faaliyet dosyasındaki ÇİFTLİK BAZINDA
/// verilerinden ürün bazında ve çiftlik bazında ekim alanı, dekara verim,
/// toplam verim, satış tutarı, toplam maliyet ve net kazanç.
class UretimKarlilikEkran extends StatelessWidget {
  const UretimKarlilikEkran({super.key, required this.veri});

  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VeriDeposu.ben,
      builder: (context, _) {
        final u = (VeriDeposu.ben.veri ?? veri).tarimsalUretim;
        final baslik = u.yilBasligi.isEmpty ? 'Üretim ve Kârlılık' : '${u.yilBasligi} Üretim ve Kârlılık';
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(baslik),
              actions: const [TabloGuncelleButonu()],
              bottom: const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Color(0xCCFFFFFF),
                indicatorColor: Colors.white,
                tabs: [Tab(text: 'Ürün bazında'), Tab(text: 'Çiftlik bazında')],
              ),
            ),
            body: u.bos
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: BilgiKutusu(
                        yazi: "Veri henüz gelmedi. Drive'daki Tarımsal Faaliyet dosyasında 'ÇİFTLİK BAZINDA' "
                            'sayfası olmalı ve Apps Script güncel olmalı.'),
                  )
                : TabBarView(children: [
                    GonderAlani(konu: '$baslik – Ürün bazında', child: _UrunBazinda(u: u)),
                    GonderAlani(konu: '$baslik – Çiftlik bazında', child: _CiftlikBazinda(u: u)),
                  ]),
          ),
        );
      },
    );
  }
}

class _UrunBazinda extends StatelessWidget {
  const _UrunBazinda({required this.u});
  final TarimsalUretim u;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GenelToplam(u: u),
          for (final k in u.urunler) _KalemKarti(k: k),
          _Kaynak(u: u),
        ],
      );
}

class _CiftlikBazinda extends StatelessWidget {
  const _CiftlikBazinda({required this.u});
  final TarimsalUretim u;

  @override
  Widget build(BuildContext context) {
    final l = [...u.ciftlikler]..sort((a, b) => b.toplam.satis.compareTo(a.toplam.satis));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _GenelToplam(u: u),
        for (final c in l)
          _KalemKarti(
            k: c.toplam,
            alt: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: 20),
                const Text('Ürünler', style: TextStyle(fontWeight: FontWeight.w600, color: Renk.yazi)),
                const SizedBox(height: 6),
                VeriTablosu(
                  ilkSutunGenislik: 120,
                  basliklar: const ['Ürün', 'Alan (da)', 'Verim (kg/da)', 'Satış', 'Maliyet', 'Net kazanç'],
                  satirlar: [
                    for (final p in c.urunler)
                      [
                        p.alt.isEmpty ? p.ad : '${p.ad} (${p.alt})',
                        sayi(p.dekar),
                        sayi(p.dekaraVerim),
                        _tl(p.satis),
                        _tl(p.maliyet),
                        _tl(p.netKazanc),
                      ],
                  ],
                ),
              ],
            ),
          ),
        _Kaynak(u: u),
      ],
    );
  }
}

class _GenelToplam extends StatelessWidget {
  const _GenelToplam({required this.u});
  final TarimsalUretim u;

  @override
  Widget build(BuildContext context) {
    final t = u.genelToplam;
    return Panel(
      baslik: 'Genel toplam',
      child: Column(children: [
        _Satir('Ekim alanı', '${sayi(t.dekar)} da'),
        _Satir('Satış tutarı', _tl(t.satis)),
        _Satir('Toplam maliyet', _tl(t.maliyet)),
        const Divider(),
        _Satir('Net kazanç', _tl(t.netKazanc), renk: t.netKazanc >= 0 ? Renk.yesil : Renk.kirmizi, kalin: true),
        if (u.ekGelirler.isNotEmpty) ...[
          for (final e in u.ekGelirler) _Satir('+ ${_basHarf(e.$1)}', _tl(e.$2)),
          _Satir('Toplam kazanç', _tl(t.netKazanc + u.ekGelirToplami),
              renk: Renk.yesil, kalin: true),
        ],
      ]),
    );
  }
}

String _basHarf(String s) {
  final k = s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  return k.isEmpty ? k : '${k[0].toUpperCase()}${k.substring(1)}';
}

class _KalemKarti extends StatelessWidget {
  const _KalemKarti({required this.k, this.alt});
  final UretimKalemi k;
  final Widget? alt;

  @override
  Widget build(BuildContext context) {
    final kar = k.netKazanc >= 0;
    return Panel(
      baslik: k.ad,
      eylem: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: kar ? Renk.yesilAcik : Renk.kirmiziAcik,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(kar ? 'Kâr' : 'Zarar',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kar ? Renk.yesil : Renk.kirmizi)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Satir('Ekim alanı', '${sayi(k.dekar)} da'),
        _Satir('Dekara verim', '${sayi(k.dekaraVerim)} kg/da'),
        _Satir('Toplam verim', '${sayi(k.toplamVerim)} kg'),
        _Satir('Satış tutarı', _tl(k.satis)),
        _Satir('Toplam maliyet', _tl(k.maliyet)),
        const Divider(),
        _Satir('Net kazanç', _tl(k.netKazanc), renk: kar ? Renk.yesil : Renk.kirmizi, kalin: true),
        _Satir('Dekar başına net', _tl(k.dekarKazanc), renk: kar ? Renk.yesil : Renk.kirmizi),
        if (alt != null) alt!,
      ]),
    );
  }
}

class _Satir extends StatelessWidget {
  const _Satir(this.etiket, this.deger, {this.renk, this.kalin = false});
  final String etiket, deger;
  final Color? renk;
  final bool kalin;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(etiket, style: const TextStyle(color: Renk.soluk, fontSize: 14))),
          Text(deger,
              style: TextStyle(
                  color: renk ?? Renk.yazi, fontSize: 14, fontWeight: kalin ? FontWeight.w700 : FontWeight.w500)),
        ]),
      );
}

class _Kaynak extends StatelessWidget {
  const _Kaynak({required this.u});
  final TarimsalUretim u;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        child: Text(
          'Kaynak: ${u.dosya.isEmpty ? 'Tarımsal Faaliyet dosyası' : u.dosya} › ÇİFTLİK BAZINDA. '
          'Ürün bazındaki değerler çiftlik satırlarının toplamıdır; dekara verim = toplam verim ÷ ekim alanı. '
          'Ormanlık, Taşağıl çiftliğine dahil gösterilir.',
          style: const TextStyle(fontSize: 12, color: Renk.soluk, height: 1.4),
        ),
      );
}
