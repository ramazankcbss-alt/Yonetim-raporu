import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/model.dart';
import '../veri/tarla.dart';
import 'bilesenler.dart';
import 'gonder.dart';
import 'paylasim.dart';

/// Tarla Haritası: Google Earth (KMZ) ekiliş haritası; parseller,
/// alanlar ve tarım icmaliyle (ekim alanları, hasat, günlük faaliyet)
/// karşılaştırma.
class TarlaEkran extends StatefulWidget {
  const TarlaEkran({super.key, required this.veri, this.sezonlar});
  final RaporVerisi veri;

  /// Testler için; verilmezse paketlenmiş dosyalar yüklenir.
  final List<TarlaSezonu>? sezonlar;

  @override
  State<TarlaEkran> createState() => _TarlaEkranState();
}

class _TarlaEkranState extends State<TarlaEkran> {
  late final Future<List<TarlaSezonu>> _yuk =
      widget.sezonlar != null ? Future.value(widget.sezonlar) : TarlaSezonu.yukle();

  void _ac(BuildContext context, List<TarlaSezonu> paket, String sezon, {bool yerine = false}) {
    final r = MaterialPageRoute<void>(builder: (_) => _SezonEkrani(paket: paket, sezon: sezon, ilk: widget.veri));
    yerine ? Navigator.of(context).pushReplacement(r) : Navigator.of(context).push(r);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<TarlaSezonu>>(
        future: _yuk,
        builder: (context, snap) {
          final l = snap.data ?? const <TarlaSezonu>[];
          if (snap.connectionState != ConnectionState.done) {
            return Scaffold(appBar: AppBar(title: const Text('Tarla Haritası')), body: const Center(child: CircularProgressIndicator()));
          }
          if (l.isEmpty) {
            return Scaffold(
                appBar: AppBar(title: const Text('Tarla Haritası')),
                body: const Padding(padding: EdgeInsets.all(16), child: BilgiKutusu(yazi: 'Tarla haritası verisi yok.')));
          }
          return ListenableBuilder(
            listenable: VeriDeposu.ben,
            builder: (context, _) {
              final v = VeriDeposu.ben.veri ?? widget.veri;
              final hepsi = tarlaSezonlari(l, VeriDeposu.ben.sezonParselleri(v), sinirlar: VeriDeposu.ben.parselSinirleri(v), ekSezonlar: VeriDeposu.ben.tarlaEkSezonlari(v));
              return Scaffold(
                appBar: AppBar(title: const Text('Tarla Haritası')),
                body: GonderAlani(
                  konu: 'Tarla Haritası – Sezonlar',
                  child: ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 24), children: [
                    const BilgiKutusu(
                        yazi: 'Her sezon ayrı bir bölümdür; içinde Harita, Parseller, Karşılaştırma ve ÇKS sekmeleri yer alır. '
                            'Parsel çizimleri ve sezonların ürünleri Google Earth KMZ haritasından (Yerlerim 24.11.2026 GÜNCEL) '
                            'alınır. Haritada parsele dokunularak yapılan girişler KMZ bilgisinin önüne geçer.'),
                    const SizedBox(height: 8),
                    for (final x in hepsi) _sezonKarti(context, l, x, v),
                    if (!_yalnizGor && hepsi.isNotEmpty)
                      _MenuKarti(
                        baslik: 'Yeni sezon ekle',
                        alt: '${sonrakiSezon(hepsi.last.sezon)} sezonunu açın; parseller güncel harita çizimleriyle gelir, '
                            'ürünleri haritaya dokunarak girersiniz',
                        ikon: Icons.add_circle_outline,
                        dokun: () => _yeniSezon(context, hepsi, v),
                      ),
                    if (VeriDeposu.ben.paylasim case final p?)
                      BilgiKutusu(
                          yazi: 'Paylaşılan harita (${p.etiket}) · '
                              '${p.duzenler ? 'düzenleme yetkisi' : 'yalnızca görüntüleme'}')
                    else
                      _MenuKarti(
                        baslik: 'Paylaşım',
                        alt: 'Tarla Haritası\'nı iş arkadaşınızla paylaşın: görüntüleme / düzenleme yetkisi, istediğiniz zaman kapatma',
                        ikon: Icons.share_outlined,
                        dokun: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PaylasimEkrani())),
                      ),
                    _MenuKarti(
                      baslik: 'Yıllara göre ekim karşılaştırması',
                      alt: '${hepsi.map((x) => x.sezon).join(' · ')} — çiftlik ve ürün alanları, parsel geçmişi',
                      ikon: Icons.compare_arrows,
                      dokun: () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => _YilKarsilastirma(paket: l, ilk: widget.veri))),
                    ),
                  ]),
                ),
              );
            },
          );
        },
      );

  /// Yeni sezon açma (ve kaydı olmayan son açılan sezonu kaldırma) penceresi.
  Future<void> _yeniSezon(BuildContext context, List<TarlaSezonu> hepsi, RaporVerisi v) async {
    final yeni = sonrakiSezon(hepsi.last.sezon);
    final son = hepsi.last.sezon;
    final acilan = VeriDeposu.ben.tarlaEkSezonlari(v);
    final kayitsiz = VeriDeposu.ben.paylasim == null && acilan.contains(son) && !VeriDeposu.ben.sezonParselleri(v).any((x) => x.sezon == son);
    final secim = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$yeni sezonu açılsın mı?'),
        content: Text('Yeni sezon $son sezonunun ardından eklenir. Parseller güncel harita çizimleriyle açılır; ürün ve dekarları '
            'haritada parsele dokunarak girersiniz. '
            '${VeriDeposu.ben.paylasim == null ? 'Sezon, paylaştığınız web panelinde de görünür.' : 'Açılan sezonu yalnızca harita sahibi kaldırabilir.'}'
            '${kayitsiz ? '\n\n$son sezonunda henüz kayıt yok; isterseniz onu kaldırabilirsiniz.' : ''}'),
        actions: [
          if (kayitsiz) TextButton(onPressed: () => Navigator.pop(ctx, 'sil'), child: Text('$son sezonunu kaldır')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'ekle'), child: const Text('Sezonu aç')),
        ],
      ),
    );
    if (secim == null || !context.mounted) return;
    final m = ScaffoldMessenger.of(context);
    try {
      final mesaj = await VeriDeposu.ben.tarlaSezon(secim == 'sil' ? son : yeni, sil: secim == 'sil');
      m.showSnackBar(SnackBar(content: Text(mesaj)));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text('Sezon kaydedilemedi: $e')));
    }
  }

  Widget _sezonKarti(BuildContext context, List<TarlaSezonu> l, TarlaSezonu x, RaporVerisi v) {
    final parseller = [for (final c in x.ciftlikler) ...c.parseller.where((p) => p.tip != 'diger')];
    final girilen = parseller.where((p) => p.urunler.isNotEmpty).length;
    final cks = v.cks.where((k) => k.sezon == x.sezon).length;
    final excel = [for (final c in x.ciftlikler) ...sezonExcel(v.ekim, v.ekimPlani, x, c.ad).values].fold<double>(0, (a, b) => a + b);
    final alt = [
      '${x.uretimYili} üretim yılı',
      x.giris ? 'Haritadan girilen: $girilen / ${parseller.length} parsel' : 'KMZ haritası (${x.kaynak})',
      excel > 0 ? 'Excel: ${sayi(excel)} da' : 'Excel kaydı yok',
      if (cks > 0) 'ÇKS: $cks kayıt',
    ].join(' · ');
    return _MenuKarti(
      baslik: '${x.sezon} sezonu',
      alt: alt,
      ikon: x.giris ? Icons.edit_location_alt_outlined : Icons.map_outlined,
      dokun: () => _ac(context, l, x.sezon),
    );
  }
}

/// Sezonlar arası ekim karşılaştırması: çiftlik/ürün alanları (Excel esaslı; Excel yoksa haritadan girilen)
/// ve parsel bazında ürün geçmişi.
class _YilKarsilastirma extends StatelessWidget {
  const _YilKarsilastirma({required this.paket, required this.ilk});
  final List<TarlaSezonu> paket;
  final RaporVerisi ilk;

  static String _kisa(String s) {
    final m = RegExp(r'^\d{2}(\d{2})-\d{2}(\d{2})$').firstMatch(s);
    return m == null ? s : '${m[1]}-${m[2]}';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: VeriDeposu.ben,
        builder: (context, _) {
          final v = VeriDeposu.ben.veri ?? ilk;
          final sezonlar = tarlaSezonlari(paket, VeriDeposu.ben.sezonParselleri(v), sinirlar: VeriDeposu.ben.parselSinirleri(v), ekSezonlar: VeriDeposu.ben.tarlaEkSezonlari(v));
          final ciftlikler = <String>{for (final s in sezonlar) for (final c in s.ciftlikler) c.ad}.toList();
          // (sezon, çiftlik) → ürün → (dekar, haritadan mı)
          Map<String, (double, bool)> alanlar(TarlaSezonu s, String c) {
            final ex = sezonExcel(v.ekim, v.ekimPlani, s, c);
            if (ex.isNotEmpty) return {for (final e in ex.entries) e.key: (e.value, false)};
            final cf = s.ciftlikler.where((x) => ciftlikAnahtari(x.ad) == ciftlikAnahtari(c));
            if (cf.isEmpty) return {};
            return {for (final e in cf.first.urunToplami.entries) if (e.value > 0) e.key: (e.value, true)};
          }

          String hucre((double, bool)? x) => x == null ? '—' : '${sayi(x.$1)}${x.$2 ? '*' : ''}';
          String degisim((double, bool)? a, (double, bool)? b) {
            if (a == null && b == null) return '—';
            final d = (b?.$1 ?? 0) - (a?.$1 ?? 0);
            if (d.abs() < 0.5) return '=';
            return '${d > 0 ? '+' : '−'}${sayi(d.abs())}';
          }

          final son = sezonlar.length >= 2 ? sezonlar[sezonlar.length - 2] : null;
          return Scaffold(
            appBar: AppBar(title: const Text('Yıllara göre ekim')),
            body: GonderAlani(
              konu: 'Tarla Haritası – Yıllara göre ekim karşılaştırması',
              child: ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 24), children: [
                const BilgiKutusu(
                    yazi: 'Alanlar dekar olarak Excel dosyalarından alınır; Excel kaydı olmayan sezonda haritadan girilen '
                        'alanlar gösterilir (* işaretli). Son sütun, son iki sezon arasındaki değişimdir.'),
                for (final c in ciftlikler)
                  () {
                    final m = [for (final s in sezonlar) alanlar(s, c)];
                    final urunler = <String>{for (final x in m) ...x.keys}.toList()..sort();
                    if (urunler.isEmpty) return const SizedBox.shrink();
                    final toplam = [
                      for (final x in m) x.isEmpty ? null : (x.values.fold<double>(0, (a, b) => a + b.$1), x.values.any((y) => y.$2))
                    ];
                    return Panel(
                      baslik: c,
                      child: VeriTablosu(
                        ilkSutunGenislik: 120,
                        basliklar: ['Ürün', for (final s in sezonlar) _kisa(s.sezon), if (son != null) 'Değişim'],
                        satirlar: [
                          for (final u in urunler)
                            [
                              u,
                              for (final x in m) hucre(x[u]),
                              if (son != null) degisim(m[m.length - 2][u], m.last[u]),
                            ],
                          [
                            'Toplam',
                            for (final t in toplam) hucre(t),
                            if (son != null) degisim(toplam[toplam.length - 2], toplam.last),
                          ],
                        ],
                        vurguluSonSatir: true,
                      ),
                    );
                  }(),
                const BolumBasligi('Parsel bazında ekim geçmişi'),
                for (final c in ciftlikler)
                  () {
                    final parseller = <String>[
                      for (final s in sezonlar)
                        for (final cf in s.ciftlikler)
                          if (ciftlikAnahtari(cf.ad) == ciftlikAnahtari(c))
                            for (final p in cf.parseller)
                              if (p.tip != 'diger') p.ad
                    ].toSet().toList();
                    String yaz(TarlaSezonu s, String parsel) {
                      for (final cf in s.ciftlikler) {
                        if (ciftlikAnahtari(cf.ad) != ciftlikAnahtari(c)) continue;
                        for (final p in cf.parseller) {
                          if (p.ad != parsel) continue;
                          if (p.urunler.isEmpty) return p.girilmedi ? 'girilmedi' : '—';
                          return [
                            for (final (i, u) in p.urunler.indexed)
                              '${_YaziCizer._kisaUrun(u.$1)}'
                                  '${_YaziCizer._urunDekari(p, i) == null ? '' : ' ${sayi(_YaziCizer._urunDekari(p, i))}'}'
                                  '${p.cesit(i) == null ? '' : ' (${p.cesit(i)})'}'
                                  '${cokYillik(u.$1) ? ' · ${ardisikYil(s, c, parsel, u.$1).$1}. yıl' : ''}'
                          ].join(' + ');
                        }
                      }
                      return '—';
                    }

                    final satirlar = [
                      for (final p in parseller)
                        if (sezonlar.any((s) => !['—', 'girilmedi'].contains(yaz(s, p)))) [p, for (final s in sezonlar) yaz(s, p)]
                    ];
                    if (satirlar.isEmpty) return const SizedBox.shrink();
                    return Panel(
                      baslik: c,
                      child: VeriTablosu(
                        ilkSutunGenislik: 96,
                        basliklar: ['Parsel', for (final s in sezonlar) _kisa(s.sezon)],
                        metinSutunlari: {for (var i = 0; i <= sezonlar.length; i++) i},
                        satirlar: satirlar,
                      ),
                    );
                  }(),
              ]),
            ),
          );
        },
      );
}

/// Bir sezon bölümü: Harita, Parseller, Karşılaştırma, ÇKS.
class _SezonEkrani extends StatelessWidget {
  const _SezonEkrani({required this.paket, required this.sezon, required this.ilk});
  final List<TarlaSezonu> paket;
  final String sezon;
  final RaporVerisi ilk;

  TarlaSezonu _bul(RaporVerisi v) {
    final l = tarlaSezonlari(paket, VeriDeposu.ben.sezonParselleri(v), sinirlar: VeriDeposu.ben.parselSinirleri(v), ekSezonlar: VeriDeposu.ben.tarlaEkSezonlari(v));
    return l.firstWhere((x) => x.sezon == sezon, orElse: () => l.first);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: VeriDeposu.ben,
        builder: (context, _) {
          final v = VeriDeposu.ben.veri ?? ilk;
          final s = _bul(v);
          final sonraki = sonrakiSezon(s.sezon);
          return DefaultTabController(
            length: 4,
            child: Scaffold(
              appBar: AppBar(
                title: Text('Tarla Haritası ${s.sezon}'),
                bottom: const TabBar(
                    isScrollable: true,
                    tabs: [Tab(text: 'Harita'), Tab(text: 'Parseller'), Tab(text: 'Karşılaştırma'), Tab(text: 'ÇKS')]),
              ),
              body: TabBarView(children: [
                GonderAlani(
                    konu: 'Tarla Haritası ${s.sezon} – Harita',
                    child: _Harita(
                        s: s,
                        v: v,
                        sezonBul: _bul,
                        sezonSec: s.giris
                            ? null
                            : () => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
                                builder: (_) => _SezonEkrani(paket: paket, sezon: sonraki, ilk: ilk))))),
                GonderAlani(konu: 'Tarla Haritası ${s.sezon} – Parseller', child: _Parseller(s: s, v: v, ilk: ilk)),
                GonderAlani(
                    konu: 'Tarla Haritası ${s.sezon} – Karşılaştırma',
                    child: s.giris ? _GirisKarsilastirma(s: s, v: v) : _Karsilastirma(s: s, v: v)),
                GonderAlani(konu: 'Tarla Haritası ${s.sezon} – ÇKS', child: _Cks(s: s, v: v, ilk: ilk)),
              ]),
            ),
          );
        },
      );
}

const _renkler = {
  'Buğday': Color(0xFFE0A526),
  'Arpa': Color(0xFFC9B458),
  'Şeker pancarı': Color(0xFF8E3B8A),
  'Silajlık mısır': Color(0xFF3F9142),
  'Silajlık mısır (2. ürün)': Color(0xFF7CC47F),
  'Yonca': Color(0xFF1E7FA8),
  'Patates': Color(0xFFA0522D),
  'Soğan': Color(0xFFB8860B),
  'Dane mısır': Color(0xFFF4D03F),
  'Yağlık ayçiçeği': Color(0xFFF1C40F),
  'Çerezlik ayçiçeği': Color(0xFFD4AC0D),
  'Kanola (kolza)': Color(0xFFE5E85C),
  'Aspir': Color(0xFFE67E22),
  'Soya': Color(0xFF7DAA5A),
  'Nohut': Color(0xFFD7B98E),
  'Kuru fasulye': Color(0xFFB05A4A),
  'Mercimek': Color(0xFFC8743A),
  'Çavdar': Color(0xFFA38B5B),
  'Yulaf': Color(0xFFD9C79E),
  'Tritikale': Color(0xFFBFA76A),
  'Korunga': Color(0xFFC2185B),
  'Fiğ': Color(0xFF6C7A3A),
  'Silajlık sorgum': Color(0xFF5E8C31),
  'Sudan otu': Color(0xFF8BC34A),
  'Kimyon': Color(0xFF9E7C5A),
  'Kişniş': Color(0xFF7FA67F),
  'Nadas': Color(0xFFB8A88A),
  'Deneme alanı': Color(0xFF90A4AE),
  'Islah edilen alan': Color(0xFF9CAF88),
  'Ağaçlık alan': Color(0xFF2E5E3A),
  'Boş alan': Color(0xFFD6D6D6),
};
/// Kullanıcının seçtiği ürün renkleri (cihazda saklanır).
class UrunRenkleri extends ChangeNotifier {
  UrunRenkleri._() {
    _yukle();
  }
  static final ben = UrunRenkleri._();
  static const _anahtar = 'tarla_urun_renkleri';
  final Map<String, int> _secim = {};

  Color? secili(String urun) => _secim[urunAnahtari(urun)] == null ? null : Color(_secim[urunAnahtari(urun)]!);

  Future<void> _yukle() async {
    final p = await SharedPreferences.getInstance();
    for (final x in p.getStringList(_anahtar) ?? const <String>[]) {
      final i = x.lastIndexOf('=');
      if (i > 0) _secim[x.substring(0, i)] = int.tryParse(x.substring(i + 1)) ?? 0;
    }
    notifyListeners();
  }

  Future<void> ayarla(String urun, Color? renk) async {
    final k = urunAnahtari(urun);
    if (renk == null) {
      _secim.remove(k);
    } else {
      _secim[k] = renk.toARGB32();
    }
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_anahtar, [for (final e in _secim.entries) '${e.key}=${e.value}']);
  }
}

Color urunAdRengi(String u) =>
    UrunRenkleri.ben.secili(u) ?? _renkler[urunAnahtari(u)] ?? const Color(0xFF6D8B74);
Color urunRengi(TarlaParsel p) {
  if (p.urunler.isEmpty) return p.tip == 'bos' || p.girilmedi ? const Color(0xFFD6D6D6) : const Color(0xFF90A4AE);
  return urunAdRengi(p.urunler.first.$1);
}

const _renkPaleti = [
  Color(0xFFE0A526), Color(0xFFF4D03F), Color(0xFFC9B458), Color(0xFFD35400), Color(0xFFC0392B), Color(0xFFE91E63),
  Color(0xFF8E3B8A), Color(0xFF6C3483), Color(0xFF1E7FA8), Color(0xFF00BCD4), Color(0xFF1ABC9C), Color(0xFF3F9142),
  Color(0xFF7CC47F), Color(0xFF827717), Color(0xFFA0522D), Color(0xFF5D4037), Color(0xFF607D8B), Color(0xFF212121),
];

/// Ürün rengi seçimi (haritadaki lejanttan açılır).
Future<void> urunRengiSec(BuildContext context, String urun) async {
  final secim = await showDialog<Object>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('$urun rengi'),
      content: Wrap(spacing: 10, runSpacing: 10, children: [
        for (final r in _renkPaleti)
          InkWell(
            onTap: () => Navigator.pop(c, r),
            customBorder: const CircleBorder(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: r,
                shape: BoxShape.circle,
                border: Border.all(color: urunAdRengi(urun) == r ? Colors.black : Colors.white, width: 3),
              ),
            ),
          ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, 'varsayilan'), child: const Text('Varsayılan renk')),
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vazgeç')),
      ],
    ),
  );
  if (secim is Color) await UrunRenkleri.ben.ayarla(urun, secim);
  if (secim == 'varsayilan') await UrunRenkleri.ben.ayarla(urun, null);
}

/// KMZ görsel renkleri.
Color gorselRengi(String tur) => switch (tur) {
      'kuyu' => const Color(0xFF0277BD),
      'direk' => const Color(0xFF37474F),
      'og' => const Color(0xFFD32F2F),
      'pivot' => const Color(0xFF455A64),
      'nokta' => const Color(0xFFD32F2F),
      _ => const Color(0xFFEF6C00),
    };

const _gorselAdlari = {'kuyu': 'Kuyu', 'direk': 'Enerji direği', 'og': 'OG hattı', 'hat': 'Enerji / su hattı', 'pivot': 'Pivot merkezi'};

String _da(double? v) => v == null ? '–' : '${sayi(v)} da';

class _Harita extends StatefulWidget {
  const _Harita({required this.s, required this.v, required this.sezonBul, this.sezonSec});
  final TarlaSezonu s;
  final RaporVerisi v;

  /// Güncel veriyle aynı sezonu verir (tam ekran harita için).
  final TarlaSezonu Function(RaporVerisi) sezonBul;

  /// Yeni sezon görünümüne geçer.
  final VoidCallback? sezonSec;
  @override
  State<_Harita> createState() => _HaritaState();
}

