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
                    GonderAlani(konu: 'Tarla Haritası ${s.sezon} – ÇKS', child: _Cks(s: s, v: v)),
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
          child: AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                  painter: _HaritaCizer(cizili, {
                for (final p in cizili)
                  if (parselCks(c, p, widget.v.cks, widget.s.sezon).isNotEmpty) p.ad
              }))),
        ),
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

class _HaritaCizer extends CustomPainter {
  _HaritaCizer(this.p, this.cks);
  final List<TarlaParsel> p;
  final Set<String> cks;
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
        ..color = cks.contains(x.ad) ? Renk.mavi : Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = cks.contains(x.ad) ? 3 : 1);
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
  bool shouldRepaint(covariant _HaritaCizer old) => old.p != p || old.cks.length != cks.length;
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
            for (final x in cks)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Renk.maviAcik, borderRadius: BorderRadius.circular(6)),
                child: Text("ÇKS'de bildirildi: ${x.urun} ${_da(x.alan)}${x.adaParsel.isEmpty ? '' : ' · ${x.adaParsel}'}",
                    style: const TextStyle(fontSize: 12, color: Renk.mavi, fontWeight: FontWeight.w700)),
              ),
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

  void _git(GlobalKey k) {
    final c = k.currentContext;
    if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 350), alignment: 0.02);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s, v = widget.v;
    final k = ekimKarsilastir(s, v.ekim);
    final uyumlu = k.where((x) => x.durum == 'Uyumlu').toList();
    final fark = k.where((x) => x.durum != 'Uyumlu').toList();
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
      if (v.cks.isNotEmpty) ...[
        const SizedBox(height: 8),
        _Sayac("ÇKS ile eşleşmeyen", cksEslesmeyen.length + cksYok.length, Renk.mavi, () => _git(_kCks)),
      ],
      BolumBasligi('Tutarsızlıklar: harita ve tarım icmali', key: _kFark),
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
        for (final x in cksEslesmeyen)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
                dense: true,
                leading: const Icon(Icons.help_outline, color: Renk.mavi),
                title: Text("${x.ciftlik} · ÇKS: ${x.urun} ${_da(x.alan)}", style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${[x.mevki, x.adaParsel].where((e) => e.isNotEmpty).join(' · ')}\nHaritadaki bir parselle eşleşmedi.')),
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

/// ÇKS: belge yükleme (kamera ya da dosya) ve bildirilen parseller.
class _Cks extends StatefulWidget {
  const _Cks({required this.s, required this.v});
  final TarlaSezonu s;
  final RaporVerisi v;
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
    final l = [for (final x in widget.v.cks) if (x.sezon.isEmpty || x.sezon == widget.s.sezon) x];
    final grup = <String, List<CksParsel>>{};
    for (final x in l) {
      grup.putIfAbsent(x.ciftlik, () => []).add(x);
    }
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
      BolumBasligi("ÇKS'de bildirilen parseller (${l.length})"),
      if (l.isEmpty) const Text('Henüz işlenmiş ÇKS kaydı yok.'),
      for (final e in grup.entries) ...[
        Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w800))),
        for (final x in e.value)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: Icon(x.eslesen.isEmpty ? Icons.help_outline : Icons.check_circle_outline,
                  color: x.eslesen.isEmpty ? Renk.amber : Renk.yesil),
              title: Text('${x.urun} · ${_da(x.alan)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text([
                if (x.mevki.isNotEmpty) x.mevki,
                if (x.adaParsel.isNotEmpty) x.adaParsel,
                x.eslesen.isEmpty ? 'Haritada eşleşen parsel yok' : 'Haritada: ${x.eslesen}',
              ].join('\n')),
            ),
          ),
      ],
    ]);
  }
}
