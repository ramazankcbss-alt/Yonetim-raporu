import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/model.dart';
import '../veri/tarla.dart';
import 'bilesenler.dart';
import 'gonder.dart';

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
  int _sezon = 0;

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
          // Paketlenmiş sezonlar + haritadan girilen yeni sezon.
          List<TarlaSezonu> tum(RaporVerisi v) => [...l, girisSezonu(l.first, v.sezonParsel)];
          return ListenableBuilder(
            listenable: VeriDeposu.ben,
            builder: (context, _) {
              final v = VeriDeposu.ben.veri ?? widget.veri;
              final hepsi = tum(v);
              final i = _sezon.clamp(0, hepsi.length - 1);
              final s = hepsi[i];
              TarlaSezonu sezonBul(RaporVerisi v) => tum(v)[i];
              return DefaultTabController(
                length: 4,
                child: Scaffold(
                  appBar: AppBar(
                    title: Text('Tarla Haritası ${s.sezon}'),
                    actions: [
                      PopupMenuButton<int>(
                        tooltip: 'Sezon',
                        icon: const Icon(Icons.calendar_month_outlined),
                        onSelected: (i) => setState(() => _sezon = i),
                        itemBuilder: (_) => [
                          for (final (i, x) in hepsi.indexed)
                            PopupMenuItem(value: i, child: Text(x.giris ? '${x.sezon} (haritadan giriş)' : x.sezon)),
                        ],
                      ),
                    ],
                    bottom: const TabBar(
                        isScrollable: true,
                        tabs: [Tab(text: 'Harita'), Tab(text: 'Parseller'), Tab(text: 'Karşılaştırma'), Tab(text: 'ÇKS')]),
                  ),
                  body: TabBarView(children: [
                    GonderAlani(konu: 'Tarla Haritası ${s.sezon} – Harita', child: _Harita(s: s, v: v, sezonBul: sezonBul, sezonSec: () => setState(() => _sezon = hepsi.length - 1))),
                    GonderAlani(konu: 'Tarla Haritası ${s.sezon} – Parseller', child: _Parseller(s: s, v: v, ilk: widget.veri)),
                    GonderAlani(konu: 'Tarla Haritası ${s.sezon} – Karşılaştırma', child: s.giris ? _GirisKarsilastirma(s: s, v: v) : _Karsilastirma(s: s, v: v)),
                    GonderAlani(konu: 'Tarla Haritası ${s.sezon} – ÇKS', child: _Cks(s: s, v: v, ilk: widget.veri)),
                  ]),
                ),
              );
            },
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
};
Color urunRengi(TarlaParsel p) {
  if (p.urunler.isEmpty) return p.tip == 'bos' || p.girilmedi ? const Color(0xFFD6D6D6) : const Color(0xFF90A4AE);
  return _renkler[urunAnahtari(p.urunler.first.$1)] ?? const Color(0xFF6D8B74);
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
  Widget build(BuildContext context) {
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
    final plan = giris ? yilPlani(widget.v.ekimPlani, widget.s.uretimYili, c.ad) : const <String, double>{};
    final cinsler = c.urunCinsleri;
    final urunler = [...excel.keys, ...cinsler.where((u) => !excel.containsKey(u)), ...plan.keys.where((u) => !excel.containsKey(u) && !cinsler.contains(u))];
    final toplam = excel.values.fold<double>(0, (a, b) => a + b);
    final girilmeyen = cizili.where((p) => p.girilmedi).length;
    void dokun(TarlaParsel p) => _parselIslem(context, widget.s, c, p);
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
            child: _HaritaGorunum(p: cizili, g: c.gorseller, cks: cksAdlari, maxOlcek: 6, dekar: giris, onDokun: dokun),
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
                          dekar: s2.giris,
                          onDokun: (p) => _parselIslem(context, s2, c2, p)),
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
            'İki parmakla yakınlaştırabilir, sağ üstteki düğmeyle tam ekran açabilirsiniz.',
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
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 12, height: 12, color: _renkler[u] ?? const Color(0xFF6D8B74)),
            const SizedBox(width: 4),
            Text('$u: ${excel[u] == null ? (giris ? 'girilmedi' : "Excel'de yok") : _da(excel[u])}', style: const TextStyle(fontSize: 12.5)),
          ]),
      ]),
      const BolumBasligi('Ekiliş özeti'),
      Text(
          giris
              ? 'Alanlar: haritadan girilen bilgiler. Karşısında ${widget.s.uretimYili} Excel ekim planı gösterilir.'
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
                    ? Text('${widget.s.uretimYili} Excel planı: ${plan[u] == null ? 'yok' : _da(plan[u])}',
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

/// Haritanın düzlem geometrisi ve her parselin yazı noktası (üstteki
/// küçük parsellerin dışında, kenarlardan en uzak iç nokta).
class _Geometri {
  _Geometri(List<TarlaParsel> p, [List<TarlaGorsel> g = const []]) {
    final tum = [for (final x in p) ...x.koord];
    final lat0 = tum.map((c) => c.$2).reduce((a, b) => a + b) / tum.length;
    final kx = math.cos(lat0 * math.pi / 180);
    for (final x in p) {
      poligon[x] = [for (final c in x.koord) (c.$1 * kx, c.$2)];
      alan[x] = _alan(poligon[x]!);
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
  final yaziNoktasi = <TarlaParsel, _N>{};

  /// KMZ görselleri (kuyu, direk, hatlar) düzlem koordinatında.
  late final List<(TarlaGorsel, List<_N>)> gorsel;
  late final List<TarlaParsel> sirali;
  late final double minX, maxX, minY, maxY;

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
  const _HaritaGorunum({required this.p, this.g = const [], required this.cks, this.maxOlcek = 6, this.yazi = 11.5, this.dekar = false, this.onDokun});
  final List<TarlaParsel> p;
  final List<TarlaGorsel> g;
  final Set<String> cks;
  final double maxOlcek, yazi;

  /// Etikette alan da yazılsın mı (yalnızca haritadan girilen yeni sezonda).
  final bool dekar;
  final void Function(TarlaParsel)? onDokun;
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
      if (!ayniCizim) _ctl.value = Matrix4.identity();
    }
  }

  /// Dokunulan noktadaki en küçük parsel.
  TarlaParsel? _bul(Offset n, Size size) {
    final d = _g.donusum(size);
    for (final x in _g.sirali.reversed) {
      final yol = Path()..addPolygon([for (final c in _g.poligon[x]!) d(c)], true);
      if (yol.contains(n)) return x;
    }
    return null;
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
        child: Stack(fit: StackFit.expand, children: [
          InteractiveViewer(
            transformationController: _ctl,
            maxScale: widget.maxOlcek,
            child: LayoutBuilder(
              builder: (context, k) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: widget.onDokun == null
                    ? null
                    : (e) {
                        final x = _bul(e.localPosition, k.biggest);
                        if (x != null) widget.onDokun!(x);
                      },
                child: CustomPaint(size: Size.infinite, painter: _PoligonCizer(_g, widget.cks)),
              ),
            ),
          ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _ctl,
              builder: (_, __) =>
                  CustomPaint(size: Size.infinite, painter: _YaziCizer(_g, _ctl.value.clone(), widget.yazi, widget.dekar)),
            ),
          ),
        ]),
      );
}