class _HaritaState extends State<_Harita> {
  int _c = 0;
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: UrunRenkleri.ben, builder: (context, _) => _yap(context));

  Widget _yap(BuildContext context) {
    final ciftlikler = widget.s.ciftlikler.where((c) => c.parseller.any((p) => p.koord.length > 2)).toList();
    final c = ciftlikler[_c.clamp(0, ciftlikler.length - 1)];
    final cizili = c.parseller.where((p) => p.koord.length > 2).toList();
    final cksAdlari = {
      for (final p in cizili)
        if (parselCks(c, p, widget.v.cks, widget.s.sezon).isNotEmpty) p.ad
    };
    // Alanlar Excel ekim planından; haritadan yalnızca ürün cinsi alınır.
    final giris = widget.s.giris;
    // Alanlar Excel ekim planından; yeni sezonda haritadan girilen alanlar.
    final excel = giris ? c.urunToplami : excelAlanlari(widget.v.ekim, c.ad);
    final plan = giris ? sezonExcel(widget.v.ekim, widget.v.ekimPlani, widget.s, c.ad) : const <String, double>{};
    final cinsler = c.urunCinsleri;
    final urunler = [...excel.keys, ...cinsler.where((u) => !excel.containsKey(u)), ...plan.keys.where((u) => !excel.containsKey(u) && !cinsler.contains(u))];
    final toplam = excel.values.fold<double>(0, (a, b) => a + b);
    final girilmeyen = cizili.where((p) => p.girilmedi).length;
    void dokun(TarlaParsel p, int? parca) => _parselIslem(context, widget.s, c, p, parca: parca);
    return ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 24), children: [
      SizedBox(
        height: 44,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final (i, x) in ciftlikler.indexed)
            Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(label: Text(x.ad), selected: i == _c, onSelected: (_) => setState(() => _c = i))),
        ]),
      ),
      Text(c.ad, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      Text('${widget.s.sezon} sezonu · kaynak: ${widget.s.kaynak}', style: const TextStyle(fontSize: 12, color: Renk.soluk)),
      const SizedBox(height: 8),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          AspectRatio(
            aspectRatio: 0.82,
            child: _HaritaGorunum(
                p: cizili, g: c.gorseller, cks: cksAdlari, maxOlcek: 6, dekar: true, onDokun: dokun,
                cizgiKaydet: _yalnizGor ? null : (p, cz) => _cizgiKaydet(context, widget.s, c, p, cz),
                cizgiIleBol: (p, cz, oran) => _cizgiIleBol(context, widget.s, c, p, cz, oran),
                bolgeEkle: (p, b, pay) => _bolgeEkle(context, widget.s, c, p, b, pay),
                sinirKaydet: (p, k, da) => _sinirKaydet(context, widget.s, c, p, k, da),
                sinirGeriAl: (p) => _sinirGeriAl(context, widget.s, c, p),
                degisenSinir: _degisenSinirlar(widget.v, widget.s, c)),
          ),
          Positioned(
            right: 6,
            top: 6,
            child: IconButton.filledTonal(
              tooltip: 'Tam ekran',
              icon: const Icon(Icons.fullscreen),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ListenableBuilder(
                  listenable: VeriDeposu.ben,
                  builder: (context, _) {
                    final s2 = widget.sezonBul(VeriDeposu.ben.veri ?? widget.v);
                    final c2 = s2.ciftlikler.firstWhere((x) => x.ad == c.ad, orElse: () => c);
                    return Scaffold(
                      appBar: AppBar(title: Text('${c.ad} · ${s2.sezon}')),
                      body: _HaritaGorunum(
                          p: c2.parseller.where((p) => p.koord.length > 2).toList(),
                          g: c2.gorseller,
                          cks: cksAdlari,
                          maxOlcek: 10,
                          yazi: 13,
                          dekar: true,
                          onDokun: (p, parca) => _parselIslem(context, s2, c2, p, parca: parca),
                          cizgiKaydet: _yalnizGor ? null : (p, cz) => _cizgiKaydet(context, s2, c2, p, cz),
                          cizgiIleBol: (p, cz, oran) => _cizgiIleBol(context, s2, c2, p, cz, oran),
                          bolgeEkle: (p, b, pay) => _bolgeEkle(context, s2, c2, p, b, pay),
                          sinirKaydet: (p, k, da) => _sinirKaydet(context, s2, c2, p, k, da),
                          sinirGeriAl: (p) => _sinirGeriAl(context, s2, c2, p),
                          degisenSinir: _degisenSinirlar(VeriDeposu.ben.veri ?? widget.v, s2, c2)),
                    );
                  },
                ),
              )),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 6),
        child: Text(
            'Parsele dokunarak ${giris ? widget.s.sezon : sonrakiSezon(widget.s.sezon)} sezonu için ürün ve dekar girebilirsiniz. '
            'İki parmakla yakınlaştırabilir, sağ üstteki düğmeyle tam ekran açabilirsiniz. '
            'Ürün rengini değiştirmek için aşağıdaki renk kutusuna dokunun.',
            style: const TextStyle(fontSize: 11.5, color: Renk.soluk)),
      ),
      if (!giris && widget.sezonSec != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.sezonSec,
            icon: const Icon(Icons.event_note_outlined, size: 18),
            label: Text('${sonrakiSezon(widget.s.sezon)} sezonu haritasını aç'),
          ),
        ),
      if (giris && girilmeyen > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('Ürün girilmemiş parsel: $girilmeyen (gri)', style: const TextStyle(fontSize: 12.5, color: Renk.amber)),
        ),
      Wrap(spacing: 10, runSpacing: 4, children: [
        if (widget.v.cks.isNotEmpty)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(border: Border.all(color: Renk.mavi, width: 2.5))),
            const SizedBox(width: 4),
            const Text("Mavi kenarlı: ÇKS'de bildirildi", style: TextStyle(fontSize: 12.5)),
          ]),
        for (final t in {for (final x in c.gorseller) x.tur}.where(_gorselAdlari.containsKey))
          Row(mainAxisSize: MainAxisSize.min, children: [
            {'hat', 'og', 'pivot'}.contains(t)
                ? Container(width: 14, height: 3, color: gorselRengi(t))
                : Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: gorselRengi(t), shape: t == 'direk' ? BoxShape.rectangle : BoxShape.circle)),
            const SizedBox(width: 4),
            Text(_gorselAdlari[t]!, style: const TextStyle(fontSize: 12.5)),
          ]),
        for (final u in urunler)
          InkWell(
            onTap: () => urunRengiSec(context, u),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(color: urunAdRengi(u), borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 4),
                Text('$u: ${excel[u] == null ? (giris ? 'girilmedi' : "Excel'de yok") : _da(excel[u])}', style: const TextStyle(fontSize: 12.5)),
                const Icon(Icons.palette_outlined, size: 14, color: Renk.soluk),
              ]),
            ),
          ),
      ]),
      const BolumBasligi('Ekiliş özeti'),
      Text(
          giris
              ? 'Alanlar: haritadan girilen bilgiler. Karşısında Excel kaydı gösterilir: ${sezonExcelKaynak(widget.s)}.'
              : 'Alanlar: 2026-2027 Ekim Planı (Excel). Haritadan yalnızca ekili ürün cinsi alınır.',
          style: const TextStyle(fontSize: 11.5, color: Renk.soluk)),
      const SizedBox(height: 4),
      Card(
        child: Column(children: [
          for (final u in urunler)
            ListTile(
                dense: true,
                title: Text(u),
                subtitle: giris
                    ? Text('Excel: ${plan[u] == null ? 'yok' : _da(plan[u])}',
                        style: const TextStyle(fontSize: 12))
                    : cinsler.contains(u)
                        ? null
                        : const Text('Haritada bu ürün yok', style: TextStyle(color: Renk.amber, fontSize: 12)),
                trailing: Text(excel[u] == null ? (giris ? 'Girilmedi' : "Excel'de yok") : _da(excel[u]),
                    style: TextStyle(fontWeight: FontWeight.w700, color: excel[u] == null ? Renk.amber : null))),
          ListTile(
              dense: true,
              title: Text(giris ? 'Toplam girilen alan' : 'Toplam ekili alan (Excel)', style: const TextStyle(fontWeight: FontWeight.w800)),
              trailing: Text(excel.isEmpty ? '–' : _da(toplam), style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
      ),
      for (final n in c.notlar.where((n) => !n.contains('uyuşmuyor'))) Padding(padding: const EdgeInsets.only(top: 6), child: BilgiKutusu(yazi: n)),
      if (c.tesis.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Altyapı: ${c.tesis.entries.map((e) => '${switch (e.key) { 'kuyu' => 'kuyu', 'hayvansalKuyu' => 'hayvancılık kuyusu', 'direk' => 'enerji direği', _ => e.key }} ${e.value}').join(', ')}',
              style: const TextStyle(fontSize: 12.5, color: Renk.soluk)),
        ),
    ]);
  }
}

/// Düzlem koordinatı (boylam × cos(enlem), enlem).
typedef _N = (double, double);

/// Düzlem çokgeninin yaklaşık alanı (dekar).
double _dekarAlan(List<_N> k) => k.length < 3 ? 0 : _alan(k) * 111320 * 111320 / 1000;

/// Ekranda yeterince uzun kenarların orta noktaları (köşe eklemek için): (kenarın ilk köşesi, nokta).
List<(int, Offset)> _ortaNoktalar(List<Offset> e, double olcek) => [
      for (var i = 0; i < e.length; i++)
        if ((e[i] - e[(i + 1) % e.length]).distance * olcek > 44) (i, (e[i] + e[(i + 1) % e.length]) / 2)
    ];

/// Kopyalanan parsel şekli (boylam, enlem): başka sezona, çiftliğe ya da yere yapıştırmak için (uygulama açıkken).
(String, List<(double, double)>)? kopyaSekil;
void sekilKopyala(String ad, List<(double, double)> koord) => kopyaSekil = (ad, [...koord]);

/// Çizilen şekli boşluğa oturtur: komşu parsellerle çakışan kısımlar çıkarılır, kalan en büyük parça yeni
/// parselin sınırı olur (kenarlar komşu parsellerin sınırına denk gelir). Çakışma yoksa şekil aynen kalır.
List<(double, double)> bosluguDoldur(List<(double, double)> sekil, Iterable<List<(double, double)>> parseller) {
  if (sekil.length < 3) return sekil;
  final (x0, y0, x1, y1) = _kutu(sekil);
  final o = 4000 / math.max(x1 - x0, y1 - y0);
  Offset d(_N n) => Offset((n.$1 - x0) * o, (n.$2 - y0) * o);
  _N t(Offset e) => (x0 + e.dx / o, y0 + e.dy / o);
  var yol = Path()..addPolygon([for (final c in sekil) d(c)], true);
  var kesti = false;
  for (final k in parseller) {
    if (k.length < 3) continue;
    final (a0, b0, a1, b1) = _kutu(k);
    if (a1 < x0 || a0 > x1 || b1 < y0 || b0 > y1) continue;
    yol = Path.combine(PathOperation.difference, yol, Path()..addPolygon([for (final c in k) d(c)], true));
    kesti = true;
  }
  if (!kesti) return sekil;
  List<Offset>? en;
  var enA = 0.0;
  for (final m in yol.computeMetrics()) {
    final l = <Offset>[
      for (double u = 0; u < m.length; u += 4)
        if (m.getTangentForOffset(u) case final tg?) tg.position,
    ];
    if (l.length < 3) continue;
    final a = _alan([for (final e in l) (e.dx, e.dy)]);
    if (a > enA) {
      enA = a;
      en = l;
    }
  }
  final tum = _alan([for (final c in sekil) (d(c).dx, d(c).dy)]);
  if (en == null || enA < tum * 0.02) return sekil;
  return [for (final e in _sadelestir(en, 1.2)) t(e)];
}

/// Boşluğu doldur: [n] noktasından her yöne ışın atılır, komşu parsel kenarlarına çarpan noktalara daire
/// oturtulur (pivot boşluğu), sonra daire merkezinden ışınlar daireyle ve komşu kenarlarla sınırlanır.
/// Sonuç boşluğun şeklidir; açık kenarlarda daire yayı kalır. Bulunamazsa null.
List<(double, double)>? bosluguBul((double, double) n, List<List<(double, double)>> parseller) {
  if (parseller.any((k) => k.length > 2 && _icinde(n, k))) return null;
  double? isin((double, double) o, double aci) {
    final dx = math.cos(aci), dy = math.sin(aci);
    double? en;
    for (final k in parseller) {
      for (var i = 0; i < k.length; i++) {
        final a = k[i], b = k[(i + 1) % k.length];
        final ex = b.$1 - a.$1, ey = b.$2 - a.$2;
        final den = dx * ey - dy * ex;
        if (den.abs() < 1e-15) continue;
        final t = ((a.$1 - o.$1) * ey - (a.$2 - o.$2) * ex) / den;
        final u = ((a.$1 - o.$1) * dy - (a.$2 - o.$2) * dx) / den;
        if (t > 0 && u >= 0 && u <= 1 && (en == null || t < en)) en = t;
      }
    }
    return en;
  }

  const m = 96;
  var noktalar = <(double, double)>[];
  for (var i = 0; i < m; i++) {
    final a = i * 2 * math.pi / m;
    final t = isin(n, a);
    if (t != null) noktalar.add((n.$1 + t * math.cos(a), n.$2 + t * math.sin(a)));
  }
  if (noktalar.length < 8) return null;
  double ort(Iterable<double> l) => l.reduce((a, b) => a + b) / l.length;
  final uz = [for (final p in noktalar) math.sqrt(math.pow(p.$1 - n.$1, 2) + math.pow(p.$2 - n.$2, 2))]..sort();
  final medyan = uz[uz.length ~/ 2];
  // Uzaktaki (boşluğun açık tarafından kaçan) ışınlar atılır.
  noktalar = [for (final p in noktalar) if (math.sqrt(math.pow(p.$1 - n.$1, 2) + math.pow(p.$2 - n.$2, 2)) <= medyan * 1.6) p];
  (double, double, double)? daire;
  for (var tur = 0; tur < 3 && noktalar.length >= 6; tur++) {
    // Kasa yöntemi: x² + y² + Dx + Ey + F = 0 (merkeze göre kaydırılmış koordinatlarla)
    final cx0 = ort(noktalar.map((p) => p.$1)), cy0 = ort(noktalar.map((p) => p.$2));
    var sxx = 0.0, sxy = 0.0, syy = 0.0, sx = 0.0, sy = 0.0, sxz = 0.0, syz = 0.0, sz = 0.0;
    for (final p in noktalar) {
      final x = p.$1 - cx0, y = p.$2 - cy0, z = x * x + y * y;
      sxx += x * x; sxy += x * y; syy += y * y; sx += x; sy += y; sxz += x * z; syz += y * z; sz += z;
    }
    final nn = noktalar.length.toDouble();
    // [sxx sxy sx; sxy syy sy; sx sy n] [D E F] = -[sxz syz sz]
    final a = [
      [sxx, sxy, sx, -sxz],
      [sxy, syy, sy, -syz],
      [sx, sy, nn, -sz],
    ];
    for (var i = 0; i < 3; i++) {
      var p = i;
      for (var r = i + 1; r < 3; r++) {
        if (a[r][i].abs() > a[p][i].abs()) p = r;
      }
      final g = a[i];
      a[i] = a[p];
      a[p] = g;
      if (a[i][i].abs() < 1e-30) return null;
      for (var r = 0; r < 3; r++) {
        if (r == i) continue;
        final f = a[r][i] / a[i][i];
        for (var c = i; c < 4; c++) {
          a[r][c] -= f * a[i][c];
        }
      }
    }
    final d = a[0][3] / a[0][0], e = a[1][3] / a[1][1], f = a[2][3] / a[2][2];
    final cx = -d / 2, cy = -e / 2, r2 = cx * cx + cy * cy - f;
    if (r2 <= 0) return null;
    daire = (cx + cx0, cy + cy0, math.sqrt(r2));
    final (dx, dy, r) = daire;
    final art = [for (final p in noktalar) (math.sqrt(math.pow(p.$1 - dx, 2) + math.pow(p.$2 - dy, 2)) - r).abs()]..sort();
    final esik = math.max(art[art.length ~/ 2] * 2.5, r * 0.01);
    noktalar = [for (final p in noktalar) if ((math.sqrt(math.pow(p.$1 - dx, 2) + math.pow(p.$2 - dy, 2)) - r).abs() <= esik) p];
  }
  if (daire == null) return null;
  final (cx, cy, r) = daire;
  if (r > medyan * 3) return null;
  final merkez = (cx, cy);
  return [
    for (var i = 0; i < m; i++)
      () {
        final a = i * 2 * math.pi / m;
        final t = math.min(r, isin(merkez, a) ?? r);
        return (cx + t * math.cos(a), cy + t * math.sin(a));
      }(),
  ];
}

/// Sadeleştirme toleransı: şeklin boyutunun binde ikisi (düzlem birimiyle).
double _dekarCm(List<(double, double)> k) {
  final (x0, y0, x1, y1) = _kutu(k);
  return math.max(x1 - x0, y1 - y0) * 0.002;
}

/// Douglas–Peucker: [eps] mesafesinden az sapan ara noktaları atar (kapalı çokgen).
List<Offset> _sadelestir(List<Offset> l, double eps) {
  if (l.length < 4) return l;
  double uzak(Offset p, Offset a, Offset b) {
    final ab = b - a, uz = ab.distance;
    if (uz == 0) return (p - a).distance;
    return ((p.dx - a.dx) * ab.dy - (p.dy - a.dy) * ab.dx).abs() / uz;
  }

  List<Offset> parca(List<Offset> l) {
    if (l.length < 3) return l;
    var en = 0.0, i0 = 0;
    for (var i = 1; i < l.length - 1; i++) {
      final u = uzak(l[i], l.first, l.last);
      if (u > en) {
        en = u;
        i0 = i;
      }
    }
    if (en <= eps) return [l.first, l.last];
    final a = parca(l.sublist(0, i0 + 1)), b = parca(l.sublist(i0));
    return [...a.sublist(0, a.length - 1), ...b];
  }

  // Kapalı çokgeni en uzak iki noktadan ikiye bölüp her yarıyı sadeleştir.
  var j = 0, enU = 0.0;
  for (var i = 1; i < l.length; i++) {
    final u = (l[i] - l[0]).distance;
    if (u > enU) {
      enU = u;
      j = i;
    }
  }
  final a = parca(l.sublist(0, j + 1)), b = parca([...l.sublist(j), l.first]);
  return [...a.sublist(0, a.length - 1), ...b.sublist(0, b.length - 1)];
}

double _alan(List<_N> k) {
  var a = 0.0;
  for (var i = 0; i < k.length; i++) {
    final p = k[i], q = k[(i + 1) % k.length];
    a += p.$1 * q.$2 - q.$1 * p.$2;
  }
  return a.abs() / 2;
}

bool _icinde(_N n, List<_N> k) {
  var ic = false;
  for (var i = 0, j = k.length - 1; i < k.length; j = i++) {
    final a = k[i], b = k[j];
    if ((a.$2 > n.$2) != (b.$2 > n.$2) && n.$1 < (b.$1 - a.$1) * (n.$2 - a.$2) / (b.$2 - a.$2) + a.$1) ic = !ic;
  }
  return ic;
}

double _kenarUzakligi(_N n, List<_N> k) {
  var m = double.infinity;
  for (var i = 0; i < k.length; i++) {
    final a = k[i], b = k[(i + 1) % k.length];
    final dx = b.$1 - a.$1, dy = b.$2 - a.$2;
    final l2 = dx * dx + dy * dy;
    final t = l2 == 0 ? 0.0 : (((n.$1 - a.$1) * dx + (n.$2 - a.$2) * dy) / l2).clamp(0.0, 1.0);
    final x = a.$1 + t * dx - n.$1, y = a.$2 + t * dy - n.$2;
    m = math.min(m, math.sqrt(x * x + y * y));
  }
  return m;
}

/// Ayırma çizgisi (açı°, konum %) → normal ve sabit: n·p = c.
(double, double, double) _cizgiDenklemi(List<_N> k, (double, double) cz) {
  final r = cz.$1 * math.pi / 180;
  final nx = -math.sin(r), ny = math.cos(r);
  var mn = double.infinity, mx = -double.infinity;
  for (final p in k) {
    final v = nx * p.$1 + ny * p.$2;
    mn = math.min(mn, v);
    mx = math.max(mx, v);
  }
  return (nx, ny, mn + (mx - mn) * cz.$2.clamp(0, 100) / 100);
}

/// Çokgenin çevreleyen kutusu (x0, y0, x1, y1).
(double, double, double, double) _kutu(List<_N> k) {
  final xs = k.map((e) => e.$1), ys = k.map((e) => e.$2);
  return (xs.reduce(math.min), ys.reduce(math.min), xs.reduce(math.max), ys.reduce(math.max));
}

/// Kayıtlı bölge (parsel kutusuna göre yüzde) → düzlem çokgeni.
List<_N> _bolgePoligon(List<_N> k, ParselBolge b) {
  final (x0, y0, x1, y1) = _kutu(k);
  final w = x1 - x0, h = y1 - y0, v = b.$2;
  _N n(double px, double py) => (x0 + px / 100 * w, y0 + py / 100 * h);
  switch (b.$1) {
    case 'D' when v.length >= 4:
      return [n(v[0], v[1]), n(v[2], v[1]), n(v[2], v[3]), n(v[0], v[3])];
    case 'C' when v.length >= 4:
      return [
        for (var i = 0; i < 48; i++)
          n(v[0] + v[2] * math.cos(i * math.pi / 24), v[1] + v[3] * math.sin(i * math.pi / 24))
      ];
    case 'P' when v.length >= 6:
      return [for (var i = 0; i + 1 < v.length; i += 2) n(v[i], v[i + 1])];
  }
  return const [];
}

/// Düzlem çokgeni → parsel kutusuna göre yüzde (tek tip: 'D', 'C' ya da 'P').
ParselBolge _bolgeKodla(List<_N> k, String tip, List<_N> noktalar) {
  final (x0, y0, x1, y1) = _kutu(k);
  final w = x1 - x0, h = y1 - y0;
  double px(double x) => (x - x0) / w * 100;
  double py(double y) => (y - y0) / h * 100;
  if (tip == 'C') {
    // noktalar: [merkez, çevredeki nokta]
    final r = math.sqrt(math.pow(noktalar[1].$1 - noktalar[0].$1, 2) + math.pow(noktalar[1].$2 - noktalar[0].$2, 2));
    return ('C', [px(noktalar[0].$1), py(noktalar[0].$2), r / w * 100, r / h * 100]);
  }
  if (tip == 'D') {
    return ('D', [
      px(math.min(noktalar[0].$1, noktalar[1].$1)), py(math.min(noktalar[0].$2, noktalar[1].$2)),
      px(math.max(noktalar[0].$1, noktalar[1].$1)), py(math.max(noktalar[0].$2, noktalar[1].$2)),
    ]);
  }
  return ('P', [for (final n in noktalar) ...[px(n.$1), py(n.$2)]]);
}

