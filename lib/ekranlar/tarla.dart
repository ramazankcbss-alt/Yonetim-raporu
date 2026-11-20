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
          final s = l[_sezon.clamp(0, l.length - 1)];
          return ListenableBuilder(
            listenable: VeriDeposu.ben,
            builder: (context, _) {
              final v = VeriDeposu.ben.veri ?? widget.veri;
              return DefaultTabController(
                length: 4,
                child: Scaffold(
                  appBar: AppBar(
                    title: Text('Tarla Haritası ${s.sezon}'),
                    actions: [
                      if (l.length > 1)
                        PopupMenuButton<int>(
                          tooltip: 'Sezon',
                          icon: const Icon(Icons.calendar_month_outlined),
                          onSelected: (i) => setState(() => _sezon = i),
                          itemBuilder: (_) => [for (final (i, x) in l.indexed) PopupMenuItem(value: i, child: Text(x.sezon))],
                        ),
                    ],
                    bottom: const TabBar(
                        isScrollable: true,
                        tabs: [Tab(text: 'Harita'), Tab(text: 'Parseller'), Tab(text: 'Karşılaştırma'), Tab(text: 'ÇKS')]),
                  ),
                  body: TabBarView(children: [
                    GonderAlani(konu: 'Tarla Haritası ${s.sezon} – Harita', child: _Harita(s: s, v: v)),
                    GonderAlani(konu: 'Tarla Haritası ${s.sezon} – Parseller', child: _Parseller(s: s, v: v, ilk: widget.veri)),
                    GonderAlani(konu: 'Tarla Haritası ${s.sezon} – Karşılaştırma', child: _Karsilastirma(s: s, v: v)),
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
  if (p.urunler.isEmpty) return p.tip == 'bos' ? const Color(0xFFBDBDBD) : const Color(0xFF90A4AE);
  return _renkler[urunAnahtari(p.urunler.first.$1)] ?? const Color(0xFF6D8B74);
}

String _da(double? v) => v == null ? '–' : '${sayi(v)} da';

class _Harita extends StatefulWidget {
  const _Harita({required this.s, required this.v});
  final TarlaSezonu s;
  final RaporVerisi v;
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
    final toplam = c.urunToplami;
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
            child: _HaritaGorunum(p: cizili, cks: cksAdlari, maxOlcek: 6),
          ),
          Positioned(
            right: 6,
            top: 6,
            child: IconButton.filledTonal(
              tooltip: 'Tam ekran',
              icon: const Icon(Icons.fullscreen),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: Text('${c.ad} · ${widget.s.sezon}')),
                  body: _HaritaGorunum(p: cizili, cks: cksAdlari, maxOlcek: 10, yazi: 13),
                ),
              )),
            ),
          ),
        ]),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 2, bottom: 6),
        child: Text('İki parmakla yakınlaştırabilir, sağ üstteki düğmeyle tam ekran açabilirsiniz.',
            style: TextStyle(fontSize: 11.5, color: Renk.soluk)),
      ),
      Wrap(spacing: 10, runSpacing: 4, children: [
        if (widget.v.cks.isNotEmpty)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(border: Border.all(color: Renk.mavi, width: 2.5))),
            const SizedBox(width: 4),
            const Text("Mavi kenarlı: ÇKS'de bildirildi", style: TextStyle(fontSize: 12.5)),
          ]),
        for (final e in toplam.entries)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 12, height: 12, color: _renkler[e.key] ?? const Color(0xFF6D8B74)),
            const SizedBox(width: 4),
            Text('${e.key}: ${sayi(e.value)} da', style: const TextStyle(fontSize: 12.5)),
          ]),
      ]),
      const BolumBasligi('Ekiliş özeti'),
      Card(
        child: Column(children: [
          for (final e in toplam.entries)
            ListTile(dense: true, title: Text(e.key), trailing: Text(_da(e.value), style: const TextStyle(fontWeight: FontWeight.w700))),
          ListTile(
              dense: true,
              title: const Text('Toplam ekili alan', style: TextStyle(fontWeight: FontWeight.w800)),
              trailing: Text(_da(toplam.values.fold<double>(0, (a, b) => a + b)), style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
      ),
      for (final n in c.notlar) Padding(padding: const EdgeInsets.only(top: 6), child: BilgiKutusu(yazi: n)),
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
  _Geometri(List<TarlaParsel> p) {
    final tum = [for (final x in p) ...x.koord];
    final lat0 = tum.map((c) => c.$2).reduce((a, b) => a + b) / tum.length;
    final kx = math.cos(lat0 * math.pi / 180);
    for (final x in p) {
      poligon[x] = [for (final c in x.koord) (c.$1 * kx, c.$2)];
      alan[x] = _alan(poligon[x]!);
    }
    sirali = [...p]..sort((a, b) => alan[b]!.compareTo(alan[a]!));
    final xs = poligon.values.expand((e) => e).map((e) => e.$1), ys = poligon.values.expand((e) => e).map((e) => e.$2);
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
  const _HaritaGorunum({required this.p, required this.cks, this.maxOlcek = 6, this.yazi = 11.5});
  final List<TarlaParsel> p;
  final Set<String> cks;
  final double maxOlcek, yazi;
  @override
  State<_HaritaGorunum> createState() => _HaritaGorunumState();
}

class _HaritaGorunumState extends State<_HaritaGorunum> {
  final _ctl = TransformationController();
  late _Geometri _g = _Geometri(widget.p);

  @override
  void didUpdateWidget(covariant _HaritaGorunum old) {
    super.didUpdateWidget(old);
    if (old.p != widget.p) {
      _g = _Geometri(widget.p);
      _ctl.value = Matrix4.identity();
    }
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
            child: CustomPaint(size: Size.infinite, painter: _PoligonCizer(_g, widget.cks)),
          ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _ctl,
              builder: (_, __) => CustomPaint(size: Size.infinite, painter: _YaziCizer(_g, _ctl.value.clone(), widget.yazi)),
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
  }

  @override
  bool shouldRepaint(covariant _PoligonCizer old) => old.g != g || old.cks.length != cks.length;
}

class _YaziCizer extends CustomPainter {
  _YaziCizer(this.g, this.m, this.yazi);
  final _Geometri g;
  final Matrix4 m;
  final double yazi;

  @override
  void paint(Canvas canvas, Size size) {
    final d = g.donusum(size);
    final dolu = <Rect>[];
    for (final x in g.sirali) {
      final n = MatrixUtils.transformPoint(m, d(g.yaziNoktasi[x]!));
      final tp = TextPainter(
        text: TextSpan(children: [
          TextSpan(text: x.ad, style: TextStyle(fontSize: yazi, color: Colors.black, fontWeight: FontWeight.w800)),
          for (final u in x.urunler)
            TextSpan(
                text: '\n${_kisaUrun(u.$1)} ${sayi(u.$2)} da',
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
  bool shouldRepaint(covariant _YaziCizer old) => old.m != m || old.g != g;
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
              subtitle: Text('${c.parseller.length} parsel · ${sayi(c.urunToplami.values.fold<double>(0, (a, b) => a + b))} da ekili'
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
        Text(_da(p.beyan), style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 2),
      Text(p.urunYazi),
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

  Future<void> _geriAl(BuildContext context, EkimKarsilastirma x) async {
    try {
      final m = await VeriDeposu.ben.ekimDuzelt(sezon: widget.s.sezon, ciftlik: x.ciftlik, urun: x.urun, geriAl: true);
      if (context.mounted) bildir(context, m);
    } catch (e) {
      if (context.mounted) bildir(context, '$e');
    }
  }

  Future<void> _duzelt(BuildContext context, EkimKarsilastirma x) async {
    final sonuc = await showDialog<(String, double, String)>(context: context, builder: (_) => _DuzeltDiyalog(x: x));
    if (sonuc == null || !context.mounted) return;
    try {
      final m = await VeriDeposu.ben.ekimDuzelt(
          sezon: widget.s.sezon, ciftlik: x.ciftlik, urun: x.urun, secim: sonuc.$1, deger: sonuc.$2, aciklama: sonuc.$3);
      if (context.mounted) bildir(context, m);
    } catch (e) {
      if (context.mounted) bildir(context, '$e');
    }
  }

  void _git(GlobalKey k) {
    final c = k.currentContext;
    if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 350), alignment: 0.02);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s, v = widget.v;
    final k = ekimKarsilastir(s, v.ekim);
    final uyumlu = k.where((x) => x.durum == 'Uyumlu').toList();
    final farkTum = k.where((x) => x.durum != 'Uyumlu').toList();
    final duzeltilen = [
      for (final x in farkTum)
        if (aktifDuzeltme(v.ekimDuzeltme, s.sezon, x.ciftlik, x.urun) case final d?) (x, d)
    ];
    final fark = [for (final x in farkTum) if (aktifDuzeltme(v.ekimDuzeltme, s.sezon, x.ciftlik, x.urun) == null) x];
    final etiket = [for (final c in s.ciftlikler) for (final p in c.parseller) if (p.not.contains('yazıyor')) (c, p)];
    final hasat = <(HasatSatir, double)>[];
    for (final h in v.hasat) {
      if ((h.alan ?? 0) <= 0 || h.toplam == null) continue;
      for (final c in s.ciftlikler) {
        if (ciftlikAnahtari(c.ad) != ciftlikAnahtari(h.ciftlik)) continue;
        final a = c.urunToplami[urunAnahtari(h.urun)];
        if (a != null && (a - h.alan!).abs() > 10) hasat.add((h, a));
      }
    }
    final cksEslesmeyen = [
      for (final x in v.cks)
        if ((x.sezon.isEmpty || x.sezon == s.sezon) &&
            !s.ciftlikler.any((c) => c.parseller.any((p) => parselCks(c, p, [x], s.sezon).isNotEmpty)))
          x
    ];
    final resmi = resmiKarsilastir(s, v.resmiParsel);
    final yillar = planYillari(v.ekimPlani);
    final cksYok = [
      for (final c in s.ciftlikler)
        for (final p in c.parseller)
          if (p.urunler.isNotEmpty && p.tip != 'diger' && parselCks(c, p, v.cks, s.sezon).isEmpty) (c, p)
    ];
    return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BilgiKutusu(
          yazi: 'Harita (${s.kaynak}, ${s.sezon}) ile tarım icmalinin ekim alanları (plan / ekilen) karşılaştırılır. '
              'Tarım icmalindeki Ekim–Kasım güz ekimleri bir sonraki sezona ait olabilir; o satırlarda fark beklenir.'),
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
        _Sayac("ÇKS ile eşleşmeyen", cksEslesmeyen.length + cksYok.length, Renk.mavi, () => _git(_kCks)),
      ],
      const BolumBasligi('Kaynaklara göre ekim alanları (da)'),
      _KaynakTablosu(satirlar: kaynakTablosu(s, v.ekim, v.cks)),
      BolumBasligi('Tutarsızlıklar: harita ve tarım icmali', key: _kFark),
      if (fark.isEmpty) const Text('Fark yok.'),
      for (final x in fark)
        Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ListTile(
                dense: true,
                leading: const Icon(Icons.warning_amber_rounded, color: Renk.amber),
                title: Text('${x.ciftlik} · ${x.urun}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Harita ${_da(x.harita)} · İcmal planı ${_da(x.plan)} · ÇKS ${_da(cksToplami(v.cks, s.sezon, x.ciftlik, x.urun))}'
                    '${x.ekilen == null ? '' : ' · ekilen ${_da(x.ekilen)}'}'
                    '${x.fark == null ? '' : '\nFark: ${x.fark! >= 0 ? '+' : ''}${sayi(x.fark!)} da'} · ${x.durum}'),
                isThreeLine: x.fark != null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: Key('duzelt_${x.ciftlik}_${x.urun}'),
                  onPressed: () => _duzelt(context, x),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Düzelt'),
                ),
              ),
            ]),
          ),
        ),
      if (duzeltilen.isNotEmpty) ...[
        const BolumBasligi('Düzeltilenler'),
        for (final (x, d) in duzeltilen)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.task_alt, color: Renk.yesil),
              title: Text('${x.ciftlik} · ${x.urun}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Düzeltildi: ${d.secim} · ${_da(d.deger)}'
                  '${d.aciklama.isEmpty ? '' : '\n${d.aciklama}'}'
                  '\nKaynakta: harita ${_da(x.harita)} · icmal planı ${_da(x.plan)}${d.tarih.isEmpty ? '' : ' · ${d.tarih}'}'),
              isThreeLine: true,
              trailing: TextButton(onPressed: () => _geriAl(context, x), child: const Text('Geri al')),
            ),
          ),
      ],
      BolumBasligi('Haritadaki etiket tutarsızlıkları', key: _kOlcum),
      for (final (c, p) in etiket)
        Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
              dense: true,
              leading: const Icon(Icons.label_important_outline, color: Renk.amber),
              title: Text('${c.ad} · ${p.ad}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(p.not)),
        ),
      for (final c in s.ciftlikler)
        for (final n in c.notlar.where((n) => n.contains('uyuşmuyor')))
          Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(dense: true, title: Text(c.ad), subtitle: Text(n))),
      if (hasat.isNotEmpty) ...[
        const BolumBasligi('Hasat ve verim (haritadaki alanla)'),
        for (final (h, a) in hasat)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              title: Text('${h.ciftlik} · ${h.urun}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Hasat kaydında alan ${_da(h.alan)}, verim ${sayi(h.toplam! / h.alan!)} kg/da. '
                  'Haritadaki alan ${_da(a)} esas alınırsa verim ${sayi(h.toplam! / a)} kg/da.'),
            ),
          ),
      ],
      if (v.cks.isNotEmpty) ...[
        BolumBasligi('ÇKS ile harita', key: _kCks),
        for (final (c, u, k, h) in cksUrunKarsilastir(s, v.cks))
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: Icon(_yakin(k, h) ? Icons.check_circle_outline : Icons.compare_arrows,
                  color: _yakin(k, h) ? Renk.yesil : Renk.amber),
              title: Text('$c · $u', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('ÇKS: ${_da(k)} · Harita: ${_da(h)}'
                  '${_yakin(k, h) ? '' : ' · Fark: ${h - k >= 0 ? '+' : ''}${sayi(h - k)} da'}'),
            ),
          ),
        for (final x in cksEslesmeyen)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
                dense: true,
                leading: const Icon(Icons.help_outline, color: Renk.mavi),
                title: Text("${x.ciftlik} · ÇKS: ${x.urun} ${_da(x.alan)}", style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${[x.mevki, x.adaParsel].where((e) => e.isNotEmpty).join(' · ')}\nHaritada bu ürün için parsel yok.')),
          ),
        for (final (c, p) in cksYok)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
                dense: true,
                leading: const Icon(Icons.report_outlined, color: Renk.mavi),
                title: Text('${c.ad} · ${p.ad}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text("${p.urunYazi}: haritada ekili, ÇKS'de bildirimi görünmüyor.")),
          ),
        if (cksEslesmeyen.isEmpty && cksYok.isEmpty) const Text("Tüm parseller ÇKS'de bildirilmiş."),
      ],
      if (resmi.isNotEmpty) ...[
        const BolumBasligi('Resmî parsel kayıtları ile harita'),
        const Text('Kaynak: 2026-2027 Tarımsal Faaliyet › PARSEL', style: TextStyle(fontSize: 11.5, color: Renk.soluk)),
        for (final (c, u, r, h) in resmi)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: Icon(_yakin(r, h) ? Icons.check_circle_outline : Icons.compare_arrows,
                  color: _yakin(r, h) ? Renk.yesil : Renk.amber),
              title: Text('$c · $u', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Resmî kayıt: ${_da(r)} · Harita: ${_da(h)}'
                  '${_yakin(r, h) ? '' : ' · Fark: ${h - r >= 0 ? '+' : ''}${sayi(h - r)} da'}'),
            ),
          ),
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
      for (final x in uyumlu)
        Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.check_circle_outline, color: Renk.yesil),
            title: Text('${x.ciftlik} · ${x.urun}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('Harita ${_da(x.harita)} · İcmal planı ${_da(x.plan)}'),
          ),
        ),
    ]));
  }
}

