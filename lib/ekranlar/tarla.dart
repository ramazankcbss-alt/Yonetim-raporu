import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/model.dart';
import '../veri/tarla.dart';
import 'bilesenler.dart';
import 'gonder.dart';

/// Tarla Haritası: Google Earth (KMZ) ekiliş haritası; parseller, ölçülen
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
                length: 3,
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
                    bottom: const TabBar(tabs: [Tab(text: 'Harita'), Tab(text: 'Parseller'), Tab(text: 'Karşılaştırma')]),
                  ),
                  body: TabBarView(children: [
                    GonderAlani(konu: 'Tarla Haritası ${s.sezon} – Harita', child: _Harita(s: s)),
                    GonderAlani(konu: 'Tarla Haritası ${s.sezon} – Parseller', child: _Parseller(s: s, v: v)),
                    GonderAlani(konu: 'Tarla Haritası ${s.sezon} – Karşılaştırma', child: _Karsilastirma(s: s, v: v)),
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
  const _Harita({required this.s});
  final TarlaSezonu s;
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
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AspectRatio(aspectRatio: 1, child: CustomPaint(painter: _HaritaCizer(cizili))),
        ),
      ),
      Wrap(spacing: 10, runSpacing: 4, children: [
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

class _HaritaCizer extends CustomPainter {
  _HaritaCizer(this.p);
  final List<TarlaParsel> p;
  @override
  void paint(Canvas canvas, Size size) {
    if (p.isEmpty) return;
    final tum = [for (final x in p) ...x.koord];
    final lat0 = tum.map((c) => c.$2).reduce((a, b) => a + b) / tum.length;
    final kx = math.cos(lat0 * math.pi / 180);
    final xs = tum.map((c) => c.$1 * kx), ys = tum.map((c) => c.$2);
    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max), minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    final olcek = 0.94 * math.min(size.width / (maxX - minX), size.height / (maxY - minY));
    final ox = (size.width - (maxX - minX) * olcek) / 2, oy = (size.height - (maxY - minY) * olcek) / 2;
    Offset nok((double, double) c) => Offset(ox + (c.$1 * kx - minX) * olcek, size.height - (oy + (c.$2 - minY) * olcek));
    for (final x in p) {
      final yol = Path()..addPolygon([for (final c in x.koord) nok(c)], true);
      canvas.drawPath(yol, Paint()..color = urunRengi(x).withValues(alpha: 0.55));
      canvas.drawPath(yol, Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1);
    }
    for (final x in p) {
      final pts = [for (final c in x.koord) nok(c)];
      final m = Offset(pts.map((e) => e.dx).reduce((a, b) => a + b) / pts.length, pts.map((e) => e.dy).reduce((a, b) => a + b) / pts.length);
      final etiket = RegExp(r'^\d+').stringMatch(x.ad) ?? x.ad.split(' ').first;
      final tp = TextPainter(
        text: TextSpan(text: etiket, style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 80);
      tp.paint(canvas, m - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _HaritaCizer old) => old.p != p;
}

class _Parseller extends StatelessWidget {
  const _Parseller({required this.s, required this.v});
  final TarlaSezonu s;
  final RaporVerisi v;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(12, 6, 12, 24), children: [
        for (final c in s.ciftlikler) ...[
          BolumBasligi(c.ad),
          for (final p in c.parseller) _ParselKarti(c: c, p: p, kayitlar: parselKayitlari(c, p, v.tarim)),
        ],
      ]);
}

class _ParselKarti extends StatelessWidget {
  const _ParselKarti({required this.c, required this.p, required this.kayitlar});
  final TarlaCiftlik c;
  final TarlaParsel p;
  final List<TarimKaydi> kayitlar;
  @override
  Widget build(BuildContext context) {
    final f = p.olcumFarki;
    final uyari = f != null && f.abs() > 5 && ((p.olculen ?? 0) - (p.beyan ?? 0)).abs() > 10;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 12, height: 12, color: urunRengi(p)),
            const SizedBox(width: 8),
            Expanded(child: Text(p.ad, style: const TextStyle(fontWeight: FontWeight.w800))),
            Text(_da(p.beyan), style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 2),
          Text(p.urunYazi),
          if (p.olculen != null)
            Text(
                'Haritada ölçülen: ${_da(p.olculen)}${f == null ? '' : ' (beyana göre ${f >= 0 ? '+' : ''}${sayi(f, ondalik: 1)}%)'}',
                style: TextStyle(fontSize: 12.5, color: uyari ? Renk.amber : Renk.soluk, fontWeight: uyari ? FontWeight.w700 : null)),
          if (p.not.isNotEmpty) Text(p.not, style: const TextStyle(fontSize: 12.5, color: Renk.amber)),
          if (kayitlar.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Tarım icmali (son kayıtlar):', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Renk.ana)),
            for (final k in kayitlar.take(3)) Text('${tarihKisa(k.tarih)}: ${k.faaliyet}', style: const TextStyle(fontSize: 12)),
          ],
        ]),
      ),
    );
  }
}