/// Parselin bölgelere ve kalana düşen alan payları (ızgara örneklemesiyle; bölgeler, sonda kalan).
List<double> _bolgePaylari(List<_N> k, List<List<_N>> bolgeler) {
  final (x0, y0, x1, y1) = _kutu(k);
  final say = List<int>.filled(bolgeler.length + 1, 0);
  var toplam = 0;
  const n = 70;
  for (var i = 0; i < n; i++) {
    for (var j = 0; j < n; j++) {
      final p = (x0 + (i + 0.5) / n * (x1 - x0), y0 + (j + 0.5) / n * (y1 - y0));
      if (!_icinde(p, k)) continue;
      toplam++;
      var hangi = bolgeler.length;
      for (var b = 0; b < bolgeler.length; b++) {
        if (bolgeler[b].length > 2 && _icinde(p, bolgeler[b])) {
          hangi = b;
          break;
        }
      }
      say[hangi]++;
    }
  }
  return [for (final x in say) toplam == 0 ? 0.0 : x / toplam];
}

/// İki noktadan geçen çizgi → (açı°, konum %) bu çokgene göre.
(double, double) _cizgiAl(List<_N> k, _N p, _N q) {
  final aci = math.atan2(q.$2 - p.$2, q.$1 - p.$1) * 180 / math.pi;
  final r = aci * math.pi / 180;
  final nx = -math.sin(r), ny = math.cos(r);
  var mn = double.infinity, mx = -double.infinity;
  for (final x in k) {
    final v = nx * x.$1 + ny * x.$2;
    mn = math.min(mn, v);
    mx = math.max(mx, v);
  }
  final m = ((p.$1 + q.$1) / 2, (p.$2 + q.$2) / 2);
  return (aci, ((nx * m.$1 + ny * m.$2 - mn) / (mx - mn) * 100).clamp(1.0, 99.0));
}

/// Çokgeni bir çizginin bir yanına kırpar (Sutherland–Hodgman).
List<_N> _kirp(List<_N> k, (double, double, double) d, bool birinciYan) {
  double f(_N p) {
    final v = d.$1 * p.$1 + d.$2 * p.$2 - d.$3;
    return birinciYan ? v : -v;
  }

  final out = <_N>[];
  for (var i = 0; i < k.length; i++) {
    final a = k[i], b = k[(i + 1) % k.length];
    final fa = f(a), fb = f(b);
    if (fa <= 0) out.add(a);
    if ((fa < 0 && fb > 0) || (fa > 0 && fb < 0)) {
      final t = fa / (fa - fb);
      out.add((a.$1 + t * (b.$1 - a.$1), a.$2 + t * (b.$2 - a.$2)));
    }
  }
  return out;
}

/// Parseli çizgilerle parçalara ayırır: 1. parça 1. çizginin bir yanı, sonraki parçalar
/// iki çizgi arası, son parça son çizginin öbür yanı.
List<List<_N>> _parcala(List<_N> k, List<(double, double)> cizgiler) {
  final d = [for (final c in cizgiler) _cizgiDenklemi(k, c)];
  return [
    for (var i = 0; i <= d.length; i++)
      () {
        var p = k;
        if (i > 0) p = _kirp(p, d[i - 1], false);
        if (i < d.length) p = _kirp(p, d[i], true);
        return p;
      }(),
  ];
}

/// Çizgi çizilmemiş bölünmüş parsel: kuzey–güney doğrultulu çizgiler, parçalar dekar oranında.
List<(double, double)> _otomatikCizgiler(List<_N> k, List<double> dekarlar) {
  final toplam = dekarlar.fold<double>(0, (a, b) => a + b);
  final oran = [for (final d in dekarlar) toplam > 0 ? d / toplam : 1 / dekarlar.length];
  final tumAlan = _alan(k);
  final l = <(double, double)>[];
  var birikim = 0.0;
  for (var i = 0; i < oran.length - 1; i++) {
    birikim += oran[i];
    var a = 0.0, b = 100.0;
    for (var j = 0; j < 30; j++) {
      final m = (a + b) / 2;
      final p = _kirp(k, _cizgiDenklemi(k, (90, m)), true);
      if ((p.length < 3 ? 0 : _alan(p)) / tumAlan < birikim) {
        a = m;
      } else {
        b = m;
      }
    }
    l.add((90, (a + b) / 2));
  }
  return l;
}

/// Haritanın düzlem geometrisi ve her parselin yazı noktası (üstteki
/// küçük parsellerin dışında, kenarlardan en uzak iç nokta).
class _Geometri {
  _Geometri(List<TarlaParsel> p, [List<TarlaGorsel> g = const []]) {
    final tum = [for (final x in p) ...x.koord];
    final lat0 = tum.map((c) => c.$2).reduce((a, b) => a + b) / tum.length;
    kx = math.cos(lat0 * math.pi / 180);
    for (final x in p) {
      poligon[x] = [for (final c in x.koord) (c.$1 * kx, c.$2)];
      alan[x] = _alan(poligon[x]!);
      if (x.bolgeler.isNotEmpty && x.urunler.length == x.bolgeler.length + 1 && poligon[x]!.length > 2) {
        bolge[x] = [for (final b in x.bolgeler) _bolgePoligon(poligon[x]!, b)];
        bolgePay[x] = _bolgePaylari(poligon[x]!, bolge[x]!);
      } else if (x.urunler.length > 1 && poligon[x]!.length > 2) {
        final cz = x.bolme.length == x.urunler.length - 1
            ? x.bolme
            : _otomatikCizgiler(poligon[x]!, [for (final u in x.urunler) u.$2]);
        parca[x] = _parcala(poligon[x]!, cz);
      }
    }
    sirali = [...p]..sort((a, b) => alan[b]!.compareTo(alan[a]!));
    gorsel = [
      for (final x in g)
        if (x.koord.isNotEmpty) (x, [for (final c in x.koord) (c.$1 * kx, c.$2)])
    ];
    final hepsi = [...poligon.values.expand((e) => e), ...gorsel.expand((e) => e.$2)];
    final xs = hepsi.map((e) => e.$1), ys = hepsi.map((e) => e.$2);
    minX = xs.reduce(math.min);
    maxX = xs.reduce(math.max);
    minY = ys.reduce(math.min);
    maxY = ys.reduce(math.max);
    for (final x in p) {
      yaziNoktasi[x] = _nokta(x);
    }
  }

  final poligon = <TarlaParsel, List<_N>>{};
  final alan = <TarlaParsel, double>{};

  /// Parçalara bölünmüş parsellerin parçaları (ürün sırasıyla).
  final parca = <TarlaParsel, List<List<_N>>>{};

  /// Parsel içinde çizilen bölgeler (düzlem çokgenleri) ve bölge/kalan alan payları.
  final bolge = <TarlaParsel, List<List<_N>>>{};
  final bolgePay = <TarlaParsel, List<double>>{};
  final yaziNoktasi = <TarlaParsel, _N>{};

  /// KMZ görselleri (kuyu, direk, hatlar) düzlem koordinatında.
  late final List<(TarlaGorsel, List<_N>)> gorsel;
  late final List<TarlaParsel> sirali;
  late final double minX, maxX, minY, maxY;

  /// Boylam düzeltmesi: düzlem x = boylam × kx.
  late final double kx;

  _N _nokta(TarlaParsel x) {
    final k = poligon[x]!;
    final ustteki = [
      for (final y in sirali)
        if (y != x && alan[y]! < alan[x]!) poligon[y]!
    ];
    final bx = k.map((e) => e.$1), by = k.map((e) => e.$2);
    final x0 = bx.reduce(math.min), x1 = bx.reduce(math.max), y0 = by.reduce(math.min), y1 = by.reduce(math.max);
    _N? en;
    var skor = -1.0;
    const n = 28;
    for (var i = 0; i <= n; i++) {
      for (var j = 0; j <= n; j++) {
        final q = (x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * j / n);
        if (!_icinde(q, k) || ustteki.any((u) => _icinde(q, u))) continue;
        var d = _kenarUzakligi(q, k);
        for (final u in ustteki) {
          d = math.min(d, _kenarUzakligi(q, u));
        }
        if (d > skor) {
          skor = d;
          en = q;
        }
      }
    }
    if (en != null) return en;
    return (k.map((e) => e.$1).reduce((a, b) => a + b) / k.length, k.map((e) => e.$2).reduce((a, b) => a + b) / k.length);
  }

  /// Ekran (yakınlaştırma öncesi) → düzlem.
  _N Function(Offset) tersDonusum(Size size) {
    final olcek = 0.94 * math.min(size.width / (maxX - minX), size.height / (maxY - minY));
    final ox = (size.width - (maxX - minX) * olcek) / 2, oy = (size.height - (maxY - minY) * olcek) / 2;
    return (e) => (minX + (e.dx - ox) / olcek, minY + (size.height - e.dy - oy) / olcek);
  }

  /// Düzlem → ekran (yakınlaştırma öncesi).
  Offset Function(_N) donusum(Size size) {
    final olcek = 0.94 * math.min(size.width / (maxX - minX), size.height / (maxY - minY));
    final ox = (size.width - (maxX - minX) * olcek) / 2, oy = (size.height - (maxY - minY) * olcek) / 2;
    return (c) => Offset(ox + (c.$1 - minX) * olcek, size.height - (oy + (c.$2 - minY) * olcek));
  }
}

/// Yakınlaştırılabilir harita: parseller yakınlaşır, yazılar sabit boyutta
/// kalır; üst üste gelen yazılar gizlenir, yakınlaştırınca görünür.
class _HaritaGorunum extends StatefulWidget {
  const _HaritaGorunum({required this.p, this.g = const [], required this.cks, this.maxOlcek = 6, this.yazi = 11.5, this.dekar = false, this.onDokun, this.cizgiKaydet, this.cizgiIleBol, this.bolgeEkle, this.sinirKaydet, this.sinirGeriAl, this.degisenSinir = const {}});
  final List<TarlaParsel> p;
  final List<TarlaGorsel> g;
  final Set<String> cks;
  final double maxOlcek, yazi;

  /// Etikette alan da yazılsın mı (yalnızca haritadan girilen yeni sezonda).
  final bool dekar;
  /// Dokunulan parsel ve (bölünmüş parselde) parça sırası.
  final void Function(TarlaParsel, int?)? onDokun;

  /// Bölünmüş parsellerde ayırma çizgisini doğrudan haritada çizip kaydetme.
  final Future<void> Function(TarlaParsel p, List<(double, double)> cizgiler)? cizgiKaydet;

  /// Bölünmemiş parselin üzerinden çizgi çekilince: parseli bu çizgiyle iki parçaya böler.
  /// [oran]: çizginin 1. yanındaki alanın parsele oranı.
  final Future<void> Function(TarlaParsel p, (double, double) cizgi, double oran)? cizgiIleBol;

  /// Parsel içine dikdörtgen, daire ya da noktalarla çizilen bölge: [pay] bölgenin parsele oranı.
  final Future<void> Function(TarlaParsel p, ParselBolge bolge, double pay)? bolgeEkle;

  /// Parsel sınırını yeniden çizme / yeni parsel ekleme: [p] null ise yeni parsel; [koord] (boylam, enlem).
  final Future<bool> Function(TarlaParsel? p, List<(double, double)> koord, double dekar)? sinirKaydet;

  /// Değiştirilmiş sınırı KMZ'deki hâline döndürür (haritadan eklenen parseli kaldırır).
  final Future<bool> Function(TarlaParsel p)? sinirGeriAl;

  /// Sınırı haritadan değiştirilmiş (ya da haritadan eklenmiş) parsel adları.
  final Set<String> degisenSinir;
  @override
  State<_HaritaGorunum> createState() => _HaritaGorunumState();
}

class _HaritaGorunumState extends State<_HaritaGorunum> {
  final _ctl = TransformationController();
  late _Geometri _g = _Geometri(widget.p, widget.g);

  @override
  void didUpdateWidget(covariant _HaritaGorunum old) {
    super.didUpdateWidget(old);
    if (old.p != widget.p) {
      final ayniCizim = old.p.length == widget.p.length &&
          [for (var i = 0; i < old.p.length; i++) identical(old.p[i].koord, widget.p[i].koord)].every((e) => e);
      _g = _Geometri(widget.p, widget.g);
      if (_duzenParsel != null && !_g.poligon.containsKey(_duzenParsel)) {
        final ad = _duzenParsel!.ad;
        final yeni = widget.p.where((x) => x.ad == ad).firstOrNull;
        if (yeni == null || _kaydediliyor) {
          _duzenBirak();
        } else {
          _duzenParsel = yeni;
        }
      }
      if (!ayniCizim && !_cizim) _ctl.value = Matrix4.identity();
    }
  }

  // Çizim kipi: 'cizgi' (ayırma çizgisi), 'kare', 'daire', 'nokta' (dokunarak köşe).
  String _sekil = 'cizgi';
  final List<Offset> _noktalar = [];

  // Sınır düzenleme: seçilen parsel, köşeleri (düzlem), seçili / sürüklenen köşe, baştan çizim.
  TarlaParsel? _duzenParsel;
  List<_N> _duzen = [];
  int? _secKose, _surukle;
  bool _yenidenCiz = false;
  double get _olcek => _ctl.value.getMaxScaleOnAxis();

  void _duzenBirak() {
    _duzenParsel = null;
    _duzen = [];
    _secKose = _surukle = null;
    _yenidenCiz = false;
    _yeniDuzen = false;
    _tasiBas = null;
    _tasiIlk = null;
  }

  // Parsel dışına çizilen şekil: yeni parsel olarak köşeleri düzeltilir, içinden sürüklenerek taşınır.
  bool _yeniDuzen = false;
  _N? _tasiBas;
  List<_N>? _tasiIlk;
  bool get _duzenleniyor => (_sekil == 'sinir' && _duzenParsel != null && !_yenidenCiz) || (_sekil == 'yeni' && _yeniDuzen);

  bool get _noktaDokunusu =>
      _sekil == 'nokta' || _sekil == 'doldur' || (_sekil == 'yeni' && !_yeniDuzen) || (_sekil == 'sinir' && (_duzenParsel == null || _yenidenCiz));