class _DuzeltDiyalog extends StatefulWidget {
  const _DuzeltDiyalog({required this.x});
  final EkimKarsilastirma x;
  @override
  State<_DuzeltDiyalog> createState() => _DuzeltDiyalogState();
}

class _DuzeltDiyalogState extends State<_DuzeltDiyalog> {
  String _secim = 'Harita doğru';
  final _deger = TextEditingController(), _aciklama = TextEditingController();

  @override
  void dispose() {
    _deger.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  double? get _sonDeger => switch (_secim) {
        'Harita doğru' => widget.x.harita,
        'Plan doğru' => widget.x.plan,
        _ => double.tryParse(_deger.text.trim().replaceAll('.', '').replaceAll(',', '.')),
      };

  @override
  Widget build(BuildContext context) {
    final x = widget.x;
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
      title: Text('${x.ciftlik} · ${x.urun}'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Kaynak dosyalar değişmez; düzeltme rapor tablosuna kaydedilir ve istediğiniz zaman geri alınabilir.',
              style: TextStyle(fontSize: 12.5, color: Renk.soluk)),
          secenek('Harita doğru', _da(x.harita)),
          if (x.plan != null) secenek('Plan doğru', _da(x.plan)),
          secenek('Doğru değer', ''),
          if (_secim == 'Doğru değer')
            TextField(
              controller: _deger,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Doğru alan (da)'),
              onChanged: (_) => setState(() {}),
            ),
          TextField(
            controller: _aciklama,
            maxLength: 300,
            decoration: const InputDecoration(labelText: 'Açıklama (isteğe bağlı)', hintText: 'Örn. 30 da pancar 5. pivota kaydırıldı'),
          ),
          const Text('KVKK: açıklamaya kişi adı yazmayın.', style: TextStyle(fontSize: 11.5, color: Renk.soluk)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: _sonDeger == null ? null : () => Navigator.pop(context, (_secim, _sonDeger!, _aciklama.text.trim())),
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

/// Harita / icmal planı / ÇKS tablosu; diğerlerinden sapan değer turuncu.
class _KaynakTablosu extends StatelessWidget {
  const _KaynakTablosu({required this.satirlar});
  final List<KaynakSatiri> satirlar;

  @override
  Widget build(BuildContext context) {
    Widget h(String t, {TextAlign a = TextAlign.right}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(t, textAlign: a, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)));
    Widget d(double? x, bool sapan) => Container(
          color: sapan ? Renk.amber.withValues(alpha: 0.18) : null,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(x == null ? '—' : sayi(x),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12.5, fontWeight: sapan ? FontWeight.w800 : null, color: sapan ? Renk.amber : null)),
        );
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Table(
            columnWidths: const {0: FlexColumnWidth(2.4), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1)},
            border: TableBorder(horizontalInside: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
            children: [
              TableRow(children: [h('Çiftlik · Ürün', a: TextAlign.left), h('Harita'), h('İcmal'), h('ÇKS')]),
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
                  d(r.harita, r.sapan.contains(0)),
                  d(r.plan, r.sapan.contains(1)),
                  d(r.cks, r.sapan.contains(2)),
                ]),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Turuncu: diğer kaynaklardan sapan değer. ✓: kaynaklar uyumlu. —: o kaynakta kayıt yok.',
              style: TextStyle(fontSize: 11.5, color: Renk.soluk)),
        ]),
      ),
    );
  }
}

bool _yakin(double a, double b) => (a - b).abs() <= 10 || (a > 0 && (a - b).abs() / a <= 0.03);

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