class _PoligonCizer extends CustomPainter {
  _PoligonCizer(this.g, this.cks);
  final _Geometri g;
  final Set<String> cks;
  @override
  void paint(Canvas canvas, Size size) {
    final d = g.donusum(size);
    for (final x in g.sirali) {
      final yol = Path()..addPolygon([for (final c in g.poligon[x]!) d(c)], true);
      canvas.drawPath(yol, Paint()..color = urunRengi(x).withValues(alpha: 0.6));
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
      final tp = TextPainter(
        text: TextSpan(children: [
          TextSpan(text: x.ad, style: TextStyle(fontSize: yazi, color: Colors.black, fontWeight: FontWeight.w800)),
          if (x.girilmedi)
            TextSpan(text: '\nGirilmedi', style: TextStyle(fontSize: yazi * 0.85, color: Colors.black54)),
          for (final kisa in {
            for (final u in x.urunler) dekar && u.$2 > 0 ? '${_kisaUrun(u.$1)} ${sayi(u.$2)} da' : _kisaUrun(u.$1)
          })
            TextSpan(
                text: '\n$kisa',
                style: TextStyle(fontSize: yazi * 0.92, color: Colors.black87, fontWeight: FontWeight.w600)),
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
    final l = widget.v.cks;
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
      Row(children: [
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
      BolumBasligi("ÇKS'de bildirilen parseller (${l.length} kayıt)"),
      if (l.isEmpty) const Text('Henüz işlenmiş ÇKS kaydı yok.'),
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
Future<void> _parselIslem(BuildContext context, TarlaSezonu s, TarlaCiftlik c, TarlaParsel p) async {
  if (p.tip == 'diger') {
    bildir(context, '${p.ad}: ekim alanı değil, ürün girilemez.');
    return;
  }
  final hedef = s.giris ? s.sezon : sonrakiSezon(s.sezon);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => ListenableBuilder(
      listenable: VeriDeposu.ben,
      builder: (context, _) {
        final v = VeriDeposu.ben.veri;
        final g = v == null ? null : parselGirisi(v.sezonParsel, hedef, c.ad, p.ad);
        final once = s.giris ? oncekiUrunler(s, c.ad, p.ad) : [for (final u in p.urunler) urunAnahtari(u.$1)];
        final onceSezon = s.giris ? s.onceki!.sezon : s.sezon;
        final ayni = g != null && once.contains(urunAnahtari(g.urun));
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('${c.ad} · ${p.ad}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('$onceSezon: ${once.isEmpty ? 'ürün yok' : once.join(' + ')}', style: const TextStyle(color: Renk.soluk)),
              Text('$hedef: ${g == null ? 'girilmedi' : '${g.urun}${g.alan == null ? '' : ' · ${_da(g.alan)}'}'}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              if (ayni)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Münavebe uyarısı: aynı ürün bu parselde üst üste ekiliyor.',
                      style: TextStyle(color: Renk.amber, fontSize: 12.5)),
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
                  final urun = g?.urun ?? (once.length == 1 ? once.first : null);
                  if (urun == null) {
                    bildir(context, 'Önce "Ürün değiştir" ile ürünü seçin.');
                    return;
                  }
                  final a = await showDialog<double>(context: context, builder: (_) => _DekarGir(deger: g?.alan, urun: urun));
                  if (a == null || !context.mounted) return;
                  await _kaydet(context, hedef, c, p, urun, a);
                },
                icon: const Icon(Icons.straighten),
                label: const Text('Dekar değiştir'),
              ),
              if (g != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      final m = await VeriDeposu.ben.sezonParselKaydet(sezon: hedef, ciftlik: c.ad, parsel: p.ad, geriAl: true);
                      if (context.mounted) bildir(context, m);
                    } catch (e) {
                      if (context.mounted) bildir(context, '$e');
                    }
                  },
                  icon: const Icon(Icons.undo),
                  label: const Text('Girişi geri al'),
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
    final x = double.tryParse(_t.text.trim().replaceAll('.', '').replaceAll(',', '.'));
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

/// Yeni sezon karşılaştırması: girilen alanlar ile Excel ekim planı ve münavebe.
class _GirisKarsilastirma extends StatelessWidget {
  const _GirisKarsilastirma({required this.s, required this.v});
  final TarlaSezonu s;
  final RaporVerisi v;

  @override
  Widget build(BuildContext context) {
    final yil = s.uretimYili;
    final planVar = v.ekimPlani.any((x) => x.yil == yil);
    final satirlar = <(String, String, double?, double?)>[];
    for (final c in s.ciftlikler) {
      final g = c.urunToplami, pl = yilPlani(v.ekimPlani, yil, c.ad);
      for (final u in {...g.keys, ...pl.keys}) {
        satirlar.add((c.ad, u, g[u], pl[u]));
      }
    }
    final munavebe = <(String, TarlaParsel, List<String>)>[];
    var girilmeyen = 0;
    for (final c in s.ciftlikler) {
      for (final p in c.parseller) {
        if (p.girilmedi) girilmeyen++;
        if (p.urunler.isEmpty) continue;
        munavebe.add((c.ad, p, oncekiUrunler(s, c.ad, p.ad)));
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
              'Girilen alanlar $yil Excel ekim planıyla karşılaştırılır.'
              '${planVar ? '' : ' Ekim planı dosyasında henüz $yil yılı yok; plan girildiğinde burada görünür.'}'),
      if (girilmeyen > 0)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Ürün girilmemiş parsel: $girilmeyen', style: const TextStyle(color: Renk.amber, fontSize: 12.5)),
        ),
      const BolumBasligi('Girilen alanlar ve Excel planı (da)'),
      if (satirlar.isEmpty)
        const Text('Henüz giriş yok. Harita sekmesinde bir parsele dokunun.')
      else
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Table(
              columnWidths: const {0: FlexColumnWidth(2.4), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1)},
              border: TableBorder(horizontalInside: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
              children: [
                TableRow(children: [h('Çiftlik · Ürün', a: TextAlign.left), h('Girilen'), h('$yil planı'), h('Fark')]),
                for (final (c, u, g, pl) in satirlar)
                  TableRow(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: Text('$c · $u', style: const TextStyle(fontSize: 12.5)),
                    ),
                    d(g == null ? '—' : sayi(g)),
                    d(pl == null ? '—' : sayi(pl)),
                    g == null || pl == null
                        ? d('—')
                        : alanYakin(g, pl)
                            ? d('✓', renk: Renk.yesil)
                            : d('${g - pl >= 0 ? '+' : '−'}${sayi((g - pl).abs())}', renk: Renk.amber),
                  ]),
              ],
            ),
          ),
        ),
      const BolumBasligi('Münavebe (önceki sezon → yeni sezon)'),
      if (munavebe.isEmpty) const Text('Henüz giriş yok.'),
      for (final (c, p, once) in munavebe)
        Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            leading: Icon(once.contains(urunAnahtari(p.urunler.first.$1)) ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                color: once.contains(urunAnahtari(p.urunler.first.$1)) ? Renk.amber : Renk.yesil),
            title: Text('$c · ${p.ad}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${once.isEmpty ? 'ürün yok' : once.join(' + ')} → ${p.urunYazi}'
                '${once.contains(urunAnahtari(p.urunler.first.$1)) ? '\nAynı ürün üst üste ekiliyor.' : ''}'),
          ),
        ),
    ]);
  }
}