  void _noktaEkle(Offset e, Size size) {
    final t = _g.tersDonusum(size);
    setState(() {
      switch (_sekil) {
        case 'nokta':
          _noktalar.add(e);
        case 'doldur':
          final b = bosluguBul(t(e), [for (final x in _g.sirali) _g.poligon[x]!]);
          if (b == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Boşluk bulunamadı: parsellerin arasındaki boş alanın ortasına dokunun (parselin içine değil).'))));
          } else {
            final o = bosluguDoldur(b, [for (final x in _g.sirali) _g.poligon[x]!]);
            final sade = [for (final c in _sadelestir([for (final c in o) Offset(c.$1, c.$2)], _dekarCm(o))) (c.dx, c.dy)];
            _duzenBirak();
            _sekil = 'yeni';
            _yeniDuzen = true;
            _duzen = sade.length >= 3 ? sade : o;
            WidgetsBinding.instance.addPostFrameCallback((_) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Boşluk dolduruldu. Gerekirse köşeleri düzeltip "Parseli kaydet"e basın.'))));
          }
        case 'yeni':
          _duzen.add(t(e));
        case 'sinir' when _yenidenCiz:
          _duzen.add(t(e));
        case 'sinir':
          final x = _bul(e, size);
          if (x != null && _g.poligon[x.$1]!.length > 2) {
            _duzenParsel = x.$1;
            _duzen = [..._g.poligon[x.$1]!];
            _secKose = null;
          }
      }
    });
  }

  /// Sürükleme başlangıcı: bir köşe ya da kenar ortası yakınında mı (kenar ortasında yeni köşe açılır).
  bool _koseYakala(Offset e, Size size) {
    if (!_duzenleniyor || _duzen.isEmpty) return false;
    final d = _g.donusum(size);
    final ekran = [for (final c in _duzen) d(c)];
    final r = 24 / _olcek;
    int? en;
    var enU = r;
    for (var i = 0; i < ekran.length; i++) {
      final u = (ekran[i] - e).distance;
      if (u < enU) {
        enU = u;
        en = i;
      }
    }
    if (en != null) {
      _surukle = en;
      return true;
    }
    for (final (i, o) in _ortaNoktalar(ekran, _olcek)) {
      if ((o - e).distance < r * 0.8) {
        _duzen.insert(i + 1, _g.tersDonusum(size)(o));
        _surukle = i + 1;
        return true;
      }
    }
    // Yeni parsel şeklinin içinden tutulunca şekil bütün olarak taşınır.
    final n = _g.tersDonusum(size)(e);
    if (_sekil == 'yeni' && _duzen.length > 2 && _icinde(n, _duzen)) {
      _tasiBas = n;
      _tasiIlk = [..._duzen];
      return true;
    }
    return false;
  }

  Future<void> _sinirKaydetBas() async {
    final k = [for (final c in _duzen) (c.$1 / _g.kx, c.$2)];
    final p = _sekil == 'yeni' ? null : _duzenParsel;
    if (k.length < 3 || widget.sinirKaydet == null) return;
    setState(() => _kaydediliyor = true);
    final ok = await widget.sinirKaydet!(p, k, _dekarAlan(_duzen));
    if (!mounted) return;
    setState(() {
      _kaydediliyor = false;
      if (ok) _duzenBirak();
    });
  }

  Future<void> _sinirGeriAlBas() async {
    final p = _duzenParsel;
    if (p == null || widget.sinirGeriAl == null) return;
    setState(() => _kaydediliyor = true);
    final ok = await widget.sinirGeriAl!(p);
    if (!mounted) return;
    setState(() {
      _kaydediliyor = false;
      if (ok) _duzenBirak();
    });
  }
  Size _sonBoyut = Size.zero;

  Future<void> _sekilBitir(Size size, {List<Offset>? noktalar}) async {
    final a = _bas, b = _son;
    setState(() => _bas = _son = null);
    final t = _g.tersDonusum(size);
    List<_N> duz;
    List<_N> kod;
    if (_sekil == 'nokta') {
      if (noktalar == null || noktalar.length < 3) return;
      kod = duz = [for (final x in noktalar) t(x)];
    } else {
      if (a == null || b == null || (a - b).distance < 12) return;
      final p = t(a), q = t(b);
      kod = [p, q];
      if (_sekil == 'kare') {
        duz = [(p.$1, p.$2), (q.$1, p.$2), (q.$1, q.$2), (p.$1, q.$2)];
      } else {
        final r = math.sqrt(math.pow(q.$1 - p.$1, 2) + math.pow(q.$2 - p.$2, 2));
        duz = [for (var i = 0; i < 48; i++) (p.$1 + r * math.cos(i * math.pi / 24), p.$2 + r * math.sin(i * math.pi / 24))];
      }
    }
    final o = (duz.map((e) => e.$1).reduce((x, y) => x + y) / duz.length, duz.map((e) => e.$2).reduce((x, y) => x + y) / duz.length);
    TarlaParsel? hedef;
    for (final x in _g.sirali.reversed) {
      if (x.tip == 'diger') continue;
      if (_icinde(_sekil == 'daire' ? kod.first : o, _g.poligon[x]!)) {
        hedef = x;
        break;
      }
    }
    if (hedef == null && widget.sinirKaydet != null) {
      // Parsel dışına çizilen şekil yeni parsel olur: önce şekil düzeltilir, sonra ad, ürün ve dekar girilir.
      // Komşu parsellerle çakışan kısımlar çıkarılır: şekil boşluğa oturur (kenarlar komşu sınırlara denk gelir).
      final tam = _sekil == 'daire'
          ? [for (var i = 0; i < 96; i++) (o.$1 + (duz[0].$1 - o.$1) * math.cos(i * math.pi / 48) - (duz[0].$2 - o.$2) * math.sin(i * math.pi / 48),
              o.$2 + (duz[0].$1 - o.$1) * math.sin(i * math.pi / 48) + (duz[0].$2 - o.$2) * math.cos(i * math.pi / 48))]
          : duz;
      final oturan = bosluguDoldur(tam, [for (final x in _g.sirali) _g.poligon[x]!]);
      final oturdu = !identical(oturan, tam);
      final yeni = oturdu || _sekil != 'daire' ? oturan : [for (var i = 0; i < tam.length; i += 4) tam[i]];
      setState(() {
        _noktalar.clear();
        _duzenBirak();
        _sekil = 'yeni';
        _yeniDuzen = true;
        _duzen = yeni;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(oturdu
              ? 'Şekil boşluğa oturtuldu: komşu parsellerle çakışan kısımlar çıkarıldı. Gerekirse köşeleri düzeltip '
                  '"Parseli kaydet"e basın.'
              : 'Şekil parsel dışında: yeni parsel olarak düzeltip "Parseli kaydet"e basın. '
                  'Köşeleri sürükleyebilir, şeklin içinden tutup taşıyabilirsiniz.')));
      return;
    }
    if (hedef == null || widget.bolgeEkle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şekli bir parselin içine çizin (ortası parselin içinde kalmalı).')));
      return;
    }
    final k = _g.poligon[hedef]!;
    final b0 = _bolgeKodla(k, _sekil == 'kare' ? 'D' : (_sekil == 'daire' ? 'C' : 'P'), kod);
    final pay = _bolgePaylari(k, [_bolgePoligon(k, b0)]).first;
    setState(_noktalar.clear);
    await widget.bolgeEkle!(hedef, b0, pay);
  }

  // Çizim kipi: bölünmüş parselin üzerinden çekilen çizgi.
  bool _cizim = false;
  Offset? _bas, _son;
  (TarlaParsel, List<(double, double)>)? _bekleyen;
  bool _kaydediliyor = false;

  List<(double, double)> _mevcutCizgiler(TarlaParsel x) => x.bolme.length == x.urunler.length - 1
      ? x.bolme
      : _otomatikCizgiler(_g.poligon[x]!, [for (final u in x.urunler) u.$2]);

  Future<void> _cizgiBitir(Size size) async {
    final a = _bas, b = _son;
    setState(() => _bas = _son = null);
    if (a == null || b == null || (a - b).distance < 12) return;
    final t = _g.tersDonusum(size);
    final p = t(a), q = t(b);
    // Çizginin geçtiği bölünmüş parsel: orta noktayı içeren, yoksa çizgi üzerindeki noktalardan en çoğunu içeren.
    TarlaParsel? hedef;
    var enCok = 0;
    for (final x in _g.parca.keys) {
      final k = _g.poligon[x]!;
      var n = 0;
      for (var i = 0; i <= 20; i++) {
        final f = i / 20;
        if (_icinde((p.$1 + (q.$1 - p.$1) * f, p.$2 + (q.$2 - p.$2) * f), k)) n++;
      }
      if (n > enCok) {
        enCok = n;
        hedef = x;
      }
    }
    if (hedef == null) {
      // Bölünmemiş bir parselden geçiyorsa o parseli bu çizgiyle iki parçaya bölmeyi öner.
      TarlaParsel? duz;
      var enIc = 0;
      for (final x in _g.sirali.reversed) {
        if (x.tip == 'diger') continue;
        final k = _g.poligon[x]!;
        var n = 0;
        for (var i = 0; i <= 20; i++) {
          final f = i / 20;
          if (_icinde((p.$1 + (q.$1 - p.$1) * f, p.$2 + (q.$2 - p.$2) * f), k)) n++;
        }
        if (n > enIc) {
          enIc = n;
          duz = x;
        }
      }
      if (duz == null || widget.cizgiIleBol == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Çizgiyi bir parselin üzerinden, ayırmak istediğiniz yere çekin.')));
        return;
      }
      final k = _g.poligon[duz]!;
      final cz = _cizgiAl(k, p, q);
      final yan = _kirp(k, _cizgiDenklemi(k, cz), true);
      final oran = yan.length < 3 ? 0.5 : _alan(yan) / _alan(k);
      await widget.cizgiIleBol!(duz, cz, oran);
      return;
    }
    final k = _g.poligon[hedef]!;
    final aci = math.atan2(q.$2 - p.$2, q.$1 - p.$1) * 180 / math.pi;
    final r = aci * math.pi / 180;
    final nx = -math.sin(r), ny = math.cos(r);
    var mn = double.infinity, mx = -double.infinity;
    for (final x in k) {
      final v = nx * x.$1 + ny * x.$2;
      mn = math.min(mn, v);
      mx = math.max(mx, v);
    }
    final m = ((p.$1 + q.$1) / 2, (p.$2 + q.$2) / 2);
    final konum = ((nx * m.$1 + ny * m.$2 - mn) / (mx - mn) * 100).clamp(1.0, 99.0);
    final yeni = (aci, konum);
    var l = [...(_bekleyen?.$1 == hedef ? _bekleyen!.$2 : _mevcutCizgiler(hedef))];
    if (l.length <= 1) {
      l = [yeni];
    } else {
      // Üç parçalı parselde yeni çizgi, orta noktasına en yakın eski çizginin yerine geçer.
      var en = 0;
      var enUzak = double.infinity;
      for (var i = 0; i < l.length; i++) {
        final d = _cizgiDenklemi(k, l[i]);
        final u = (d.$1 * m.$1 + d.$2 * m.$2 - d.$3).abs();
        if (u < enUzak) {
          enUzak = u;
          en = i;
        }
      }
      l[en] = yeni;
    }
    // Çizginin yönüne göre parça sırası: 1. ürün önceki rengini korusun diye eski 1. parçanın
    // ağırlık merkezi hangi yandaysa o yan seçilir.
    final eski = _g.parca[hedef]!;
    if (eski.isNotEmpty && eski.first.length > 2 && l.length == 1) {
      final e = eski.first;
      final ox = e.map((x) => x.$1).reduce((a, b) => a + b) / e.length, oy = e.map((x) => x.$2).reduce((a, b) => a + b) / e.length;
      final d = _cizgiDenklemi(k, l.first);
      if (d.$1 * ox + d.$2 * oy - d.$3 > 0) l = [((l.first.$1 + 180) % 360, 100 - l.first.$2)];
    }
    _onizle(hedef, l);
  }

  void _onizle(TarlaParsel x, List<(double, double)> l) {
    setState(() {
      _bekleyen = (x, l);
      _g.parca[x] = _parcala(_g.poligon[x]!, l);
    });
  }

  /// Renkleri (ürün yerlerini) çevirir: çizgiler ters yönde ve ters sırada.
  void _cevir() {
    final b = _bekleyen;
    if (b == null) return;
    _onizle(b.$1, [for (final c in b.$2.reversed) ((c.$1 + 180) % 360, 100 - c.$2)]);
  }

  void _iptal() {
    final b = _bekleyen;
    setState(() {
      _bekleyen = null;
      if (b != null) _g.parca[b.$1] = _parcala(_g.poligon[b.$1]!, _mevcutCizgiler(b.$1));
    });
  }

  Future<void> _kaydet() async {
    final b = _bekleyen;
    if (b == null || widget.cizgiKaydet == null) return;
    setState(() => _kaydediliyor = true);
    try {
      await widget.cizgiKaydet!(b.$1, b.$2);
      if (mounted) setState(() => _bekleyen = null);
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  /// Dokunulan noktadaki en küçük parsel.
  (TarlaParsel, int?)? _bul(Offset n, Size size) {
    final d = _g.donusum(size);
    for (final x in _g.sirali.reversed) {
      final yol = Path()..addPolygon([for (final c in _g.poligon[x]!) d(c)], true);
      if (!yol.contains(n)) continue;
      // Bölge çizilmiş parselde dokunulan bölge; değilse kalan (son parça).
      final bolgeler = _g.bolge[x];
      if (bolgeler != null) {
        for (var i = 0; i < bolgeler.length; i++) {
          if (bolgeler[i].length > 2 && (Path()..addPolygon([for (final c in bolgeler[i]) d(c)], true)).contains(n)) {
            return (x, i);
          }
        }
        return (x, bolgeler.length);
      }
      // Bölünmüş parselde dokunulan parça.
      final parcalar = _g.parca[x];
      if (parcalar != null) {
        for (var i = 0; i < parcalar.length; i++) {
          if (parcalar[i].length < 3) continue;
          if ((Path()..addPolygon([for (final c in parcalar[i]) d(c)], true)).contains(n)) return (x, i);
        }
      }
      return (x, null);
    }
    return null;
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: UrunRenkleri.ben, builder: (context, _) => _yap(context));

  Widget _yap(BuildContext context) {
    final cizilebilir = widget.cizgiKaydet != null;
    return ClipRect(
        child: Stack(fit: StackFit.expand, children: [
          InteractiveViewer(
            transformationController: _ctl,
            maxScale: widget.maxOlcek,
            panEnabled: !_cizim || const {'nokta', 'yeni', 'sinir', 'doldur'}.contains(_sekil),
            scaleEnabled: !_cizim || const {'nokta', 'yeni', 'sinir', 'doldur'}.contains(_sekil),
            child: LayoutBuilder(builder: (context, k) {
              final d = _g.donusum(k.biggest);
              final resim = AnimatedBuilder(
                animation: _ctl,
                builder: (_, __) => CustomPaint(
                    size: Size.infinite,
                    painter: _PoligonCizer(_g, widget.cks,
                        cizim: _bas == null || _son == null ? null : (_bas!, _son!),
                        sekil: _sekil,
                        noktalar: [..._noktalar],
                        duzen: _cizim && (_sekil == 'yeni' || _sekil == 'sinir') ? [for (final c in _duzen) d(c)] : null,
                        duzenKapali: (_sekil == 'sinir' && !_yenidenCiz) || (_sekil == 'yeni' && _yeniDuzen),
                        secKose: _secKose,
                        olcek: _olcek)),
              );
              _sonBoyut = k.biggest;
              if (_cizim && _noktaDokunusu) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (e) => _noktaEkle(e.localPosition, k.biggest),
                  child: resim,
                );
              }
              if (_cizim && (_sekil == 'sinir' || (_sekil == 'yeni' && _yeniDuzen))) {
                // Köşe ya da kenar ortası tutulunca sürükleme; başka yerde harita kayar / yakınlaşır.
                return RawGestureDetector(
                  behavior: HitTestBehavior.opaque,
                  gestures: {
                    _KoseSurukle: GestureRecognizerFactoryWithHandlers<_KoseSurukle>(
                      _KoseSurukle.new,
                      (r) => r
                        ..kabul = ((e) => _koseYakala(e, k.biggest))
                        ..onUpdate = ((e) {
                          final n = _g.tersDonusum(k.biggest)(e.localPosition);
                          if ((_tasiBas, _tasiIlk) case (final b?, final ilk?)) {
                            setState(() => _duzen = [for (final c in ilk) (c.$1 + n.$1 - b.$1, c.$2 + n.$2 - b.$2)]);
                            return;
                          }
                          final i = _surukle;
                          if (i == null || i >= _duzen.length) return;
                          setState(() => _duzen[i] = n);
                        })
                        ..onEnd = ((_) => setState(() {
                              if (_tasiBas == null) _secKose = _surukle;
                              _surukle = null;
                              _tasiBas = _tasiIlk = null;
                            }))
                        ..onCancel = (() => setState(() {
                              if (_tasiBas == null) _secKose = _surukle;
                              _surukle = null;
                              _tasiBas = _tasiIlk = null;
                            })),
                    ),
                  },
                  child: resim,
                );
              }
              if (_cizim) {
                // Çizim kipinde parmak hareketi hemen çizgiye ayrılır (sayfa kaymaz, harita kaymaz).
                return RawGestureDetector(
                  behavior: HitTestBehavior.opaque,
                  gestures: {
                    _HemenPan: GestureRecognizerFactoryWithHandlers<_HemenPan>(
                      _HemenPan.new,
                      (r) => r
                        ..onStart = ((e) => setState(() => _bas = _son = e.localPosition))
                        ..onUpdate = ((e) => setState(() => _son = e.localPosition))
                        ..onEnd = ((_) => _sekil == 'cizgi' ? _cizgiBitir(k.biggest) : _sekilBitir(k.biggest)),
                    ),
                  },
                  child: resim,
                );
              }
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: widget.onDokun == null
                    ? null
                    : (e) {
                        final x = _bul(e.localPosition, k.biggest);
                        if (x != null) widget.onDokun!(x.$1, x.$2);
                      },
                child: resim,
              );
            }),
          ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _ctl,
              builder: (_, __) =>
                  CustomPaint(size: Size.infinite, painter: _YaziCizer(_g, _ctl.value.clone(), widget.yazi, widget.dekar)),
            ),
          ),
          if (cizilebilir)
            Positioned(
              left: 6,
              top: 6,
              child: _cizim
                  ? FilledButton.icon(
                      onPressed: () {
                        _iptal();
                        setState(() {
                          _cizim = false;
                          _noktalar.clear();
                          _duzenBirak();
                        });
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Çizimi bitir'))
                  : IconButton.filledTonal(
                      tooltip: 'Çizim: ayırma çizgisi, bölge, parsel sınırı',
                      icon: const Icon(Icons.draw_outlined),
                      onPressed: () => setState(() => _cizim = true)),
            ),
          if (_cizim)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: _bekleyen == null
                      ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Wrap(spacing: 6, runSpacing: 0, children: [
                            for (final (d, ad, ik) in [
                              ('cizgi', 'Çizgi', Icons.horizontal_rule),
                              ('kare', 'Kare', Icons.crop_square),
                              ('daire', 'Daire', Icons.circle_outlined),
                              ('nokta', 'Nokta', Icons.polyline_outlined),
                              if (widget.sinirKaydet != null) ('doldur', 'Boşluğu doldur', Icons.format_color_fill),
                              if (widget.sinirKaydet != null) ('sinir', 'Sınır düzenle', Icons.edit_location_alt_outlined),
                              if (widget.sinirKaydet != null) ('yeni', 'Yeni parsel', Icons.add_location_alt_outlined),
                            ])
                              ChoiceChip(
                                visualDensity: VisualDensity.compact,
                                avatar: Icon(ik, size: 16),
                                label: Text(ad),
                                selected: _sekil == d,
                                onSelected: (_) => setState(() {
                                  _sekil = d;
                                  _noktalar.clear();
                                  _duzenBirak();
                                }),
                              ),
                          ]),
                          const SizedBox(height: 6),
                          Text(
                              switch (_sekil) {
                                'kare' => 'Parselin içinde bir köşeden karşı köşeye parmağınızı sürükleyin; dikdörtgen bölge olur.',
                                'daire' => 'Bölgenin ortasına basıp dışa doğru sürükleyin; daire bölge olur.',
                                'nokta' => 'Bölgenin köşelerine sırayla dokunun (en az 3 nokta), sonra "Bölgeyi kapat".',
                                'doldur' => 'Parsellerin arasındaki boşluğun (ör. pivot yeri) ortasına dokunun: komşu parsellerin '
                                    'kenarlarına göre daire bulunur ve boşluk doldurulur; sonra düzeltip kaydedersiniz.',
                                'sinir' when _duzenParsel == null =>
                                  'Sınırını değiştirmek istediğiniz parsele dokunun. Haritayı iki parmakla yakınlaştırıp kaydırabilirsiniz.',
                                'sinir' when _yenidenCiz =>
                                  '${_duzenParsel!.ad}: yeni sınırın köşelerine sırayla dokunun (en az 3 nokta). '
                                      'Çizilen alan ≈ ${sayi(_dekarAlan(_duzen))} da',
                                'sinir' => '${_duzenParsel!.ad}: köşeleri sürükleyin; kenar ortasındaki küçük noktayı sürükleyerek '
                                    'köşe ekleyin; köşeye dokunup seçerek silin. Çizilen alan ≈ ${sayi(_dekarAlan(_duzen))} da',
                                'yeni' when _yeniDuzen => 'Yeni parsel: köşeleri sürükleyin, kenar ortasındaki küçük noktadan '
                                    'köşe ekleyin, şeklin içinden tutup taşıyın. Çizilen alan ≈ ${sayi(_dekarAlan(_duzen))} da',
                                'yeni' => 'Yeni parselin köşelerine sırayla dokunun (en az 3 nokta) ya da Kare / Daire / Nokta ile '
                                    'parsel dışına şekil çizin. '
                                    'Çizilen alan ≈ ${sayi(_dekarAlan(_duzen))} da',
                                _ => 'Ayırmak istediğiniz parselin üzerinden bir çizgi çekin. İki renkli parselde çizgi yer '
                                    'değiştirir; tek ürünlü parselde parsel iki parçaya bölünür.',
                              },
                              style: const TextStyle(fontSize: 12.5)),
                          if (kopyaSekil != null && (_sekil == 'yeni' || (_sekil == 'sinir' && _duzenParsel != null)))
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                  onPressed: () => setState(() {
                                        _duzen = [for (final c in kopyaSekil!.$2) (c.$1 * _g.kx, c.$2)];
                                        _secKose = null;
                                        _yenidenCiz = false;
                                        if (_sekil == 'yeni') _yeniDuzen = true;
                                      }),
                                  icon: const Icon(Icons.content_paste),
                                  label: Text('Yapıştır: ${kopyaSekil!.$1} şekli')),
                            ),
                          if (_sekil == 'sinir' && _duzenParsel != null && _duzen.length > 2)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                  onPressed: () {
                                    sekilKopyala(_duzenParsel!.ad, [for (final c in _duzen) (c.$1 / _g.kx, c.$2)]);
                                    setState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('${_duzenParsel!.ad} şekli kopyalandı.')));
                                  },
                                  icon: const Icon(Icons.copy_all_outlined),
                                  label: const Text('Bu şekli kopyala')),
                            ),
                          if ((_sekil == 'sinir' && _duzenParsel != null) || _sekil == 'yeni')
                            Wrap(spacing: 6, runSpacing: 0, children: [
                              if ((_sekil == 'yeni' && !_yeniDuzen) || _yenidenCiz)
                                TextButton.icon(
                                    onPressed: _duzen.isEmpty ? null : () => setState(_duzen.removeLast),
                                    icon: const Icon(Icons.undo),
                                    label: const Text('Son noktayı sil'))
                              else ...[
                                TextButton.icon(
                                    onPressed: _secKose == null || _duzen.length <= 3
                                        ? null
                                        : () => setState(() {
                                              _duzen.removeAt(_secKose!);
                                              _secKose = null;
                                            }),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Seçili köşeyi sil')),
                                TextButton.icon(
                                    onPressed: () => setState(() {
                                          _duzen = [];
                                          if (_sekil == 'yeni') {
                                            _yeniDuzen = false;
                                          } else {
                                            _yenidenCiz = true;
                                          }
                                          _secKose = null;
                                        }),
                                    icon: const Icon(Icons.gesture),
                                    label: const Text('Baştan çiz')),
                              ],
                              if (_sekil == 'sinir' && widget.degisenSinir.contains(_duzenParsel!.ad))
                                TextButton.icon(
                                    onPressed: _kaydediliyor ? null : _sinirGeriAlBas,
                                    icon: const Icon(Icons.restore),
                                    label: const Text('Değişikliği geri al')),
                              if (_sekil == 'sinir' || _yeniDuzen)
                                TextButton(onPressed: () => setState(_duzenBirak), child: const Text('Vazgeç')),
                              FilledButton.icon(
                                  onPressed: _kaydediliyor || _duzen.length < 3 ? null : _sinirKaydetBas,
                                  icon: _kaydediliyor
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.check),
                                  label: Text(_sekil == 'yeni' ? 'Parseli kaydet' : 'Sınırı kaydet')),
                            ]),
                          if (_sekil == 'nokta')
                            Wrap(spacing: 8, children: [
                              TextButton.icon(
                                  onPressed: _noktalar.isEmpty ? null : () => setState(_noktalar.removeLast),
                                  icon: const Icon(Icons.undo),
                                  label: const Text('Son noktayı sil')),
                              FilledButton.icon(
                                  onPressed: _noktalar.length < 3
                                      ? null
                                      : () => _sekilBitir(_sonBoyut, noktalar: [..._noktalar]),
                                  icon: const Icon(Icons.check),
                                  label: Text('Bölgeyi kapat (${_noktalar.length})')),
                            ]),
                        ])
                      : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Text('${_bekleyen!.$1.ad}: ${_bekleyen!.$1.urunler.map((u) => u.$1).join(' / ')}',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Wrap(spacing: 8, runSpacing: 4, children: [
                            OutlinedButton.icon(
                                onPressed: _kaydediliyor ? null : _cevir,
                                icon: const Icon(Icons.swap_horiz),
                                label: const Text('Renkleri çevir')),
                            TextButton(onPressed: _kaydediliyor ? null : _iptal, child: const Text('Vazgeç')),
                            FilledButton.icon(
                                onPressed: _kaydediliyor ? null : _kaydet,
                                icon: _kaydediliyor
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.check),
                                label: const Text('Kaydet')),
                          ]),
                        ]),
                ),
              ),
            ),
        ]),
      );
  }
}

/// Yalnızca köşe / kenar ortası üzerinde başlayan sürükleme (başka yerde harita kayar).
class _KoseSurukle extends PanGestureRecognizer {
  bool Function(Offset local) kabul = (_) => false;
  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (!kabul(event.localPosition)) return;
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

/// Parmak değer değmez kabul edilen sürükleme (üst kaydırma ile yarışmaz).
class _HemenPan extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _PoligonCizer extends CustomPainter {
  _PoligonCizer(this.g, this.cks,
      {this.cizim, this.sekil = 'cizgi', this.noktalar = const [], this.duzen, this.duzenKapali = true, this.secKose, this.olcek = 1});

  /// Düzenlenen sınırın köşeleri (ekran, yakınlaştırma öncesi); kapalı ise kenar ortaları da çizilir.
  final List<Offset>? duzen;
  final bool duzenKapali;
  final int? secKose;
  final double olcek;
  final _Geometri g;
  final Set<String> cks;
  final (Offset, Offset)? cizim;