class _Karsilastirma extends StatelessWidget {
  const _Karsilastirma({required this.s, required this.v});
  final TarlaSezonu s;
  final RaporVerisi v;

  @override
  Widget build(BuildContext context) {
    final k = ekimKarsilastir(s, v.ekim);
    final uyumlu = k.where((x) => x.durum == 'Uyumlu').toList();
    final fark = k.where((x) => x.durum != 'Uyumlu').toList();
    final olcum = [
      for (final c in s.ciftlikler)
        for (final p in c.parseller)
          if (p.olcumFarki != null && p.olcumFarki!.abs() > 5 && ((p.olculen ?? 0) - (p.beyan ?? 0)).abs() > 10) (c, p)
    ];
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
    return ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 24), children: [
      BilgiKutusu(
          yazi: 'Harita (${s.kaynak}, ${s.sezon}) ile tarım icmalinin ekim alanları (plan / ekilen) karşılaştırılır. '
              'Tarım icmalindeki Ekim–Kasım güz ekimleri bir sonraki sezona ait olabilir; o satırlarda fark beklenir.'),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: _Sayac('Uyumlu', uyumlu.length, Renk.yesil)),
        const SizedBox(width: 8),
        Expanded(child: _Sayac('Farklı / eksik', fark.length, Renk.amber)),
        const SizedBox(width: 8),
        Expanded(child: _Sayac('Ölçüm farkı', olcum.length, Renk.kirmizi)),
      ]),
      const BolumBasligi('Tutarsızlıklar: harita ve tarım icmali'),
      if (fark.isEmpty) const Text('Fark yok.'),
      for (final x in fark)
        Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.warning_amber_rounded, color: Renk.amber),
            title: Text('${x.ciftlik} · ${x.urun}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('Harita ${_da(x.harita)} · İcmal planı ${_da(x.plan)}${x.ekilen == null ? '' : ' · ekilen ${_da(x.ekilen)}'}'
                '${x.fark == null ? '' : '\nFark: ${x.fark! >= 0 ? '+' : ''}${sayi(x.fark!)} da'} · ${x.durum}'),
            isThreeLine: x.fark != null,
          ),
        ),
      const BolumBasligi('Harita içi tutarsızlıklar'),
      for (final (c, p) in etiket)
        Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
              dense: true,
              leading: const Icon(Icons.label_important_outline, color: Renk.amber),
              title: Text('${c.ad} · ${p.ad}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(p.not)),
        ),
      for (final (c, p) in olcum)
        Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
              dense: true,
              leading: const Icon(Icons.straighten, color: Renk.kirmizi),
              title: Text('${c.ad} · ${p.ad}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Etiket ${_da(p.beyan)}, haritada ölçülen ${_da(p.olculen)} '
                  '(${p.olcumFarki! >= 0 ? '+' : ''}${sayi(p.olcumFarki!, ondalik: 1)}%)')),
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
      const BolumBasligi('Olumlu: uyumlu olanlar'),
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
    ]);
  }
}

class _Sayac extends StatelessWidget {
  const _Sayac(this.etiket, this.n, this.renk);
  final String etiket;
  final int n;
  final Color renk;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Text('$n', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: renk)),
          Text(etiket, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
        ]),
      );
}