  /// Çizim önizlemesi: 'cizgi', 'kare', 'daire', 'nokta'.
  final String sekil;
  final List<Offset> noktalar;
  @override
  void paint(Canvas canvas, Size size) {
    final d = g.donusum(size);
    for (final x in g.sirali) {
      final yol = Path()..addPolygon([for (final c in g.poligon[x]!) d(c)], true);
      final parcalar = g.parca[x];
      final bolgeler = g.bolge[x];
      if (bolgeler != null) {
        // Bölgeler parselle kesişimi kadar, kalan parselin geri kalanı kadar boyanır.
        var kalan = yol;
        for (var i = 0; i < bolgeler.length; i++) {
          if (bolgeler[i].length < 3) continue;
          final by = Path()..addPolygon([for (final c in bolgeler[i]) d(c)], true);
          final kesisim = Path.combine(PathOperation.intersect, yol, by);
          canvas.drawPath(kesisim, Paint()..color = urunAdRengi(x.urunler[i].$1).withValues(alpha: 0.75));
          canvas.drawPath(
              kesisim,
              Paint()
                ..color = Colors.white
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5);
          kalan = Path.combine(PathOperation.difference, kalan, by);
        }
        canvas.drawPath(kalan, Paint()..color = urunAdRengi(x.urunler.last.$1).withValues(alpha: 0.6));
      } else if (parcalar != null) {
        for (var i = 0; i < parcalar.length && i < x.urunler.length; i++) {
          if (parcalar[i].length < 3) continue;
          final py = Path()..addPolygon([for (final c in parcalar[i]) d(c)], true);
          canvas.drawPath(py, Paint()..color = urunAdRengi(x.urunler[i].$1).withValues(alpha: 0.6));
          canvas.drawPath(
              py,
              Paint()
                ..color = Colors.white70
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.2);
        }
      } else {
        canvas.drawPath(yol, Paint()..color = urunRengi(x).withValues(alpha: 0.6));
      }
      canvas.drawPath(
          yol,
          Paint()
            ..color = cks.contains(x.ad) ? Renk.mavi : Colors.black54
            ..style = PaintingStyle.stroke
            ..strokeWidth = cks.contains(x.ad) ? 3 : 1);
    }
    // KMZ görselleri: hatlar, pivot merkez çizgileri, kuyu ve direkler.
    for (final (x, k) in g.gorsel) {
      final n = [for (final c in k) d(c)];
      if (x.cizgi && n.length > 1) {
        canvas.drawPath(
            Path()..addPolygon(n, false),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = x.tur == 'og' ? 2.2 : 1.4
              ..color = gorselRengi(x.tur));
      } else if (n.isNotEmpty) {
        final m = n.first;
        if (x.tur == 'direk') {
          canvas.drawRect(Rect.fromCenter(center: m, width: 6, height: 6), Paint()..color = gorselRengi(x.tur));
        } else {
          canvas.drawCircle(m, 4.5, Paint()..color = Colors.white);
          canvas.drawCircle(m, 3.5, Paint()..color = gorselRengi(x.tur));
        }
      }
    }
    final kalem = Paint()
      ..color = Colors.red
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (cizim case (final a, final b)) {
      switch (sekil) {
        case 'kare':
          canvas.drawRect(Rect.fromPoints(a, b), kalem);
        case 'daire':
          canvas.drawCircle(a, (b - a).distance, kalem);
        default:
          canvas.drawLine(a, b, kalem);
      }
    }
    if (duzen case final e? when e.isNotEmpty) {
      final u = 1 / olcek;
      final yol = Path()..addPolygon(e, e.length > 2);
      if (e.length > 2) canvas.drawPath(yol, Paint()..color = Colors.orange.withValues(alpha: 0.25));
      canvas.drawPath(
          yol,
          Paint()
            ..color = Colors.deepOrange
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 * u);
      if (duzenKapali && e.length > 2) {
        for (final (_, o) in _ortaNoktalar(e, olcek)) {
          canvas.drawCircle(o, 4 * u, Paint()..color = Colors.white.withValues(alpha: 0.9));
          canvas.drawCircle(
              o,
              4 * u,
              Paint()
                ..color = Colors.deepOrange
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.2 * u);
        }
      }
      for (final (i, n) in e.indexed) {
        canvas.drawCircle(n, (i == secKose ? 8 : 6) * u, Paint()..color = i == secKose ? Colors.red : Colors.white);
        canvas.drawCircle(
            n,
            (i == secKose ? 8 : 6) * u,
            Paint()
              ..color = Colors.deepOrange
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2 * u);
      }
    }
    if (sekil == 'nokta' && noktalar.isNotEmpty) {
      canvas.drawPath(Path()..addPolygon(noktalar, noktalar.length > 2), kalem);
      for (final n in noktalar) {
        canvas.drawCircle(n, 5, Paint()..color = Colors.red);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PoligonCizer old) => true;
}

class _YaziCizer extends CustomPainter {
  _YaziCizer(this.g, this.m, this.yazi, this.dekar);
  final _Geometri g;
  final Matrix4 m;
  final double yazi;
  final bool dekar;

  @override
  void paint(Canvas canvas, Size size) {
    final d = g.donusum(size);
    final dolu = <Rect>[];
    for (final x in g.sirali) {
      final n = MatrixUtils.transformPoint(m, d(g.yaziNoktasi[x]!));
      final bolgeler = g.bolge[x];
      if (bolgeler != null) {
        String alt(int i) => [
              if (dekar && _dekarGoster(x, i) != null) '${sayi(_dekarGoster(x, i))} da',
              if (x.cesit(i) != null) x.cesit(i)!,
            ].join(' · ');
        final son = x.urunler.length - 1;
        _etiket(canvas, size, dolu, n, [
          TextSpan(text: x.ad, style: TextStyle(fontSize: yazi, color: Colors.black, fontWeight: FontWeight.w800)),
          TextSpan(
              text: '\n${_kisaUrun(x.urunler[son].$1)}',
              style: TextStyle(fontSize: yazi * 0.92, color: Colors.black87, fontWeight: FontWeight.w600)),
          if (alt(son).isNotEmpty) TextSpan(text: '\n${alt(son)}', style: TextStyle(fontSize: yazi * 0.8, color: Colors.black54)),
        ]);
        for (var i = 0; i < bolgeler.length; i++) {
          final k = bolgeler[i];
          if (k.length < 3) continue;
          final o = (k.map((e) => e.$1).reduce((a, b) => a + b) / k.length, k.map((e) => e.$2).reduce((a, b) => a + b) / k.length);
          _etiket(canvas, size, dolu, MatrixUtils.transformPoint(m, d(o)), [
            TextSpan(
                text: _kisaUrun(x.urunler[i].$1),
                style: TextStyle(fontSize: yazi * 0.85, color: Colors.black87, fontWeight: FontWeight.w600)),
            if (alt(i).isNotEmpty) TextSpan(text: '\n${alt(i)}', style: TextStyle(fontSize: yazi * 0.75, color: Colors.black54)),
          ]);
        }
        continue;
      }
      final parcalar = g.parca[x];
      if (parcalar != null && parcalar.length == x.urunler.length) {
        // Bölünmüş parsel: ad kendi noktasında, her parçanın ürünü/dekarı kendi parçasının ortasında.
        _etiket(canvas, size, dolu, n, [TextSpan(text: x.ad, style: TextStyle(fontSize: yazi, color: Colors.black, fontWeight: FontWeight.w800))]);
        for (var i = 0; i < parcalar.length; i++) {
          final k = parcalar[i];
          if (k.length < 3) continue;
          final o = (k.map((e) => e.$1).reduce((a, b) => a + b) / k.length, k.map((e) => e.$2).reduce((a, b) => a + b) / k.length);
          final alt = [
            if (dekar && _dekarGoster(x, i) != null) '${sayi(_dekarGoster(x, i))} da',
            if (x.cesit(i) != null) x.cesit(i)!,
            if (x.bag(i) != null) '→ ${x.bag(i)}',
          ].join(' · ');
          _etiket(canvas, size, dolu, MatrixUtils.transformPoint(m, d(o)), [
            TextSpan(
                text: _kisaUrun(x.urunler[i].$1),
                style: TextStyle(fontSize: yazi * 0.92, color: Colors.black87, fontWeight: FontWeight.w600)),
            if (alt.isNotEmpty) TextSpan(text: '\n$alt', style: TextStyle(fontSize: yazi * 0.8, color: Colors.black54)),
          ]);
        }
        continue;
      }
      final tp = TextPainter(
        text: TextSpan(children: [
          TextSpan(text: x.ad, style: TextStyle(fontSize: yazi, color: Colors.black, fontWeight: FontWeight.w800)),
          if (x.girilmedi)
            TextSpan(text: '\nGirilmedi', style: TextStyle(fontSize: yazi * 0.85, color: Colors.black54)),
          for (final (kisa, alt) in {
            for (final (i, u) in x.urunler.indexed)
              (
                _kisaUrun(u.$1),
                [
                  if (dekar && _dekarGoster(x, i) != null) '${sayi(_dekarGoster(x, i))} da',
                  if (x.cesit(i) != null) x.cesit(i)!,
                ].join(' · '),
              )
          }) ...[
            TextSpan(
                text: '\n$kisa',
                style: TextStyle(fontSize: yazi * 0.92, color: Colors.black87, fontWeight: FontWeight.w600)),
            if (alt.isNotEmpty)
              TextSpan(text: '\n$alt', style: TextStyle(fontSize: yazi * 0.8, color: Colors.black54)),
          ],
        ]),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: yazi * 11);
      final r = Rect.fromCenter(center: n, width: tp.width + 8, height: tp.height + 4);
      if (!(Offset.zero & size).contains(n)) continue;
      if (dolu.any((o) => o.overlaps(r))) continue;
      dolu.add(r);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), Paint()..color = Colors.white.withValues(alpha: 0.8));
      tp.paint(canvas, n - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _etiket(Canvas canvas, Size size, List<Rect> dolu, Offset n, List<TextSpan> metin) {
    if (!(Offset.zero & size).contains(n)) return;
    final tp = TextPainter(
        text: TextSpan(children: metin), textAlign: TextAlign.center, textDirection: TextDirection.ltr)
      ..layout(maxWidth: yazi * 11);
    final r = Rect.fromCenter(center: n, width: tp.width + 8, height: tp.height + 4);
    if (dolu.any((o) => o.overlaps(r))) return;
    dolu.add(r);
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), Paint()..color = Colors.white.withValues(alpha: 0.8));
    tp.paint(canvas, n - Offset(tp.width / 2, tp.height / 2));
  }

  /// Haritada gösterilen dekar: girilen değer; yoksa parselin beyan/ölçülen alanı, o da yoksa çizimden
  /// hesaplanan alan. Çok ürünlü parselde parçaların çizimdeki alan payıyla bölüştürülür.
  double? _dekarGoster(TarlaParsel x, int i) {
    final d = x.urunler[i].$2;
    if (d > 0) return d;
    if (x.urunler.length == 1 && x.not.endsWith('ile birleştirildi')) return null;
    final cizim = (g.alan[x] ?? 0).abs();
    final toplam = x.beyan ?? x.olculen ?? (cizim > 0 ? cizim * 111320 * 111320 / 1000 : null);
    if (toplam == null || toplam <= 0) return null;
    if (x.urunler.length == 1) return toplam.roundToDouble();
    final pay = g.bolgePay[x];
    if (pay != null) return i < pay.length ? (toplam * pay[i]).roundToDouble() : null;
    final parcalar = g.parca[x];
    if (parcalar == null || i >= parcalar.length || parcalar[i].length < 3 || cizim <= 0) return null;
    return (toplam * _alan(parcalar[i]).abs() / cizim).roundToDouble();
  }

  /// Ürünün dekarı: girilen değer; tek ürünlü KMZ parselinde parselin beyan/ölçülen alanı.
  static double? _urunDekari(TarlaParsel x, int i) {
    final d = x.urunler[i].$2;
    if (d > 0) return d;
    if (x.urunler.length == 1) return x.beyan ?? x.olculen;
    return null;
  }

  static String _kisaUrun(String u) {
    final k = urunAnahtari(u);
    if (k.startsWith('Silajlık mısır')) return k.contains('2.') ? 'Mısır (2. ürün)' : 'Mısır';
    if (k == 'Şeker pancarı') return 'Pancar';
    return u;
  }

  @override
  bool shouldRepaint(covariant _YaziCizer old) => old.m != m || old.g != g || old.dekar != dekar;
}

class _Parseller extends StatelessWidget {
  const _Parseller({required this.s, required this.v, required this.ilk});
  final TarlaSezonu s;
  final RaporVerisi v, ilk;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 24), children: [
        const BolumBasligi('Çiftlikler'),
        for (final c in s.ciftlikler)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Renk.anaAcik, child: Icon(Icons.grid_view, color: Renk.ana)),
              title: Text(c.ad, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${c.parseller.length} parsel · ${s.giris ? 'Girilen' : 'Excel'}: ${sayi((s.giris ? c.urunToplami : excelAlanlari(v.ekim, c.ad)).values.fold<double>(0, (a, b) => a + b))} da ekili'
                  '${_cksSay(c) > 0 ? ' · ${_cksSay(c)} parsel ÇKS\'de bildirildi' : ''}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _ac(context, '${c.ad} parselleri', 'Tarla Haritası ${s.sezon} – ${c.ad} parselleri',
                  (v) => ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 24), children: [
                        _ResmiParselKarti(c: c, v: v),
                        for (final p in c.parseller) _ParselKarti(c: c, p: p, s: s, v: v, ilk: ilk),
                      ])),
            ),
          ),
      ]);

  int _cksSay(TarlaCiftlik c) => c.parseller.where((p) => parselCks(c, p, v.cks, s.sezon).isNotEmpty).length;

  void _ac(BuildContext context, String baslik, String konu, Widget Function(RaporVerisi) govde) =>
      tarlaSayfaAc(context, ilk, baslik, konu, govde);
}

/// Tarımsal Faaliyet › PARSEL sekmesindeki resmî parseller.
class _ResmiParselKarti extends StatelessWidget {
  const _ResmiParselKarti({required this.c, required this.v});
  final TarlaCiftlik c;
  final RaporVerisi v;
  @override
  Widget build(BuildContext context) {
    final l = [for (final x in v.resmiParsel) if (ciftlikAnahtari(x.ciftlik) == ciftlikAnahtari(c.ad)) x];
    if (l.isEmpty) return const SizedBox.shrink();
    final toplam = l.fold<double>(0, (a, x) => a + (x.alan ?? 0));
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Resmî parsel kayıtları (${l.length} satır · ${sayi(toplam)} da)',
              style: const TextStyle(fontWeight: FontWeight.w800, color: Renk.ana)),
          const Text('Kaynak: 2026-2027 Tarımsal Faaliyet › PARSEL', style: TextStyle(fontSize: 11.5, color: Renk.soluk)),
          const SizedBox(height: 6),
          for (final x in l)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('${x.koy} · ${x.adaParsel} · ${_da(x.alan)} · ${urunAnahtari(x.urun)}', style: const TextStyle(fontSize: 12.5)),
            ),
        ]),
      ),
    );
  }
}

/// Alt sayfa: başlık, "Bu bulguyu gönder" ve veri yenilenince güncellenen gövde.
void tarlaSayfaAc(BuildContext context, RaporVerisi ilk, String baslik, String konu, Widget Function(RaporVerisi) govde) =>
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ListenableBuilder(
        listenable: VeriDeposu.ben,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: Text(baslik)),
          body: GonderAlani(konu: konu, child: govde(VeriDeposu.ben.veri ?? ilk)),
        ),
      ),
    ));

Map<String, (double, int)> _cksOzet(List<CksParsel> l) {
  final m = <String, (double, int)>{};
  for (final x in l) {
    final o = m[x.urun] ?? (0.0, 0);
    m[x.urun] = (o.$1 + (x.alan ?? 0), o.$2 + 1);
  }
  return m;
}

class _ParselKarti extends StatelessWidget {
  const _ParselKarti({required this.c, required this.p, required this.s, required this.v, required this.ilk, this.ayrinti = false});
  final TarlaCiftlik c;
  final TarlaParsel p;
  final TarlaSezonu s;
  final RaporVerisi v, ilk;
  final bool ayrinti;

  @override
  Widget build(BuildContext context) {
    final kayitlar = parselKayitlari(c, p, v.tarim);
    final cks = parselCks(c, p, v.cks, s.sezon);
    final icerik = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 12, height: 12, color: urunRengi(p)),
        const SizedBox(width: 8),
        Expanded(child: Text(p.ad, style: const TextStyle(fontWeight: FontWeight.w800))),
      ]),
      const SizedBox(height: 2),
      Text(s.giris && (p.beyan ?? 0) > 0 ? p.urunYazi : p.urunCinsi),
      if (ayrinti && p.tip != 'diger')
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: OutlinedButton.icon(
            onPressed: () => _parselIslem(context, s, c, p),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text('${s.giris ? s.sezon : sonrakiSezon(s.sezon)}: ürün / dekar değiştir'),
          ),
        ),
      if (cks.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(spacing: 6, runSpacing: 4, children: [
            for (final e in _cksOzet(cks).entries)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Renk.maviAcik, borderRadius: BorderRadius.circular(6)),
                child: Text("ÇKS'de bildirildi: ${e.key} · çiftlikte ÇKS toplamı ${_da(e.value.$1)} (${e.value.$2} kayıt)",
                    style: const TextStyle(fontSize: 12, color: Renk.mavi, fontWeight: FontWeight.w700)),
              ),
            if (ayrinti)
              for (final x in cks)
                Text('${x.adaParsel} · ${x.urun} ${_da(x.alan)} · ${x.mevki}', style: const TextStyle(fontSize: 12)),
          ]),
        ),
      if (p.not.isNotEmpty) Text(p.not, style: const TextStyle(fontSize: 12.5, color: Renk.amber)),
      if (kayitlar.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(ayrinti ? 'Tarım icmali kayıtları (${kayitlar.length}):' : 'Tarım icmali (son kayıtlar):',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Renk.ana)),
        for (final k in (ayrinti ? kayitlar : kayitlar.take(2))) Text('${tarihKisa(k.tarih)}: ${k.faaliyet}', style: const TextStyle(fontSize: 12)),
      ],
    ]);
    if (ayrinti) return Padding(padding: const EdgeInsets.all(14), child: icerik);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => tarlaSayfaAc(context, ilk, '${c.ad} · ${p.ad}', 'Tarla Haritası ${s.sezon} – ${c.ad} ${p.ad}',
            (v) => ListView(children: [_ParselKarti(c: c, p: p, s: s, v: v, ilk: ilk, ayrinti: true)])),
        child: Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 10), child: icerik),
      ),
    );
  }
}

class _Karsilastirma extends StatefulWidget {
  const _Karsilastirma({required this.s, required this.v});
  final TarlaSezonu s;
  final RaporVerisi v;
  @override
  State<_Karsilastirma> createState() => _KarsilastirmaState();
}

class _KarsilastirmaState extends State<_Karsilastirma> {
  final _kFark = GlobalKey(), _kOlcum = GlobalKey(), _kUyumlu = GlobalKey(), _kCks = GlobalKey();

  Future<void> _geriAl(BuildContext context, String ciftlik, String konu) async {
    try {
      final m = await VeriDeposu.ben.ekimDuzelt(sezon: widget.s.sezon, ciftlik: ciftlik, urun: konu, geriAl: true);
      if (context.mounted) bildir(context, m);
    } catch (e) {
      if (context.mounted) bildir(context, '$e');
    }
  }

  Future<void> _duzelt(BuildContext context,
      {required String ciftlik,
      required String konu,
      required String baslik,
      required List<(String, double?)> secenekler,
      bool ozelDeger = false}) async {
    final sonuc = await showDialog<(String, double?, String)>(
        context: context, builder: (_) => _DuzeltDiyalog(baslik: baslik, secenekler: secenekler, ozelDeger: ozelDeger));
    if (sonuc == null || !context.mounted) return;
    try {
      final m = await VeriDeposu.ben.ekimDuzelt(
          sezon: widget.s.sezon, ciftlik: ciftlik, urun: konu, secim: sonuc.$1, deger: sonuc.$2, aciklama: sonuc.$3);
      if (context.mounted) bildir(context, m);
    } catch (e) {
      if (context.mounted) bildir(context, '$e');
    }
  }

  Widget _uyumluKart(String baslik, String alt) => Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.check_circle_outline, color: Renk.yesil),
          title: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(alt),
        ),
      );

  /// Farklılık kartı: "Düzelt" ya da (düzeltildiyse) "Düzeltildi · Geri al".
  Widget _kart(BuildContext context,
      {required String ciftlik,
      required String konu,
      required String baslik,
      required String alt,
      required IconData ikon,
      required List<(String, double?)> secenekler,
      bool ozelDeger = false}) {
    final d = aktifDuzeltme(widget.v.ekimDuzeltme, widget.s.sezon, ciftlik, konu);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ListTile(
            dense: true,
            leading: Icon(d == null ? ikon : Icons.task_alt, color: d == null ? Renk.amber : Renk.yesil),
            title: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(d == null
                ? alt
                : '$alt\nDüzeltildi: ${d.secim}${d.deger == null || d.deger == 0 ? '' : ' · ${_da(d.deger)}'}'
                    '${d.aciklama.isEmpty ? '' : ' · ${d.aciklama}'}'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: d == null
                ? TextButton.icon(
                    onPressed: () => _duzelt(context,
                        ciftlik: ciftlik, konu: konu, baslik: baslik, secenekler: secenekler, ozelDeger: ozelDeger),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Düzelt'),
                  )
                : TextButton(onPressed: () => _geriAl(context, ciftlik, konu), child: const Text('Geri al')),
          ),
        ]),
      ),
    );
  }

  void _git(GlobalKey k) {
    final c = k.currentContext;
    if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 350), alignment: 0.02);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s, v = widget.v;
    final tablo = excelKarsilastir(s, v.ekim, v.resmiParsel, v.cks);
    final uyumlu = tablo.where((x) => x.uyumlu).toList();
    final farkTum = tablo.where((x) => !x.uyumlu).toList();
    final duzeltilen = [for (final x in farkTum) if (aktifDuzeltme(v.ekimDuzeltme, s.sezon, x.ciftlik, x.urun) != null) x];
    final fark = [for (final x in farkTum) if (aktifDuzeltme(v.ekimDuzeltme, s.sezon, x.ciftlik, x.urun) == null) x];
    // Yalnızca ürün cinsi çelişkileri; haritadaki dekar çelişkileri dikkate alınmaz.
    final dekarCeliskisi = RegExp(r'"\d+ da", alan çizimi "\d+ da"');
    final etiket = [
      for (final c in s.ciftlikler)
        for (final p in c.parseller)
          if (p.not.contains('yazıyor') && !dekarCeliskisi.hasMatch(p.not)) (c, p)
    ];
    final hasat = <(HasatSatir, double)>[];
    for (final h in v.hasat) {
      if ((h.alan ?? 0) <= 0 || h.toplam == null) continue;
      for (final c in s.ciftlikler) {
        if (ciftlikAnahtari(c.ad) != ciftlikAnahtari(h.ciftlik)) continue;
        final a = excelAlanlari(v.ekim, c.ad)[urunAnahtari(h.urun)];
        if (a != null && !alanYakin(a, h.alan!)) hasat.add((h, a));
      }
    }
    final cksEslesmeyen = [
      for (final x in v.cks)
        if ((x.sezon.isEmpty || x.sezon == s.sezon) &&
            !s.ciftlikler.any((c) => c.parseller.any((p) => parselCks(c, p, [x], s.sezon).isNotEmpty)))
          x
    ];
    final yillar = planYillari(v.ekimPlani);
    final cksYok = [
      for (final c in s.ciftlikler)
        for (final p in c.parseller)
          if (p.urunler.isNotEmpty && p.tip != 'diger' && parselCks(c, p, v.cks, s.sezon).isEmpty) (c, p)
    ];
    String kaynaklar(UrunSatiri x) => [
          'Excel planı ${_da(x.excel)}',
          if (x.resmi != null) 'Excel PARSEL ${_da(x.resmi)}',
          'ÇKS ${_da(x.cks)}',
          'Harita: ${x.haritada ? 'ekili' : 'yok'}',
          if (x.ekilen != null) 'ekilen ${_da(x.ekilen)}',
        ].join(' · ');
    Widget farkKarti(UrunSatiri x) => _kart(context,
        ciftlik: x.ciftlik,
        konu: x.urun,
        baslik: '${x.ciftlik} · ${x.urun}',
        alt: '${kaynaklar(x)}\n${x.bulgular.join('; ')}',
        ikon: Icons.warning_amber_rounded,
        secenekler: [
          if ((x.excel ?? 0) > 0) ('Excel ekim planı doğru', x.excel),
          if (x.resmi != null) ('Excel PARSEL kaydı doğru', x.resmi),
          if (x.cks != null) ('ÇKS doğru', x.cks),
          if (x.excelYok) ("Excel'e eklenecek", null),
          if (x.haritadaYok) ('Harita güncellenecek', null),
        ],
        ozelDeger: true);
    return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const BilgiKutusu(
          yazi: 'Esas alınan kaynak Excel dosyalarıdır: ekim planı (2026-2027 Ekim Planı) ve resmî parsel kayıtları '
              '(2026-2027 Tarımsal Faaliyet › PARSEL). ÇKS bu rakamlarla karşılaştırılır. Haritadan yalnızca ekili ürün '
              'cinsi alınır; haritada yazan dekarlar kullanılmaz.'),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: _Sayac('Uyumlu', uyumlu.length, Renk.yesil, () => _git(_kUyumlu))),
        const SizedBox(width: 8),
        Expanded(child: _Sayac('Farklı / eksik', fark.length, Renk.amber, () => _git(_kFark))),
      ]),
      if (duzeltilen.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('${duzeltilen.length} fark uygulamada düzeltildi (Düzeltilenler bölümü).',
              style: const TextStyle(fontSize: 12, color: Renk.yesil)),
        ),
      if (v.cks.isNotEmpty) ...[
        const SizedBox(height: 8),
        _Sayac("ÇKS ile eşleşmeyen parsel", cksEslesmeyen.length + cksYok.length, Renk.mavi, () => _git(_kCks)),
      ],
      const BolumBasligi('Excel esaslı ekim alanları (da)'),
      _KaynakTablosu(satirlar: tablo),
      BolumBasligi('Tutarsızlıklar: Excel esas alınarak', key: _kFark),
      if (fark.isEmpty) const Text('Fark yok.'),
      for (final x in fark) farkKarti(x),
      if (duzeltilen.isNotEmpty) ...[
        const BolumBasligi('Düzeltilenler'),
        for (final x in duzeltilen) farkKarti(x),
      ],
      if (etiket.isNotEmpty) ...[
        BolumBasligi('Haritada ürün cinsi tutarsızlıkları', key: _kOlcum),
        for (final (c, p) in etiket)
          _kart(context,
              ciftlik: c.ad,
              konu: 'Etiket: ${p.ad}',
              baslik: '${c.ad} · ${p.ad}',
              alt: p.not,
              ikon: Icons.label_important_outline,
              secenekler: const [('Haritadaki işaret doğru', null), ('Alan çizimindeki ürün doğru', null), ('İncelendi, sorun yok', null)]),
      ],
      if (hasat.isNotEmpty) ...[
        const BolumBasligi('Hasat ve verim (Excel alanıyla)'),
        for (final (h, a) in hasat)
          _kart(context,
              ciftlik: h.ciftlik,
              konu: 'Hasat: ${h.urun}',
              baslik: '${h.ciftlik} · ${h.urun}',
              alt: 'Hasat kaydında alan ${_da(h.alan)}, verim ${sayi(h.toplam! / h.alan!)} kg/da. '
                  'Excel ekim planındaki alan ${_da(a)} esas alınırsa verim ${sayi(h.toplam! / a)} kg/da.',
              ikon: Icons.agriculture,
              secenekler: [('Hasat kaydındaki alan doğru', h.alan), ('Excel alanı doğru', a)],
              ozelDeger: true),
      ],
      if (v.cks.isNotEmpty) ...[
        BolumBasligi('ÇKS ile haritadaki ekili ürünler', key: _kCks),
        for (final x in cksEslesmeyen)
          _kart(context,
              ciftlik: x.ciftlik,
              konu: 'ÇKS kaydı: ${x.urun} ${x.adaParsel}',
              baslik: "${x.ciftlik} · ÇKS: ${x.urun} ${_da(x.alan)}",
              alt: '${[x.mevki, x.adaParsel].where((e) => e.isNotEmpty).join(' · ')}\nHaritada bu ürün için parsel yok.',
              ikon: Icons.help_outline,
              secenekler: const [('ÇKS kaydı doğru, harita güncellenecek', null), ('İncelendi, sorun yok', null)]),
        for (final (c, p) in cksYok)
          _kart(context,
              ciftlik: c.ad,
              konu: 'ÇKS bildirimi: ${p.ad}',
              baslik: '${c.ad} · ${p.ad}',
              alt: "${p.urunCinsi}: haritada ekili, ÇKS'de bildirimi görünmüyor.",
              ikon: Icons.report_outlined,
              secenekler: const [("ÇKS'de bildirildi (başka parsel altında)", null), ("ÇKS'ye bildirilecek", null), ('İncelendi, sorun yok', null)]),
        if (cksEslesmeyen.isEmpty && cksYok.isEmpty) const Text("Tüm parseller ÇKS'de bildirilmiş."),
      ],
      const BolumBasligi('Ekim planı yıllara göre (münavebe)'),
      if (yillar.length < 2)
        Text(yillar.isEmpty
            ? 'Ekim planı dosyası okunamadı.'
            : '${yillar.first} planı okundu. ${int.parse(yillar.first) + 1} planı dosyaya girildiğinde '
                'çiftlik ve ürün bazında karşılaştırma burada görünecek.')
      else
        for (final c in {for (final x in v.ekimPlani) x.ciftlik})
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c, style: const TextStyle(fontWeight: FontWeight.w800)),
                for (final u in {for (final x in v.ekimPlani) if (x.ciftlik == c) x.urun})
                  Text('$u: ${[
                    for (final y in yillar)
                      '$y ${_da(v.ekimPlani.where((x) => x.ciftlik == c && x.urun == u && x.yil == y).fold<double>(0, (a, x) => a + x.plan))}'
                  ].join(' → ')}', style: const TextStyle(fontSize: 12.5)),
              ]),
            ),
          ),
      BolumBasligi('Olumlu: uyumlu olanlar', key: _kUyumlu),
      if (uyumlu.isEmpty) const Text('Uyumlu satır yok.'),
      for (final x in uyumlu) _uyumluKart('${x.ciftlik} · ${x.urun}', kaynaklar(x)),
    ]));
  }
}

class _DuzeltDiyalog extends StatefulWidget {
  const _DuzeltDiyalog({required this.baslik, required this.secenekler, this.ozelDeger = false});
  final String baslik;
  final List<(String, double?)> secenekler;
  final bool ozelDeger;
  @override
  State<_DuzeltDiyalog> createState() => _DuzeltDiyalogState();
}

class _DuzeltDiyalogState extends State<_DuzeltDiyalog> {
  static const _ozel = 'Doğru değer';
  late String _secim = widget.secenekler.isEmpty ? _ozel : widget.secenekler.first.$1;
  final _deger = TextEditingController(), _aciklama = TextEditingController();

  @override
  void dispose() {
    _deger.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  double? get _girilen => double.tryParse(_deger.text.trim().replaceAll('.', '').replaceAll(',', '.'));

  bool get _gecerli => _secim != _ozel || _girilen != null;

  double? get _sonDeger => _secim == _ozel ? _girilen : widget.secenekler.firstWhere((e) => e.$1 == _secim).$2;

  @override
  Widget build(BuildContext context) {
    Widget secenek(String s, String alt) => RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: s,
          groupValue: _secim,
          onChanged: (v) => setState(() => _secim = v!),
          title: Text(s),
          subtitle: alt.isEmpty ? null : Text(alt),
        );
    return AlertDialog(
      title: Text(widget.baslik),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Kaynak dosyalar değişmez; düzeltme rapor tablosuna kaydedilir ve istediğiniz zaman geri alınabilir.',
              style: TextStyle(fontSize: 12.5, color: Renk.soluk)),
          for (final (e, d) in widget.secenekler) secenek(e, d == null ? '' : _da(d)),
          if (widget.ozelDeger) secenek(_ozel, ''),
          if (_secim == _ozel)
            TextField(
              controller: _deger,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Doğru alan (da)'),
              onChanged: (_) => setState(() {}),
            ),
          TextField(
            controller: _aciklama,
            maxLength: 300,
            decoration: const InputDecoration(labelText: 'Açıklama (isteğe bağlı)'),
          ),
          const Text('KVKK: açıklamaya kişi adı yazmayın.', style: TextStyle(fontSize: 11.5, color: Renk.soluk)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: _gecerli ? () => Navigator.pop(context, (_secim, _sonDeger, _aciklama.text.trim())) : null,
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

/// Excel planı (esas) / Excel PARSEL / ÇKS / harita tablosu; Excel'den sapan değer turuncu.
class _KaynakTablosu extends StatelessWidget {
  const _KaynakTablosu({required this.satirlar});
  final List<UrunSatiri> satirlar;

  @override
  Widget build(BuildContext context) {
    Widget h(String t, {TextAlign a = TextAlign.right}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(t, textAlign: a, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)));
    Widget d(String t, bool sapan, {bool kalin = false}) => Container(
          color: sapan ? Renk.amber.withValues(alpha: 0.18) : null,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(t,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: sapan || kalin ? FontWeight.w800 : null, color: sapan ? Renk.amber : null)),
        );
    String n(double? x) => x == null ? '—' : sayi(x);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.3), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1), 4: FlexColumnWidth(0.8)
            },
            border: TableBorder(horizontalInside: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
            children: [
              TableRow(children: [h('Çiftlik · Ürün', a: TextAlign.left), h('Excel plan'), h('PARSEL'), h('ÇKS'), h('Harita')]),
              for (final r in satirlar)
                TableRow(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: '${r.ciftlik} · ', style: const TextStyle(color: Renk.soluk)),
                      TextSpan(text: r.urun, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (r.uyumlu) const TextSpan(text: '  ✓', style: TextStyle(color: Renk.yesil, fontWeight: FontWeight.w800)),
                    ]), style: const TextStyle(fontSize: 12.5)),
                  ),
                  d(n(r.excel), r.excelYok, kalin: true),
                  d(n(r.resmi), r.resmiFarkli),
                  d(n(r.cks), r.cksFarkli),
                  d(r.haritada ? 'ekili' : '—', r.haritadaYok || (r.excelYok && r.haritada)),
                ]),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
              "Esas: Excel ekim planı (yoksa Excel PARSEL). Turuncu: Excel'den sapan ya da Excel'de karşılığı olmayan kayıt. "
              'Harita sütunu yalnızca ürünün haritada ekili olup olmadığını gösterir. ✓: uyumlu. —: kayıt yok.',
              style: TextStyle(fontSize: 11.5, color: Renk.soluk)),
        ]),
      ),
    );
  }
}


class _Sayac extends StatelessWidget {
  const _Sayac(this.etiket, this.n, this.renk, this.dokun);
  final String etiket;
  final int n;
  final Color renk;
  final VoidCallback dokun;
  @override
  Widget build(BuildContext context) => Material(
        color: renk.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: dokun,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              Text('$n', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: renk)),
              Text(etiket, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
              Icon(Icons.keyboard_arrow_down, size: 16, color: renk),
            ]),
          ),
        ),
      );
}

double _toplam(List<CksParsel> l) => l.fold<double>(0, (a, x) => a + (x.alan ?? 0));

String _uretimYili(String sezon) {
  final m = RegExp(r'^\d{4}-(\d{4})$').firstMatch(sezon);
  return m == null ? '' : '${m.group(1)} üretim yılı · ';
}

class _MenuKarti extends StatelessWidget {
  const _MenuKarti({required this.baslik, required this.alt, required this.ikon, required this.dokun});
  final String baslik, alt;
  final IconData ikon;
  final VoidCallback dokun;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(backgroundColor: Renk.anaAcik, child: Icon(ikon, color: Renk.ana)),
          title: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(alt),
          trailing: const Icon(Icons.chevron_right),
          onTap: dokun,
        ),
      );
}

/// ÇKS › sezon › çiftlikler.
class _CksCiftlikler extends StatelessWidget {
  const _CksCiftlikler({required this.sezon, required this.l, required this.s, required this.ilk});
  final String sezon;
  final List<CksParsel> l;
  final TarlaSezonu s;
  final RaporVerisi ilk;
  @override
  Widget build(BuildContext context) {
    final g = <String, List<CksParsel>>{};
    for (final x in l) {
      g.putIfAbsent(x.ciftlik.isEmpty ? 'Çiftlik belirtilmemiş' : x.ciftlik, () => []).add(x);
    }
    return ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 24), children: [
      BolumBasligi('$sezon sezonu · ${sayi(_toplam(l))} da'),
      for (final e in g.entries)
        _MenuKarti(
          baslik: e.key,
          alt: '${e.value.length} kayıt · ${sayi(_toplam(e.value))} da',
          ikon: Icons.agriculture,
          dokun: () => tarlaSayfaAc(context, ilk, '${e.key} · ÇKS $sezon', 'Tarla Haritası – ÇKS $sezon ${e.key}',
              (v) => _CksListe(
                  l: [
                    for (final x in v.cks)
                      if ((x.sezon.isEmpty ? 'Sezon belirtilmemiş' : x.sezon) == sezon &&
                          (x.ciftlik.isEmpty ? 'Çiftlik belirtilmemiş' : x.ciftlik) == e.key)
                        x
                  ],
                  haritaSezonu: s.sezon)),
        ),
    ]);
  }
}

/// ÇKS › sezon › çiftlik › kayıtlar (ürüne göre gruplu).
class _CksListe extends StatelessWidget {
  const _CksListe({required this.l, required this.haritaSezonu});
  final List<CksParsel> l;
  final String haritaSezonu;
  @override
  Widget build(BuildContext context) {
    final g = <String, List<CksParsel>>{};
    for (final x in l) {
      g.putIfAbsent(x.urun, () => []).add(x);
    }
    return ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 24), children: [
      for (final e in g.entries) ...[
        BolumBasligi('${e.key} · ${sayi(_toplam(e.value))} da'),
        if (e.value.first.sezon == haritaSezonu)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(e.value.first.eslesen.isEmpty ? 'Haritada bu ürün için parsel yok.' : 'Haritada: ${e.value.first.eslesen}',
                style: TextStyle(fontSize: 12.5, color: e.value.first.eslesen.isEmpty ? Renk.amber : Renk.yesil)),
          ),
        for (final x in e.value)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              title: Text('${x.adaParsel} · ${_da(x.alan)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text([if (x.mevki.isNotEmpty) x.mevki, if (x.belge.isNotEmpty) 'Belge: ${x.belge}'].join('\n')),
            ),
          ),
      ],
    ]);
  }
}

/// ÇKS: belge yükleme (kamera ya da dosya) ve bildirilen parseller.
class _Cks extends StatefulWidget {
  const _Cks({required this.s, required this.v, required this.ilk});
  final TarlaSezonu s;
  final RaporVerisi v, ilk;
  @override
  State<_Cks> createState() => _CksState();
}

class _CksState extends State<_Cks> {
  bool _yukleniyor = false;

  Future<void> _yukle(Future<(List<int>, String)?> Function() sec) async {
    final r = await sec();
    if (r == null || !mounted) return;
    setState(() => _yukleniyor = true);
    try {
      final m = await VeriDeposu.ben.cksYukle(r.$1, r.$2, sezon: widget.s.sezon);
      if (mounted) bildir(context, m);
    } catch (e) {
      if (mounted) bildir(context, '$e');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<(List<int>, String)?> _kamera() async {
    final f = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2400, imageQuality: 85);
    if (f == null) return null;
    return (await f.readAsBytes(), 'image/jpeg');
  }

  Future<(List<int>, String)?> _dosya() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'], withData: true);
    final f = r?.files.single;
    if (f?.bytes == null) return null;
    final e = (f!.extension ?? '').toLowerCase();
    return (f.bytes!.toList(), e == 'pdf' ? 'application/pdf' : e == 'png' ? 'image/png' : 'image/jpeg');
  }

  @override
  Widget build(BuildContext context) {
    // Bölümün sezonuna ait ÇKS kayıtları.
    final l = [for (final x in widget.v.cks) if (x.sezon == widget.s.sezon) x];
    final yillar = <String, List<CksParsel>>{};
    for (final x in l) {
      yillar.putIfAbsent(x.sezon.isEmpty ? 'Sezon belirtilmemiş' : x.sezon, () => []).add(x);
    }
    final sirali = yillar.keys.toList()..sort((a, b) => b.compareTo(a));
    return ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 24), children: [
      const BilgiKutusu(
          yazi: "ÇKS belgesini fotoğrafını çekerek ya da dosya (PDF, görüntü) olarak ekleyin. Belge Drive'daki "
              "'ÇKS Belgeleri' klasörüne kaydedilir; parseller işlendikten sonra haritada ve parsellerde "
              "'ÇKS'de bildirildi' olarak görünür. KVKK: belgedeki kimlik, ad ve iletişim bilgileri uygulamaya alınmaz; "
              "yalnızca mevki, ada/parsel, ürün ve alan işlenir."),
      const SizedBox(height: 10),
      if (!_yalnizGor) Row(children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _yukleniyor ? null : () => _yukle(_kamera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Fotoğraf çek'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _yukleniyor ? null : () => _yukle(_dosya),
            icon: const Icon(Icons.upload_file),
            label: const Text('Dosya seç'),
          ),
        ),
      ]),
      if (_yukleniyor) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
      BolumBasligi("${widget.s.sezon} ÇKS'de bildirilen parseller (${l.length} kayıt)"),
      if (l.isEmpty) Text('${widget.s.sezon} sezonu için işlenmiş ÇKS kaydı yok.'),
      for (final y in sirali)
        _MenuKarti(
          baslik: '$y sezonu',
          alt: '${_uretimYili(y)}${yillar[y]!.length} kayıt · ${sayi(_toplam(yillar[y]!))} da',
          ikon: Icons.event_note,
          dokun: () => tarlaSayfaAc(context, widget.ilk, 'ÇKS · $y', 'Tarla Haritası – ÇKS $y',
              (v) => _CksCiftlikler(sezon: y, l: [for (final x in v.cks) if ((x.sezon.isEmpty ? 'Sezon belirtilmemiş' : x.sezon) == y) x], s: widget.s, ilk: widget.ilk)),
        ),
    ]);
  }
}


// ---------------------------------------------------------------------------
// Haritadan yeni sezon girişi: parsele dokununca ürün / dekar değiştirme.

/// Parsel için işlem penceresi. Girişler her zaman yeni sezona kaydedilir
/// (2025-2026 haritasında dokunulursa 2026-2027'ye).
/// Paylaşım linkiyle yalnızca görüntüleme yetkisi.
bool get _yalnizGor => VeriDeposu.ben.paylasim != null && !VeriDeposu.ben.paylasim!.duzenler;

Future<void> _parselIslem(BuildContext context, TarlaSezonu s, TarlaCiftlik c, TarlaParsel p, {int? parca}) async {
  if (_yalnizGor) {
    await showModalBottomSheet<void>(
        context: context,
        builder: (_) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('${c.ad} · ${p.ad}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text('${s.sezon} sezonu', style: const TextStyle(fontSize: 12, color: Renk.soluk)),
                const SizedBox(height: 8),
                Text(p.urunYazi, style: const TextStyle(fontSize: 15)),
                if (p.not.isNotEmpty) Text(p.not, style: const TextStyle(fontSize: 12.5, color: Renk.amber)),
                const SizedBox(height: 8),
                const Text('Bu paylaşımda yalnızca görüntüleme yetkisi var.', style: TextStyle(fontSize: 12, color: Renk.soluk)),
              ]),
            ));
    return;
  }
  if (p.tip == 'diger') {
    bildir(context, '${p.ad}: ekim alanı değil, ürün girilemez.');
    return;
  }
  final hedef = s.giris ? s.sezon : sonrakiSezon(s.sezon);
  // Bölünmüş parselde parçaya dokunulduysa doğrudan o parçanın ürün/dekar/tohum girişi açılır.
  if (parca != null && s.giris) {
    final v0 = VeriDeposu.ben.veri;
    final g0 = v0 == null ? null : parselGirisi(VeriDeposu.ben.sezonParselleri(v0), hedef, c.ad, p.ad);
    final ic0 = g0 == null ? null : ParselIcerik.oku(g0.urun);
    if (ic0 != null && ic0.bolunmus && parca < ic0.parcalar.length) {
      final tumu = await _parcaDuzenle(context, hedef, c, p, ic0, parca);
      if (!tumu || !context.mounted) return;
    }
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => ListenableBuilder(
      listenable: VeriDeposu.ben,
      builder: (context, _) {
        final v = VeriDeposu.ben.veri;
        final g = v == null ? null : parselGirisi(VeriDeposu.ben.sezonParselleri(v), hedef, c.ad, p.ad);
        final ic = g == null ? null : ParselIcerik.oku(g.urun);
        final bagli = <String>[
          if (v != null)
            for (final x in c.parseller)
              if (parselGirisi(VeriDeposu.ben.sezonParselleri(v), hedef, c.ad, x.ad) case final h?
                  when x.ad != p.ad && ParselIcerik.oku(h.urun).birlesik == p.ad)
                x.ad
        ];
        final once = s.giris ? oncekiUrunler(s, c.ad, p.ad) : [for (final u in p.urunler) urunAnahtari(u.$1)];
        final onceSezon = s.giris ? s.onceki?.sezon : s.sezon;
        final ayni = ic != null &&
            ic.parcalar.any((x) => once.contains(urunAnahtari(x.$1)) && !cokYillik(x.$1) && !ekimDisi(x.$1));
        final cokYil = ic == null
            ? const <String>[]
            : [
                for (final x in ic.parcalar)
                  if (cokYillik(x.$1) && once.contains(urunAnahtari(x.$1))) urunAnahtari(x.$1)
              ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('${c.ad} · ${p.ad}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              if (onceSezon != null)
                Text('$onceSezon: ${once.isEmpty ? 'ürün yok' : once.join(' + ')}', style: const TextStyle(color: Renk.soluk)),
              Text('$hedef: ${g == null ? 'girilmedi' : _girisYazi(g, ic!, bagli)}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              if (ayni)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Münavebe uyarısı: aynı ürün bu parselde üst üste ekiliyor.',
                      style: TextStyle(color: Renk.amber, fontSize: 12.5)),
                ),
              for (final u in cokYil)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      () {
                        final hs = s.giris ? s : null;
                        if (hs == null) return '$u: çok yıllık bitki.';
                        final (n, bas) = ardisikYil(hs, c.ad, p.ad, u);
                        return '$u: ${bas ? 'en az ' : ''}${n < 2 ? 2 : n}. yıl (çok yıllık bitki).';
                      }(),
                      style: const TextStyle(color: Renk.yesil, fontSize: 12.5)),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  final u = await showDialog<String>(context: context, builder: (_) => _UrunSec(secili: g?.urun));
                  if (u == null || !context.mounted) return;
                  await _kaydet(context, hedef, c, p, u, g?.alan);
                },
                icon: const Icon(Icons.grass),
                label: const Text('Ürün değiştir'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  if (ic != null && ic.bolunmus) {
                    await _bol(context, hedef, c, p, ic);
                    return;
                  }
                  // Ürün henüz belli değilse (girilmemiş ya da önceki sezonda birden çok ürün) önce ürün seçilir.
                  var urun = ic?.urun ?? (once.length == 1 ? once.first : null);
                  if (urun == null) {
                    urun = await showDialog<String>(context: context, builder: (_) => const _UrunSec());
                    if (urun == null || !context.mounted) return;
                  }
                  final a = await showDialog<double>(
                      context: context, builder: (_) => _DekarGir(deger: ic?.birlesik == null ? g?.alan : null, urun: urun!));
                  if (a == null || !context.mounted) return;
                  await _kaydet(context, hedef, c, p,
                      ic != null && ic.birlesik == null && ic.urun == urun ? ParselIcerik.urunMetni(urun, ic.cesit(0)) : urun, a);
                },
                icon: const Icon(Icons.straighten),
                label: const Text('Dekar değiştir'),
              ),
              if (ic != null && ic.bolunmus) ...[
                const SizedBox(height: 8),
                const Text('Parçalar (dokunarak ürün, dekar ve tohum girin):',
                    style: TextStyle(fontSize: 12.5, color: Renk.soluk)),
                for (final (i, x) in ic.parcalar.indexed)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(color: urunAdRengi(x.$1), borderRadius: BorderRadius.circular(4))),
                    title: Text('${i + 1}. parça: ${x.$1}${x.$2 == null ? '' : ' · ${_da(x.$2)}'}'
                        '${ic.cesit(i) == null ? '' : ' (${ic.cesit(i)})'}${ic.bag(i) == null ? '' : ' → ${ic.bag(i)}'}'),
                    trailing: const Icon(Icons.edit_outlined, size: 20),
                    onTap: () => _parcaDuzenle(context, hedef, c, p, ic, i, tumuDugmesi: false),
                  ),
              ],
              if (ic != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _tohumGir(context, hedef, c, p, g, ic),
                  icon: const Icon(Icons.spa_outlined),
                  label: Text(ic.cesitler.isEmpty ? 'Tohum / çeşit adı gir' : 'Tohum / çeşit: ${[
                      for (var i = 0; i < ic.parcalar.length; i++)
                        if (ic.cesit(i) != null) ic.cesit(i)!
                    ].join(', ')}'),
                ),
              ],
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _bol(context, hedef, c, p, ic),
                    icon: const Icon(Icons.call_split),
                    label: const Text('Parçalara böl'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _birlestir(context, hedef, c, p, ic, bagli),
                    icon: const Icon(Icons.merge),
                    label: const Text('Birleştir'),
                  ),
                ),
              ]),
              if (p.koord.length > 2) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    sekilKopyala(p.ad, p.koord);
                    Navigator.pop(context);
                    bildir(context,
                        '${p.ad} şekli kopyalandı. Kalem → Yeni parsel ya da Sınır düzenle\'de "Yapıştır" ile istediğiniz sezona/yere koyun.');
                  },
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Şekli kopyala'),
                ),
              ],
              if (ic != null && ic.bolunmus) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _parcaBagla(context, hedef, c, p, ic),
                  icon: const Icon(Icons.link),
                  label: Text(ic.baglar.isEmpty ? 'Parçayı başka parsele bağla' : 'Parça bağlantısını değiştir'),
                ),
              ],
              if (ic != null && ic.bolunmus)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Renk ayrımı için haritanın sol üstündeki kalem düğmesine basıp parselin üzerinden çizgi çekin.',
                      style: TextStyle(fontSize: 12.5, color: Renk.soluk)),
                ),
              if (g != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      // Birleşik grubun ana parseli geri alınırsa bağlı parseller de çözülür.
                      for (final b in bagli) {
                        await VeriDeposu.ben.sezonParselKaydet(
                            sezon: hedef, ciftlik: c.ad, parsel: b, geriAl: true, yenilensin: false);
                      }
                      final m = await VeriDeposu.ben.sezonParselKaydet(sezon: hedef, ciftlik: c.ad, parsel: p.ad, geriAl: true);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        bildir(context, m);
                      }
                    } catch (e) {
                      if (context.mounted) bildir(context, '$e');
                    }
                  },
                  icon: const Icon(Icons.undo),
                  label: Text(ic?.birlesik != null
                      ? 'Birleşimden ayır'
                      : bagli.isNotEmpty
                          ? 'Girişi ve birleştirmeyi geri al'
                          : 'Girişi geri al'),
                ),
              ],
              const SizedBox(height: 6),
              Text('Kayıt $hedef sezonu verilerine eklenir (Sezon_Parselleri). Kaynak Excel dosyaları değişmez.',
                  style: const TextStyle(fontSize: 11.5, color: Renk.soluk)),
            ]),
          ),
        );
      },
    ),
  );
}

String _girisYazi(SezonParsel g, ParselIcerik ic, List<String> bagli) {
  if (ic.birlesik != null) return '${ic.urun} · ${ic.birlesik} ile birleştirildi';
  if (ic.bolunmus) {
    return ic.parcalar.map((x) => '${x.$1}${x.$2 == null ? '' : ' ${_da(x.$2)}'}').join(' + ');
  }
  return '${g.urun}${g.alan == null ? '' : ' · ${_da(g.alan)}'}'
      '${bagli.isEmpty ? '' : ' (${bagli.join(', ')} ile birlikte)'}';
}

/// Parseli 2–3 parçaya böler (her parçaya ürün ve dekar). Kayıt: "Arpa:120+Buğday:120".
Future<void> _bol(BuildContext context, String sezon, TarlaCiftlik c, TarlaParsel p, ParselIcerik? ic) async {
  final l = await showDialog<List<(String, double)>>(
      context: context, builder: (_) => _ParcaGir(baslik: p.ad, mevcut: ic != null && ic.bolunmus ? ic.parcalar : const []));
  if (l == null || !context.mounted) return;
  final eski = ic != null && ic.bolunmus && ic.cizgiler.length == l.length - 1 ? ic.cizgiler : const <(double, double)>[];
  final ayniSayi = ic != null && ic.parcalar.length == l.length;
  final metin = ParselIcerik.bolunmusMetin(l, eski, ayniSayi ? ic.baglar : const [], ayniSayi ? ic.cesitler : const [],
      ayniSayi ? ic.bolgeler : const []);
  if (!_sigarMi(context, metin)) return;
  await _kaydet(context, sezon, c, p, metin, l.fold<double>(0, (a, x) => a + x.$2));
}

/// Bu parseli seçilen komşu parsellerle birleştirir: tek ürün, toplam dekar bu parselde tutulur,
/// diğerleri "Ürün@bu parsel" olarak bağlanır.
Future<void> _birlestir(BuildContext context, String sezon, TarlaCiftlik c, TarlaParsel p, ParselIcerik? ic,
    List<String> bagli) async {
  final adaylar = [for (final x in c.parseller) if (x.ad != p.ad && x.tip != 'diger') x.ad];
  final r = await showDialog<(Set<String>, String, double?)>(
      context: context,
      builder: (_) => _BirlestirGir(
          ana: p.ad, adaylar: adaylar, secili: bagli.toSet(), urun: ic?.bolunmus == false ? ic?.urun : null));
  if (r == null || !context.mounted) return;
  final (secilen, urun, alan) = r;
  final mesaj = ScaffoldMessenger.of(context);
  try {
    for (final b in bagli) {
      if (!secilen.contains(b)) {
        await VeriDeposu.ben.sezonParselKaydet(sezon: sezon, ciftlik: c.ad, parsel: b, geriAl: true, yenilensin: false);
      }
    }
    for (final b in secilen) {
      await VeriDeposu.ben.sezonParselKaydet(
          sezon: sezon, ciftlik: c.ad, parsel: b, urun: '$urun@${p.ad}', yenilensin: false);
    }
    await VeriDeposu.ben.sezonParselKaydet(sezon: sezon, ciftlik: c.ad, parsel: p.ad, urun: urun, alan: alan);
    mesaj.showSnackBar(SnackBar(content: Text('${p.ad} ile ${secilen.join(', ')} birleştirildi: $urun'
        '${alan == null ? '' : ' · ${_da(alan)}'}')));
  } catch (e) {
    mesaj.showSnackBar(SnackBar(content: Text('$e')));
  }
}

/// Haritada çizilen ayırma çizgisini kaydeder (ürün ve dekarlar değişmez).
/// Çizgi kayıtları her zaman haritası açık olan sezona yazılır (KMZ sezonunda da).
Future<void> _cizgiKaydet(BuildContext context, TarlaSezonu s, TarlaCiftlik c, TarlaParsel p, List<(double, double)> cz) async {
  final hedef = s.sezon;
  final l = [for (final u in p.urunler) (u.$1, u.$2)];
  final metin = ParselIcerik.bolunmusMetin(l, cz, p.baglar, p.cesitler, p.bolgeler);
  if (!_sigarMi(context, metin)) return;
  await _kaydet(context, hedef, c, p, metin, p.beyan ?? l.fold<double>(0, (a, x) => a + x.$2));
}

/// Tek ürünlü parsel haritada çizilen çizgiyle iki parçaya bölünür: parça ürünleri ve dekarları sorulur
/// (dekar önerisi çizginin ayırdığı alan oranıyla).
Future<void> _cizgiIleBol(
    BuildContext context, TarlaSezonu s, TarlaCiftlik c, TarlaParsel p, (double, double) cz, double oran) async {
  final toplam = p.beyan ?? p.olculen ?? p.urunler.fold<double>(0, (a, x) => a + x.$2);
  final ilk = p.urunler.isEmpty ? null : p.urunler.first.$1;
  double? yuvarla(double v) => toplam <= 0 ? null : (v * 10).round() / 10;
  final l = await showDialog<List<(String, double)>>(
      context: context,
      builder: (_) => _ParcaGir(baslik: '${p.ad} (çizgiyle)', mevcut: [
            (ilk != null && secilebilirUrunler.contains(urunAnahtari(ilk)) ? urunAnahtari(ilk) : secilebilirUrunler[1], yuvarla(toplam * oran)),
            (secilebilirUrunler.first, yuvarla(toplam * (1 - oran))),
          ]));
  if (l == null || !context.mounted) return;
  if (l.length != 2) {
    bildir(context, 'Çizgiyle bölmede iki parça girin; üçüncü parça için ikinci çizgiyi sonra çekin.');
    return;
  }
  final metin = ParselIcerik.bolunmusMetin(l, [cz]);
  if (!_sigarMi(context, metin)) return;
  await _kaydet(context, s.sezon, c, p, metin, l.fold<double>(0, (a, x) => a + x.$2));
}

/// Bölünmüş parselin bir parçasını başka bir parsele bağlar: parça o parselin ürününü alır,
/// dekarı o parselde sayılır. Kayıt: "Arpa>1. parsel:12+Buğday:90/…".
Future<void> _parcaBagla(BuildContext context, String sezon, TarlaCiftlik c, TarlaParsel p, ParselIcerik ic) async {
  final adaylar = [for (final x in c.parseller) if (x.ad != p.ad && x.tip != 'diger') x.ad];
  final r = await showDialog<(int, String?)>(
      context: context, builder: (_) => _ParcaBaglaGir(ic: ic, adaylar: adaylar));
  if (r == null || !context.mounted) return;
  final (i, hedefParsel) = r;
  final v = VeriDeposu.ben.veri;
  final urunler = [for (final x in ic.parcalar) (x.$1, x.$2 ?? 0.0)];
  if (hedefParsel != null && v != null) {
    // Parça, bağlandığı parselin ürününü alır (o parselde tek ürün girilmişse).
    final h = parselGirisi(VeriDeposu.ben.sezonParselleri(v), sezon, c.ad, hedefParsel);
    final hu = h == null ? null : ParselIcerik.oku(h.urun);
    if (hu != null && !hu.bolunmus && hu.birlesik == null && hu.urun.isNotEmpty) urunler[i] = (hu.urun, urunler[i].$2);
  }
  final baglar = [for (var j = 0; j < urunler.length; j++) j == i ? hedefParsel : ic.bag(j)];
  final metin = ParselIcerik.bolunmusMetin(urunler, ic.cizgiler, baglar, ic.cesitler, ic.bolgeler);
  if (!_sigarMi(context, metin)) return;
  await _kaydet(context, sezon, c, p, metin, urunler.fold<double>(0, (a, x) => a + x.$2));
}

class _ParcaBaglaGir extends StatefulWidget {
  const _ParcaBaglaGir({required this.ic, required this.adaylar});
  final ParselIcerik ic;
  final List<String> adaylar;
  @override
  State<_ParcaBaglaGir> createState() => _ParcaBaglaGirState();
}

class _ParcaBaglaGirState extends State<_ParcaBaglaGir> {
  int _i = 0;
  late String? _hedef = widget.ic.bag(0);
  static const _yok = '— bağlı değil —';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Parçayı başka parsele bağla'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Hangi parça?', style: TextStyle(fontWeight: FontWeight.w700)),
            for (final (i, x) in widget.ic.parcalar.indexed)
              RadioListTile<int>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: i,
                groupValue: _i,
                onChanged: (v) => setState(() {
                  _i = v!;
                  _hedef = widget.ic.bag(v);
                }),
                title: Text('${i + 1}. parça: ${x.$1}${x.$2 == null ? '' : ' ${_da(x.$2)}'}'
                    '${widget.ic.bag(i) == null ? '' : ' → ${widget.ic.bag(i)}'}'),
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _hedef ?? _yok,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Bağlanacağı parsel'),
              items: [for (final a in [_yok, ...widget.adaylar]) DropdownMenuItem(value: a, child: Text(a))],
              onChanged: (v) => setState(() => _hedef = v == _yok ? null : v),
            ),
            const SizedBox(height: 8),
            const Text('Bağlanan parça o parselin ürününü alır; dekarı o parselin alanına eklenir, bu parselden düşülür.',
                style: TextStyle(fontSize: 12, color: Renk.soluk)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, (_i, _hedef)), child: const Text('Kaydet')),
        ],
      );
}

/// Bölünmüş parselin tek parçasının ürün, dekar ve tohumunu düzenler.
/// Dönüş: kullanıcı "Parselin tümü" dediyse true.
Future<bool> _parcaDuzenle(BuildContext context, String sezon, TarlaCiftlik c, TarlaParsel p, ParselIcerik ic, int i,
    {bool tumuDugmesi = true}) async {
  final r = await showDialog<Object>(
      context: context,
      builder: (_) => _ParcaDuzenleGir(
          baslik: '${p.ad} · ${i + 1}. parça',
          urun: ic.parcalar[i].$1,
          dekar: ic.parcalar[i].$2,
          tohum: ic.cesit(i),
          tumuDugmesi: tumuDugmesi));
  if (r == 'tumu') return true;
  if (r is! (String, double, String?) || !context.mounted) return false;
  final (urun, dekar, tohum) = r;
  final l = [for (final (j, x) in ic.parcalar.indexed) j == i ? (urun, dekar) : (x.$1, x.$2 ?? 0.0)];
  final cesitler = [for (var j = 0; j < l.length; j++) j == i ? tohum : ic.cesit(j)];
  final metin = ParselIcerik.bolunmusMetin(l, ic.cizgiler, ic.baglar, cesitler, ic.bolgeler);
  if (!_sigarMi(context, metin)) return false;
  await _kaydet(context, sezon, c, p, metin, l.fold<double>(0, (a, x) => a + x.$2));
  return false;
}

class _ParcaDuzenleGir extends StatefulWidget {
  const _ParcaDuzenleGir({required this.baslik, required this.urun, this.dekar, this.tohum, this.tumuDugmesi = true});
  final String baslik, urun;
  final double? dekar;
  final String? tohum;
  final bool tumuDugmesi;
  @override
  State<_ParcaDuzenleGir> createState() => _ParcaDuzenleGirState();
}

class _ParcaDuzenleGirState extends State<_ParcaDuzenleGir> {
  late String _urun = widget.urun;
  late final _da = TextEditingController(
      text: widget.dekar == null || widget.dekar == 0 ? '' : sayi(widget.dekar, ondalik: widget.dekar! % 1 == 0 ? 0 : 1));
  late final _tohum = TextEditingController(text: widget.tohum ?? '');

  @override
  void dispose() {
    _da.dispose();
    _tohum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _dekarOku(_da.text);
    final urunler = [...secilebilirUrunler, if (!secilebilirUrunler.contains(widget.urun)) widget.urun];
    return AlertDialog(
      title: Text(widget.baslik),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DropdownButtonFormField<String>(
            initialValue: _urun,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Ürün / alan türü'),
            items: [for (final u in urunler) DropdownMenuItem(value: u, child: Text(u))],
            onChanged: (x) => setState(() => _urun = x ?? _urun),
          ),
          TextField(
            controller: _da,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Dekar'),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _tohum,
            maxLength: 24,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Tohum / çeşit (isteğe bağlı)'),
          ),
        ]),
      ),
      actions: [
        if (widget.tumuDugmesi)
          TextButton(onPressed: () => Navigator.pop(context, 'tumu'), child: const Text('Parselin tümü')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
            onPressed: d == null || d <= 0
                ? null
                : () {
                    final t = _tohum.text.trim().replaceAll(RegExp(r'[#@>:+/;]'), '');
                    Navigator.pop(context, (_urun, d, t.isEmpty ? null : t));
                  },
            child: const Text('Kaydet')),
      ],
    );
  }
}

/// Ekilen tohum / çeşit adını girer (her parça için ayrı). Öneriler Tarımsal Faaliyet planındaki çeşitlerden.
Future<void> _tohumGir(
    BuildContext context, String sezon, TarlaCiftlik c, TarlaParsel p, SezonParsel? g, ParselIcerik ic) async {
  final v = VeriDeposu.ben.veri;
  List<String> oneriler(String urun) {
    final m = <String>{};
    for (final cf in v?.tarimsalUretim.ciftlikler ?? const []) {
      for (final k in cf.urunler) {
        if (urunAnahtari(k.ad) != urunAnahtari(urun)) continue;
        for (final t in k.cesit.split(RegExp(r'[-,/]'))) {
          final x = t.trim();
          if (x.length > 1) m.add(x[0].toUpperCase() + x.substring(1).toLowerCase());
        }
      }
    }
    return m.toList()..sort();
  }

  final sonuc = await showDialog<List<String?>>(
      context: context,
      builder: (_) => _TohumGir(
          urunler: [for (final x in ic.parcalar) x.$1],
          mevcut: [for (var i = 0; i < ic.parcalar.length; i++) ic.cesit(i)],
          oneriler: [for (final x in ic.parcalar) oneriler(x.$1)]));
  if (sonuc == null || !context.mounted) return;
  final String metin;
  final double? alan;
  if (ic.birlesik != null) {
    metin = '${ParselIcerik.urunMetni(ic.urun, sonuc.first)}@${ic.birlesik}';
    alan = null;
  } else if (ic.bolunmus) {
    final l = [for (final x in ic.parcalar) (x.$1, x.$2 ?? 0.0)];
    metin = ParselIcerik.bolunmusMetin(l, ic.cizgiler, ic.baglar, sonuc, ic.bolgeler);
    alan = l.fold<double>(0, (a, x) => a + x.$2);
  } else {
    metin = ParselIcerik.urunMetni(ic.urun, sonuc.first);
    alan = g?.alan;
  }
  if (!_sigarMi(context, metin)) return;
  await _kaydet(context, sezon, c, p, metin, alan);
}

class _TohumGir extends StatefulWidget {
  const _TohumGir({required this.urunler, required this.mevcut, required this.oneriler});
  final List<String> urunler;
  final List<String?> mevcut;
  final List<List<String>> oneriler;
  @override
  State<_TohumGir> createState() => _TohumGirState();
}

class _TohumGirState extends State<_TohumGir> {
  late final _t = [for (final m in widget.mevcut) TextEditingController(text: m ?? '')];

  @override
  void dispose() {
    for (final t in _t) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Tohum / çeşit adı'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < widget.urunler.length; i++) ...[
              TextField(
                controller: _t[i],
                maxLength: 24,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: widget.urunler[i], hintText: 'örn. Altındane, Halis, Touareg'),
                onChanged: (_) => setState(() {}),
              ),
              if (widget.oneriler[i].isNotEmpty)
                Wrap(spacing: 6, runSpacing: 0, children: [
                  for (final o in widget.oneriler[i])
                    ActionChip(label: Text(o), onPressed: () => setState(() => _t[i].text = o)),
                ]),
              const SizedBox(height: 8),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(context, [
                    for (final t in _t)
                      t.text.trim().replaceAll(RegExp(r'[#@>:+/;]'), '').isEmpty
                          ? null
                          : t.text.trim().replaceAll(RegExp(r'[#@>:+/;]'), '')
                  ]),
              child: const Text('Kaydet')),
        ],
      );
}

/// Sınır kaydının anahtarı: esas haritada parsel adı; parsel düzeni farklı eski sezonda "sezon|parsel adı".
String _sinirAnahtari(TarlaSezonu s, String ad) => s.tur == 'ayri' ? '${s.sezon}|$ad' : ad;

/// Haritada sınırı değiştirilmiş ya da haritadan eklenmiş parsel adları.
Set<String> _degisenSinirlar(RaporVerisi v, TarlaSezonu s, TarlaCiftlik c) => {
      for (final k in gecerliSinirlar(VeriDeposu.ben.parselSinirleri(v)).keys)
        if (k.$1 == c.ad)
          if (s.tur == 'ayri' ? k.$2.startsWith('${s.sezon}|') : !k.$2.contains('|'))
            s.tur == 'ayri' ? k.$2.substring(s.sezon.length + 1) : k.$2
    };

/// Yeniden çizilen sınırı (ya da yeni parseli) kaydeder. Sınır tüm sezonlarda geçerlidir (2023-2024 gibi parsel
/// düzeni farklı sezonda yalnızca o sezonda). Yeni parselde ad, ürün ve dekar sorulur.
Future<bool> _sinirKaydet(
    BuildContext context, TarlaSezonu s, TarlaCiftlik c, TarlaParsel? p, List<(double, double)> k, double da) async {
  var ad = p?.ad;
  String? urun;
  double? dekar;
  final kapsam = s.tur == 'ayri' ? 'yalnızca ${s.sezon} sezonunun' : 'tüm sezonların';
  if (ad == null) {
    final cizilmemis = [for (final x in c.parseller) if (x.koord.length <= 2) x.ad];
    final cizili = {for (final x in c.parseller) if (x.koord.length > 2) x.ad};
    final r = await showDialog<(String, String?, double?)>(
        context: context,
        builder: (_) => _YeniParselAdi(cizilmemis: cizilmemis, cizili: cizili, dekar: da, kapsam: kapsam, sezon: s.giris ? s.sezon : sonrakiSezon(s.sezon)));
    if (r == null || !context.mounted) return false;
    (ad, urun, dekar) = r;
  } else {
    final onay = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
              title: Text('$ad sınırı'),
              content: Text('Yeni sınır $kapsam haritasında kullanılacak. Çizilen alan yaklaşık ${sayi(da)} da '
                  '(beyan edilen dekar değişmez; gerekirse parselden ayrıca düzeltin).'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Vazgeç')),
                FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Kaydet')),
              ],
            ));
    if (onay != true || !context.mounted) return false;
  }
  try {
    final m = await VeriDeposu.ben.parselSinirKaydet(ciftlik: c.ad, parsel: _sinirAnahtari(s, ad), koord: k);
    if (urun != null) {
      await VeriDeposu.ben.sezonParselKaydet(
          sezon: s.giris ? s.sezon : sonrakiSezon(s.sezon), ciftlik: c.ad, parsel: ad, urun: urun, alan: dekar);
    }
    if (context.mounted) bildir(context, '$m Çizilen alan ≈ ${sayi(da)} da.');
    return true;
  } catch (e) {
    if (context.mounted) bildir(context, '$e');
    return false;
  }
}

Future<bool> _sinirGeriAl(BuildContext context, TarlaSezonu s, TarlaCiftlik c, TarlaParsel p) async {
  try {
    final m = await VeriDeposu.ben.parselSinirKaydet(ciftlik: c.ad, parsel: _sinirAnahtari(s, p.ad), geriAl: true);
    if (context.mounted) bildir(context, m);
    return true;
  } catch (e) {
    if (context.mounted) bildir(context, '$e');
    return false;
  }
}

class _YeniParselAdi extends StatefulWidget {
  const _YeniParselAdi(
      {required this.cizilmemis, required this.cizili, required this.dekar, required this.kapsam, required this.sezon});
  final List<String> cizilmemis;
  final Set<String> cizili;
  final double dekar;
  final String kapsam, sezon;
  @override
  State<_YeniParselAdi> createState() => _YeniParselAdiState();
}

class _YeniParselAdiState extends State<_YeniParselAdi> {
  final _ad = TextEditingController();
  String? _urun;
  late final _da = TextEditingController(text: widget.dekar > 0 ? '${widget.dekar.round()}' : '');
  @override
  void dispose() {
    _ad.dispose();
    _da.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad.text.trim();
    final hata = ad.isEmpty ? null : (widget.cizili.contains(ad) ? 'Bu adla çizili bir parsel var.' : null);
    final da = _dekarOku(_da.text);
    return AlertDialog(
      title: const Text('Yeni parsel'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Çizilen alan yaklaşık ${sayi(widget.dekar)} da. Sınır ${widget.kapsam} haritasında kullanılır.',
              style: const TextStyle(fontSize: 13)),
          if (widget.cizilmemis.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Haritada sınırı olmayan parseller:', style: TextStyle(fontSize: 12.5, color: Renk.soluk)),
            Wrap(spacing: 6, children: [
              for (final x in widget.cizilmemis)
                ActionChip(label: Text(x), onPressed: () => setState(() => _ad.text = x)),
            ]),
          ],
          TextField(
            controller: _ad,
            maxLength: 80,
            decoration: InputDecoration(labelText: 'Parsel adı', hintText: 'Örn. 12. parsel', errorText: hata),
            onChanged: (_) => setState(() {}),
          ),
          DropdownButtonFormField<String?>(
            initialValue: _urun,
            isExpanded: true,
            decoration: InputDecoration(labelText: '${widget.sezon} ürünü / alan türü'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('— şimdi girmeyeceğim —')),
              for (final u in secilebilirUrunler) DropdownMenuItem<String?>(value: u, child: Text(u)),
            ],
            onChanged: (x) => setState(() => _urun = x),
          ),
          if (_urun != null)
            TextField(
              controller: _da,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Dekar', helperText: 'Öneri, çizdiğiniz alana göre'),
              onChanged: (_) => setState(() {}),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
            onPressed: ad.isEmpty || hata != null || (_urun != null && (da == null || da <= 0))
                ? null
                : () => Navigator.pop(context, (ad, _urun, _urun == null ? null : da)),
            child: const Text('Kaydet')),
      ],
    );
  }
}

/// Parsel içine çizilen bölgeyi kaydeder: bölgenin ürünü/dekarı ve parselin kalanının ürünü/dekarı sorulur.
Future<void> _bolgeEkle(BuildContext context, TarlaSezonu s, TarlaCiftlik c, TarlaParsel p, ParselBolge b, double pay) async {
  final eskiBolge = p.bolgeler.isNotEmpty && p.urunler.length == p.bolgeler.length + 1;
  final toplam = p.beyan ?? p.olculen ?? p.urunler.fold<double>(0, (a, x) => a + x.$2);
  final eskiBolgeDa = eskiBolge
      ? [for (var i = 0; i < p.bolgeler.length; i++) p.urunler[i].$2].fold<double>(0, (a, x) => a + x)
      : 0.0;
  final kalanUrun = p.urunler.isEmpty ? null : (eskiBolge ? p.urunler.last.$1 : p.urunler.first.$1);
  double? yuvarla(double v) => v <= 0 ? null : (v * 10).round() / 10;
  final r = await showDialog<((String, double), (String, double))>(
      context: context,
      builder: (_) => _BolgeGir(
            baslik: p.ad,
            bolgeDa: toplam > 0 ? yuvarla(toplam * pay) : null,
            kalanUrun: kalanUrun,
            toplam: toplam > 0 ? toplam - eskiBolgeDa : null,
          ));
  if (r == null || !context.mounted) return;
  final (yeni, kalan) = r;
  final l = <(String, double)>[
    if (eskiBolge) for (var i = 0; i < p.bolgeler.length; i++) p.urunler[i],
    yeni,
    kalan,
  ];
  final n = eskiBolge ? p.bolgeler.length : 0;
  final cesitler = <String?>[for (var i = 0; i < n; i++) p.cesit(i), null, eskiBolge ? p.cesit(p.urunler.length - 1) : null];
  final baglar = <String?>[for (var i = 0; i < n; i++) p.bag(i), null, eskiBolge ? p.bag(p.urunler.length - 1) : null];
  final metin = ParselIcerik.bolunmusMetin(l, const [], baglar, cesitler, [if (eskiBolge) ...p.bolgeler, b]);
  if (!_sigarMi(context, metin)) return;
  await _kaydet(context, s.sezon, c, p, metin, l.fold<double>(0, (a, x) => a + x.$2));
}

class _BolgeGir extends StatefulWidget {
  const _BolgeGir({required this.baslik, this.bolgeDa, this.kalanUrun, this.toplam});
  final String baslik;
  final double? bolgeDa, toplam;
  final String? kalanUrun;
  @override
  State<_BolgeGir> createState() => _BolgeGirState();
}

class _BolgeGirState extends State<_BolgeGir> {
  String _bolgeUrun = 'Deneme alanı';
  late String _kalanUrun = widget.kalanUrun != null && secilebilirUrunler.contains(urunAnahtari(widget.kalanUrun!))
      ? urunAnahtari(widget.kalanUrun!)
      : secilebilirUrunler.first;
  late final _bDa = TextEditingController(text: widget.bolgeDa == null ? '' : sayi(widget.bolgeDa, ondalik: widget.bolgeDa! % 1 == 0 ? 0 : 1));
  late final _kDa = TextEditingController(
      text: widget.toplam == null || widget.bolgeDa == null
          ? ''
          : sayi(math.max(0, widget.toplam! - widget.bolgeDa!), ondalik: 0));

  @override
  void dispose() {
    _bDa.dispose();
    _kDa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = _dekarOku(_bDa.text), k = _dekarOku(_kDa.text);
    Widget urunSec(String deger, ValueChanged<String> sec, String etiket) => DropdownButtonFormField<String>(
          initialValue: deger,
          isExpanded: true,
          decoration: InputDecoration(labelText: etiket),
          items: [for (final u in secilebilirUrunler) DropdownMenuItem(value: u, child: Text(u))],
          onChanged: (x) => setState(() => sec(x ?? deger)),
        );
    return AlertDialog(
      title: Text('${widget.baslik} · çizilen bölge'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          urunSec(_bolgeUrun, (x) => _bolgeUrun = x, 'Bölgenin ürünü / alan türü'),
          TextField(
            controller: _bDa,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Bölgenin dekarı', helperText: 'Öneri, çizdiğiniz alana göre'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          urunSec(_kalanUrun, (x) => _kalanUrun = x, 'Parselin kalanının ürünü'),
          TextField(
            controller: _kDa,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Kalanın dekarı'),
            onChanged: (_) => setState(() {}),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
            onPressed: b == null || b <= 0 || k == null || k < 0
                ? null
                : () => Navigator.pop(context, ((_bolgeUrun, b), (_kalanUrun, k))),
            child: const Text('Kaydet')),
      ],
    );
  }
}

/// Kayıt sunucunun "Ürün" alanına sığıyor mu (eski Apps Script 60 karakter saklar).
bool _sigarMi(BuildContext context, String metin) {
  final sinir = VeriDeposu.ben.veri?.sezonParselSiniri ?? 60;
  if (metin.length <= sinir) return true;
  bildir(
      context,
      sinir <= 60
          ? 'Bu kayıt uzun (bölge/tohum bilgisi). Kaydetmek için Apps Script kodunun güncellenmesi gerekiyor.'
          : 'Kayıt çok uzun; ürün, tohum ya da bölge sayısını azaltın.');
  return false;
}

Future<void> _kaydet(BuildContext context, String sezon, TarlaCiftlik c, TarlaParsel p, String urun, double? alan) async {
  try {
    final m = await VeriDeposu.ben.sezonParselKaydet(sezon: sezon, ciftlik: c.ad, parsel: p.ad, urun: urun, alan: alan);
    if (context.mounted) bildir(context, m);
  } catch (e) {
    if (context.mounted) bildir(context, '$e');
  }
}

class _UrunSec extends StatefulWidget {
  const _UrunSec({this.secili});
  final String? secili;
  @override
  State<_UrunSec> createState() => _UrunSecState();
}

class _UrunSecState extends State<_UrunSec> {
  static const _diger = 'Diğer';
  late String _s = widget.secili == null
      ? secilebilirUrunler.first
      : (secilebilirUrunler.contains(widget.secili) ? widget.secili! : _diger);
  late final _ad = TextEditingController(text: secilebilirUrunler.contains(widget.secili) ? '' : (widget.secili ?? ''));

  @override
  void dispose() {
    _ad.dispose();
    super.dispose();
  }

  String get _sonuc => _s == _diger ? _ad.text.trim() : _s;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Ürün seçin'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final u in [...secilebilirUrunler, _diger])
              RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: u,
                groupValue: _s,
                onChanged: (x) => setState(() => _s = x!),
                title: Text(u),
              ),
            if (_s == _diger)
              TextField(
                controller: _ad,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Ürün adı'),
                onChanged: (_) => setState(() {}),
              ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(onPressed: _sonuc.isEmpty ? null : () => Navigator.pop(context, _sonuc), child: const Text('Kaydet')),
        ],
      );
}

class _DekarGir extends StatefulWidget {
  const _DekarGir({this.deger, required this.urun});
  final double? deger;
  final String urun;
  @override
  State<_DekarGir> createState() => _DekarGirState();
}

class _DekarGirState extends State<_DekarGir> {
  late final _t = TextEditingController(text: widget.deger == null ? '' : sayi(widget.deger, ondalik: widget.deger! % 1 == 0 ? 0 : 1));

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  double? get _d {
    final x = _dekarOku(_t.text);
    return x == null || x <= 0 ? null : x;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${widget.urun} · alan'),
        content: TextField(
          controller: _t,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Ekim alanı (da)'),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(onPressed: _d == null ? null : () => Navigator.pop(context, _d), child: const Text('Kaydet')),
        ],
      );
}

/// "120", "120,5", "120.5" (telefon klavyesi), "1.250" → dekar.
double? _dekarOku(String t) {
  final s = t.trim().replaceAll(' ', '');
  if (s.isEmpty) return null;
  if (s.contains(',')) return double.tryParse(s.replaceAll('.', '').replaceAll(',', '.'));
  if (RegExp(r'^\d+\.\d{1,2}$').hasMatch(s)) return double.tryParse(s);
  return double.tryParse(s.replaceAll('.', ''));
}

/// Parçalara bölme: 2–3 satır, her satırda ürün ve dekar.
class _ParcaGir extends StatefulWidget {
  const _ParcaGir({required this.baslik, this.mevcut = const []});
  final String baslik;
  final List<(String, double?)> mevcut;
  @override
  State<_ParcaGir> createState() => _ParcaGirState();
}

class _ParcaGirState extends State<_ParcaGir> {
  late final List<String> _urun = [
    for (var i = 0; i < 3; i++)
      i < widget.mevcut.length && secilebilirUrunler.contains(widget.mevcut[i].$1)
          ? widget.mevcut[i].$1
          : secilebilirUrunler[i == 0 ? 1 : 0],
  ];
  late final List<TextEditingController> _da = [
    for (var i = 0; i < 3; i++)
      TextEditingController(
          text: i < widget.mevcut.length && widget.mevcut[i].$2 != null ? sayi(widget.mevcut[i].$2, ondalik: widget.mevcut[i].$2! % 1 == 0 ? 0 : 1) : ''),
  ];
  late int _adet = widget.mevcut.length == 3 ? 3 : 2;

  @override
  void dispose() {
    for (final t in _da) {
      t.dispose();
    }
    super.dispose();
  }

  List<(String, double)>? get _sonuc {
    final l = <(String, double)>[];
    for (var i = 0; i < _adet; i++) {
      final d = _dekarOku(_da[i].text);
      if (d == null || d <= 0) return null;
      l.add((_urun[i], d));
    }
    return l;
  }

  @override
  Widget build(BuildContext context) {
    final s = _sonuc;
    return AlertDialog(
      title: Text('${widget.baslik} · parçalara böl'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < _adet; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _urun[i],
                    isExpanded: true,
                    decoration: InputDecoration(labelText: '${i + 1}. parça'),
                    items: [for (final u in secilebilirUrunler) DropdownMenuItem(value: u, child: Text(u))],
                    onChanged: (x) => setState(() => _urun[i] = x ?? _urun[i]),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _da[i],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Dekar'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ]),
            ),
          Row(children: [
            if (_adet < 3)
              TextButton.icon(
                  onPressed: () => setState(() => _adet = 3), icon: const Icon(Icons.add), label: const Text('3. parça')),
            if (_adet == 3)
              TextButton.icon(
                  onPressed: () => setState(() => _adet = 2), icon: const Icon(Icons.remove), label: const Text('2 parça')),
          ]),
          if (s != null)
            Text('Toplam ${_da0(s.fold<double>(0, (a, x) => a + x.$2))}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(onPressed: s == null ? null : () => Navigator.pop(context, s), child: const Text('Kaydet')),
      ],
    );
  }
}

String _da0(double d) => '${sayi(d, ondalik: d % 1 == 0 ? 0 : 1)} da';

/// Birleştirme: aynı ürünle ekilecek komşu parseller ve toplam dekar.
class _BirlestirGir extends StatefulWidget {
  const _BirlestirGir({required this.ana, required this.adaylar, this.secili = const {}, this.urun});
  final String ana;
  final List<String> adaylar;
  final Set<String> secili;
  final String? urun;
  @override
  State<_BirlestirGir> createState() => _BirlestirGirState();
}

class _BirlestirGirState extends State<_BirlestirGir> {
  late final Set<String> _sec = {...widget.secili};
  late String _urun = widget.urun != null && secilebilirUrunler.contains(widget.urun) ? widget.urun! : secilebilirUrunler.first;
  final _da = TextEditingController();

  @override
  void dispose() {
    _da.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${widget.ana} · birleştir'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Bu parselle birlikte aynı ürünle ekilecek parselleri seçin:', style: TextStyle(fontSize: 13)),
            for (final a in widget.adaylar)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _sec.contains(a),
                title: Text(a),
                onChanged: (x) => setState(() => x == true ? _sec.add(a) : _sec.remove(a)),
              ),
            DropdownButtonFormField<String>(
              initialValue: _urun,
              decoration: const InputDecoration(labelText: 'Ürün'),
              items: [for (final u in secilebilirUrunler) DropdownMenuItem(value: u, child: Text(u))],
              onChanged: (x) => setState(() => _urun = x ?? _urun),
            ),
            TextField(
              controller: _da,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Birleşik alanın toplam dekarı', hintText: 'bilinmiyorsa boş bırakın'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(
              onPressed: _sec.isEmpty ? null : () => Navigator.pop(context, (_sec, _urun, _dekarOku(_da.text))),
              child: const Text('Birleştir')),
        ],
      );
}

/// Yeni sezon karşılaştırması: girilen alanlar ile Excel ekim planı ve münavebe.
class _GirisKarsilastirma extends StatelessWidget {
  const _GirisKarsilastirma({required this.s, required this.v});
  final TarlaSezonu s;
  final RaporVerisi v;

  @override
  Widget build(BuildContext context) {
    final kaynak = sezonExcelKaynak(s);
    // Çiftlik, ürün, girilen, Excel, ÇKS
    final satirlar = <(String, String, double?, double?, double?)>[];
    var excelVar = false;
    for (final c in s.ciftlikler) {
      final g = c.urunToplami, ex = sezonExcel(v.ekim, v.ekimPlani, s, c.ad);
      if (ex.isNotEmpty) excelVar = true;
      final k = <String, double>{};
      for (final x in v.cks) {
        if (x.sezon != s.sezon || ciftlikAnahtari(x.ciftlik) != ciftlikAnahtari(c.ad) || x.alan == null) continue;
        k.update(urunAnahtari(x.urun), (a) => a + x.alan!, ifAbsent: () => x.alan!);
      }
      for (final u in {...g.keys, ...ex.keys, ...k.keys}) {
        satirlar.add((c.ad, u, g[u], ex[u], k[u]));
      }
    }
    // Münavebe: önceki sezon → bu sezon; ilk sezonda bu sezon → sonraki sezon.
    final ileri = s.onceki == null && s.sonraki != null;
    final karsiSezon = ileri ? s.sonraki! : s.onceki;
    final munavebe = <(String, TarlaParsel, List<String>)>[];
    var girilmeyen = 0;
    for (final c in s.ciftlikler) {
      for (final p in c.parseller) {
        if (p.girilmedi) girilmeyen++;
        if (p.urunler.isEmpty) continue;
        munavebe.add((c.ad, p, sezonUrunleri(karsiSezon, c.ad, p.ad)));
      }
    }
    Widget h(String t, {TextAlign a = TextAlign.right}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(t, textAlign: a, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)));
    Widget d(String t, {Color? renk}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(t, textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, color: renk, fontWeight: renk == null ? null : FontWeight.w800)));
    return ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 24), children: [
      BilgiKutusu(
          yazi: '${s.sezon} sezonu, haritada parsellere dokunularak girilen ürün ve alanlardan oluşur. '
              'Esas alınan kaynak Excel: $kaynak. Girilen alanlar ve ÇKS bu rakamlarla karşılaştırılır.'
              '${excelVar ? '' : ' Excel dosyalarında bu yıl için henüz kayıt yok; girildiğinde burada görünür.'}'),
      if (girilmeyen > 0)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Ürün girilmemiş parsel: $girilmeyen', style: const TextStyle(color: Renk.amber, fontSize: 12.5)),
        ),
      const BolumBasligi('Excel esaslı ekim alanları (da)'),
      if (satirlar.isEmpty)
        const Text('Henüz kayıt yok. Harita sekmesinde bir parsele dokunarak ürün ve dekar girin.')
      else
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2.3), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1), 4: FlexColumnWidth(1)
              },
              border: TableBorder(horizontalInside: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
              children: [
                TableRow(children: [h('Çiftlik · Ürün', a: TextAlign.left), h('Excel'), h('Harita'), h('ÇKS'), h('Fark')]),
                for (final (c, u, g, pl, k) in satirlar)
                  TableRow(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: Text('$c · $u', style: const TextStyle(fontSize: 12.5)),
                    ),
                    d(pl == null ? '—' : sayi(pl)),
                    d(g == null ? '—' : (g > 0 ? sayi(g) : 'ekili'),
                        renk: g != null && g > 0 && pl != null && !alanYakin(g, pl) ? Renk.amber : null),
                    d(k == null ? '—' : sayi(k), renk: k != null && pl != null && !alanYakin(k, pl) ? Renk.amber : null),
                    g == null || pl == null || g <= 0
                        ? d('—')
                        : alanYakin(g, pl)
                            ? d('✓', renk: Renk.yesil)
                            : d('${g - pl >= 0 ? '+' : '−'}${sayi((g - pl).abs())}', renk: Renk.amber),
                  ]),
              ],
            ),
          ),
        ),
      BolumBasligi(karsiSezon == null
          ? 'Münavebe'
          : ileri
              ? 'Münavebe (${s.sezon} → ${karsiSezon.sezon})'
              : 'Münavebe (${karsiSezon.sezon} → ${s.sezon})'),
      if (munavebe.isEmpty) const Text('Henüz giriş yok.'),
      for (final (c, p, once) in munavebe)
        () {
          // Üst üste ekilen ürünler; çok yıllık olanlar (yonca) uyarı değil, kaçıncı yılı yazılır.
          final ust = [for (final u in p.urunler) if (once.contains(urunAnahtari(u.$1))) urunAnahtari(u.$1)];
          final hata = ust.where((u) => !cokYillik(u) && !ekimDisi(u)).toList();
          final yillar = [
            for (final u in {...ust.where(cokYillik)})
              () {
                final (n, bas) = ileri ? (2, false) : ardisikYil(s, c, p.ad, u);
                return '$u: ${bas ? 'en az ' : ''}$n. yıl (çok yıllık bitki, münavebe gerekmez)';
              }(),
          ];
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: Icon(hata.isNotEmpty ? Icons.warning_amber_rounded : (yillar.isNotEmpty ? Icons.eco_outlined : Icons.check_circle_outline),
                  color: hata.isNotEmpty ? Renk.amber : Renk.yesil),
              title: Text('$c · ${p.ad}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  '${ileri ? '${p.urunYazi} → ${once.isEmpty ? 'ürün yok' : once.join(' + ')}' : '${once.isEmpty ? 'ürün yok' : once.join(' + ')} → ${p.urunYazi}'}'
                  '${hata.isNotEmpty ? '\nAynı ürün üst üste ekiliyor: ${hata.join(', ')}.' : ''}'
                  '${yillar.isEmpty ? '' : '\n${yillar.join('\n')}'}'),
            ),
          );
        }(),
    ]);
  }
}
