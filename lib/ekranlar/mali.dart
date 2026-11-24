import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesenler.dart';
import 'gonder.dart';
import 'esk.dart' show tl;

/// Mali Raporlar: çiftliklerin gelen faturaları günlük, haftalık, aylık ve
/// yıllık; açık bakiyeler; dosyalar arası karşılaştırma ve tutarsızlıklar.
class MaliEkran extends StatelessWidget {
  const MaliEkran({super.key, required this.veri});

  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VeriDeposu.ben,
      builder: (context, _) {
        final m = (VeriDeposu.ben.veri ?? veri).mali;
        final acikVar = m.acik.isNotEmpty;
        return DefaultTabController(
          length: acikVar ? 6 : 5,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Mali Raporlar'),
              actions: const [TabloGuncelleButonu()],
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xCCFFFFFF),
                indicatorColor: Colors.white,
                tabs: [
                  const Tab(text: 'Günlük'),
                  const Tab(text: 'Haftalık'),
                  const Tab(text: 'Aylık'),
                  const Tab(text: 'Yıllık'),
                  if (acikVar) const Tab(text: 'Açık bakiyeler'),
                  const Tab(text: 'Karşılaştırma'),
                ],
              ),
            ),
            body: m.bos
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: BilgiKutusu(
                        yazi: "Mali veri henüz gelmedi. Drive'daki 'Mali Raporlar' klasöründe "
                            'mali_veri.json olmalı ve Apps Script güncel olmalı.'),
                  )
                : TabBarView(children: [
                    GonderAlani(konu: 'Mali Raporlar – Günlük', child: _Donem(veri: m, donem: MaliDonem.gun)),
                    GonderAlani(konu: 'Mali Raporlar – Haftalık', child: _Donem(veri: m, donem: MaliDonem.hafta)),
                    GonderAlani(konu: 'Mali Raporlar – Aylık', child: _Donem(veri: m, donem: MaliDonem.ay)),
                    GonderAlani(konu: 'Mali Raporlar – Yıllık', child: _Donem(veri: m, donem: MaliDonem.yil)),
                    if (acikVar) GonderAlani(konu: 'Mali Raporlar – Açık bakiyeler', child: _Acik(veri: m)),
                    GonderAlani(konu: 'Mali Raporlar – Karşılaştırma', child: _Karsilastirma(veri: m)),
                  ]),
          ),
        );
      },
    );
  }
}

String _donemAdi(DateTime b, MaliDonem d) => switch (d) {
      MaliDonem.gun => tarihUzun(b),
      MaliDonem.hafta => haftaEtiketi(b),
      MaliDonem.ay => '${const ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'][b.month - 1]} ${b.year}',
      MaliDonem.yil => '${b.year}',
    };

String _kisaAd(DateTime b, MaliDonem d) => switch (d) {
      MaliDonem.gun => gunAy(b),
      MaliDonem.hafta => '${isoHafta(b)}. hf',
      MaliDonem.ay => '${const ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'][b.month - 1]} ${b.year % 100}',
      MaliDonem.yil => '${b.year}',
    };

class _Donem extends StatefulWidget {
  const _Donem({required this.veri, required this.donem});
  final MaliVeri veri;
  final MaliDonem donem;

  @override
  State<_Donem> createState() => _DonemState();
}

class _DonemState extends State<_Donem> {
  DateTime? _secili;

  @override
  Widget build(BuildContext context) {
    final donemler = maliDonemler(widget.veri.faturalar, widget.donem);
    if (donemler.isEmpty) return const Center(child: Text('Fatura yok'));
    final sec = donemler.firstWhere((e) => e.key == _secili, orElse: () => donemler.first);
    final o = MaliOzet(sec.value);
    final enCok = donemler.map((e) => MaliOzet(e.value).toplam).reduce((a, b) => a > b ? a : b);
    final d = widget.donem;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
      children: [
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final e in donemler.take(d == MaliDonem.gun ? 60 : 53))
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(_kisaAd(e.key, d)),
                  selected: e.key == sec.key,
                  onSelected: (_) => setState(() => _secili = e.key),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        Text(_donemAdi(sec.key, d), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          _Kutu(widget.veri.kdv.isEmpty ? 'Toplam fatura' : 'Toplam fatura (KDV ${widget.veri.kdv})', tl(o.toplam), '${o.faturalar.length} fatura', Renk.ana),
          if (o.doviz.isNotEmpty) ...[
            const SizedBox(width: 8),
            _Kutu('Döviz faturaları', o.doviz.entries.map((e) => para(e.value, e.key)).join('\n'), 'TL toplamına dahil değil',
                Renk.mavi),
          ],
          if (widget.veri.odemeVar) ...[
            const SizedBox(width: 8),
            _Kutu('Ödenen', tl(o.odenen), '', Renk.yesil),
            const SizedBox(width: 8),
            _Kutu('Ödenmemiş', tl(o.acik), '', o.acik > 0 ? Renk.amber : Renk.soluk),
          ],
        ]),
        if (d != MaliDonem.gun) ...[
          const BolumBasligi('Dönemler'),
          _Cubuklar(
            satirlar: [
              for (final e in donemler.take(d == MaliDonem.yil ? 10 : 12))
                MapEntry(_kisaAd(e.key, d), MaliOzet(e.value).toplam)
            ],
            enCok: enCok,
            vurgu: _kisaAd(sec.key, d),
          ),
        ],
        if (d == MaliDonem.yil) ...[
          const BolumBasligi('Aylara göre'),
          Builder(builder: (_) {
            final aylar = maliDonemler(sec.value, MaliDonem.ay);
            final m = aylar.isEmpty ? 0.0 : aylar.map((e) => MaliOzet(e.value).toplam).reduce((a, b) => a > b ? a : b);
            return _Cubuklar(
                satirlar: [for (final e in aylar.reversed) MapEntry(_kisaAd(e.key, MaliDonem.ay), MaliOzet(e.value).toplam)],
                enCok: m);
          }),
        ],
        const BolumBasligi('Kategoriye göre'),
        _Cubuklar(satirlar: o.grupla((f) => f.kategori), enCok: o.toplam),
        const BolumBasligi('Tedarikçi grubu'),
        _Cubuklar(satirlar: o.grupla((f) => f.hesap), enCok: o.toplam),
        const BolumBasligi('Kayıt kontrolü'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 12, runSpacing: 6, children: [
              for (final e in o.kontrolSayilari().entries)
                Text('${e.key}: ${e.value}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: e.key == 'Raporla uyumlu' || e.key == 'Uyumlu' ? Renk.yesil : Renk.amber)),
            ]),
          ),
        ),
        if (d == MaliDonem.gun || o.faturalar.length <= 40) ...[
          const BolumBasligi('Faturalar'),
          for (final f in ([...o.faturalar]..sort((a, b) => b.tutar.compareTo(a.tutar))))
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                title: Text(f.kategori, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${f.tedarikci}\n${tarihKisa(f.tarih)}'
                    '${f.durum.isEmpty ? '' : ' · ${f.durum}'}'
                    '${f.vade != null ? ' · vade ${tarihKisa(f.vade!)}' : ''}'
                    '${f.kontrol == 'Raporla uyumlu' || f.kontrol == 'Uyumlu' ? '' : ' · ${f.kontrol}'}'
                    '${f.sapYer.isEmpty ? '' : '\nSAP listesi: ${f.sapYer}'}'
                    '${f.gelenYer.isEmpty ? '' : '\nAyrıntılı rapor: ${f.gelenYer}'}'),
                isThreeLine: true,
                trailing: Text(para(f.tutar, f.paraBirimi),
                    style: TextStyle(fontWeight: FontWeight.w700, color: f.acik ? Renk.amber : Renk.yazi)),
              ),
            ),
        ],
        const SizedBox(height: 8),
        Text('${widget.veri.kdv.isEmpty ? 'Tutarlar dosyadaki TOPLAM TUTAR (L sütunu) olarak, KDV ayrımı yapılmadan' : 'Tutarlar KDV ${widget.veri.kdv}'} TL; döviz faturaları kendi para biriminde ayrıca gösterilir · kaynak: ${widget.veri.kaynak}. Şahıs işletmesi tedarikçilerin adları KVKK gereği gösterilmez.',
            style: const TextStyle(fontSize: 11.5, color: Renk.soluk)),
      ],
    );
  }
}

class _Kutu extends StatelessWidget {
  const _Kutu(this.ad, this.deger, this.alt, this.renk);
  final String ad, deger, alt;
  final Color renk;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: renk.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ad, style: const TextStyle(fontSize: 12, color: Renk.soluk)),
            Text(deger, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: renk)),
            if (alt.isNotEmpty) Text(alt, style: const TextStyle(fontSize: 11.5, color: Renk.soluk)),
          ]),
        ),
      );
}

class _Cubuklar extends StatelessWidget {
  const _Cubuklar({required this.satirlar, required this.enCok, this.vurgu});
  final List<MapEntry<String, double>> satirlar;
  final double enCok;
  final String? vurgu;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(children: [
            for (final e in satirlar)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                        child: Text(e.key,
                            style: TextStyle(fontSize: 13, fontWeight: e.key == vurgu ? FontWeight.w800 : FontWeight.w500))),
                    Text(tl(e.value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: enCok <= 0 ? 0 : (e.value / enCok).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: Renk.cizgi,
                      color: e.key == vurgu ? Renk.anaKoyu : Renk.ana,
                    ),
                  ),
                ]),
              ),
          ]),
        ),
      );
}

class _Acik extends StatefulWidget {
  const _Acik({required this.veri});
  final MaliVeri veri;

  @override
  State<_Acik> createState() => _AcikState();
}

class _AcikState extends State<_Acik> {
  bool _yalnizGecmis = false;

  @override
  Widget build(BuildContext context) {
    final bugun = DateTime.now();
    final tum = widget.veri.acik;
    final gecmis = tum.where((a) => a.gecmis(bugun)).toList();
    double top(Iterable<MaliAcik> l) => l.fold(0.0, (t, a) => t + a.tutar);
    final l = [...(_yalnizGecmis ? gecmis : tum)]..sort((a, b) => (a.odeme ?? a.tarih).compareTo(b.odeme ?? b.tarih));
    Map<String, double> grup(String Function(MaliAcik) k) {
      final m = <String, double>{};
      for (final a in tum) {
        m.update(k(a), (v) => v + a.tutar, ifAbsent: () => a.tutar);
      }
      return m;
    }

    final vadeAy = grup((a) => a.odeme == null ? 'Vade yok' : '${a.odeme!.year}-${a.odeme!.month.toString().padLeft(2, '0')}');
    final ayAnahtar = vadeAy.keys.toList()..sort();
    final birim = grup((a) => a.birim).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final toplam = top(tum);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        Row(children: [
          _Kutu('Ödenmemiş toplam', tl(toplam), '${tum.length} fatura', Renk.amber),
          const SizedBox(width: 8),
          _Kutu('Vadesi geçmiş', tl(top(gecmis)), '${gecmis.length} fatura', gecmis.isEmpty ? Renk.soluk : Renk.kirmizi),
        ]),
        const BolumBasligi('Vade ayına göre'),
        _Cubuklar(satirlar: [
          for (final k in ayAnahtar)
            MapEntry(k == 'Vade yok' ? k : '${const ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'][int.parse(k.substring(5)) - 1]} ${k.substring(0, 4)}', vadeAy[k]!)
        ], enCok: vadeAy.values.fold(0.0, (a, b) => a > b ? a : b)),
        const BolumBasligi('Birime göre'),
        _Cubuklar(satirlar: birim, enCok: toplam),
        const BolumBasligi('Faturalar'),
        FilterChip(
          label: const Text('Yalnızca vadesi geçmiş'),
          selected: _yalnizGecmis,
          onSelected: (s) => setState(() => _yalnizGecmis = s),
        ),
        for (final a in l)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              title: Text('${a.kategori} · ${a.birim}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${a.tedarikci}\nFatura ${tarihKisa(a.tarih)}'
                  '${a.odeme != null ? ' · ödeme ${tarihKisa(a.odeme!)}' : ''}'
                  '${a.gecmis(bugun) ? ' · ${bugun.difference(a.odeme!).inDays} gün gecikti' : ''}'
                  '${a.yer.isEmpty ? '' : '\nAçık bakiye dosyası: ${a.yer}'}'),
              isThreeLine: true,
              trailing: Text(tl(a.tutar),
                  style: TextStyle(fontWeight: FontWeight.w700, color: a.gecmis(bugun) ? Renk.kirmizi : Renk.yazi)),
            ),
          ),
      ],
    );
  }
}

class _Karsilastirma extends StatelessWidget {
  const _Karsilastirma({required this.veri});
  final MaliVeri veri;

  static const _sira = ['Tutarsızlık', 'Uyuşmayan kayıtlar', 'Eşleşen kayıtlar', 'Uyarı', 'Karşılaştırma', 'Bilgi'];
  static const _talep = {'Tutarsızlık', 'Uyuşmayan kayıtlar'};
  static Color _renk(String b) => switch (b) {
        'Tutarsızlık' || 'Uyuşmayan kayıtlar' => Renk.kirmizi,
        'Eşleşen kayıtlar' => Renk.yesil,
        'Uyarı' => Renk.amber,
        'Karşılaştırma' => Renk.mavi,
        _ => Renk.soluk,
      };

  @override
  Widget build(BuildContext context) {
    final bolumler = {for (final k in veri.kontrol) k.bolum}.toList()
      ..sort((a, b) {
        final x = _sira.indexOf(a), y = _sira.indexOf(b);
        return (x < 0 ? 99 : x).compareTo(y < 0 ? 99 : y);
      });
    final hatalar = veri.kontrol.where((k) => _talep.contains(k.bolum)).toList();
    final hataSay = hatalar.fold<int>(0, (t, k) => t + k.detay.length);
    void gonder(List<MaliKontrol> l) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => DuzeltmeTalebiEkran(bulgular: l)));
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        const BilgiKutusu(
            yazi: 'Gelen fatura raporundaki hatalı ya da tutarsız kayıtlar ve uygulamadaki diğer verilerle '
                '(ESK, hayvancılık, bakım onarım) karşılaştırma. Her bulgunun altındaki "Nerede?" ile '
                'sayfa ve satır numaraları açılır.'),
        if (hatalar.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Düzeltilmesi gereken kayıtlar: $hataSay',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text(hatalar.map((k) => '${k.deger} – ${k.baslik.toLowerCase()}').join('\n'),
                    style: const TextStyle(fontSize: 12.5, color: Renk.soluk)),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => gonder(hatalar),
                  icon: const Icon(Icons.send),
                  label: const Text('Düzeltme talebi gönder'),
                ),
              ]),
            ),
          ),
        for (final b in bolumler) ...[
          BolumBasligi(b),
          for (final k in veri.kontrol.where((k) => k.bolum == b))
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(border: Border(left: BorderSide(color: _renk(b), width: 4))),
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(k.baslik, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (k.deger.isNotEmpty && k.deger != '—')
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(k.deger, style: TextStyle(fontWeight: FontWeight.w800, color: _renk(b))),
                    ),
                  if (k.aciklama.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(k.aciklama, style: const TextStyle(fontSize: 13)),
                  ],
                  if (k.kaynakA.isNotEmpty) _KaynakSatiri('Kaynak 1', k.kaynakA, k.linkA),
                  if (k.kaynakB.isNotEmpty) _KaynakSatiri('Kaynak 2', k.kaynakB, k.linkB),
                  if (k.duzeltme.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Ne yapılmalı: ${k.duzeltme}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ],
                  Wrap(spacing: 4, children: [
                    if (k.detay.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => _DetaySayfasi(k: k, renk: _renk(b)))),
                        icon: const Icon(Icons.list_alt),
                        label: Text('Nerede? ${k.detay.length} kaydın yeri'),
                      ),
                    if (_talep.contains(b))
                      TextButton.icon(
                        onPressed: () => gonder([k]),
                        icon: const Icon(Icons.send),
                        label: const Text('Bu bulguyu gönder'),
                      ),
                  ]),
                ]),
              ),
            ),
        ],
      ],
    );
  }
}

Future<void> _ac(BuildContext context, String link) async {
  final ok = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) bildir(context, 'Dosya açılamadı.');
}

class _KaynakSatiri extends StatelessWidget {
  const _KaynakSatiri(this.etiket, this.dosya, this.link);
  final String etiket, dosya, link;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$etiket: ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              TextSpan(text: dosya, style: const TextStyle(fontSize: 12.5)),
            ])),
          ),
          if (link.isNotEmpty)
            InkWell(
              onTap: () => _ac(context, link),
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('Dosyayı aç', style: TextStyle(fontSize: 12.5, color: Renk.mavi, fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
      );
}

/// Bir bulgunun kayıtları: her kaydın iki kaynaktaki yeri ve yapılacak düzeltme.
class _DetaySayfasi extends StatefulWidget {
  const _DetaySayfasi({required this.k, required this.renk});
  final MaliKontrol k;
  final Color renk;

  @override
  State<_DetaySayfasi> createState() => _DetaySayfasiState();
}

class _DetaySayfasiState extends State<_DetaySayfasi> {
  String _ara = '';
  String? _birim;
  int _sinir = 100;

  @override
  Widget build(BuildContext context) {
    final k = widget.k;
    final birimler = {for (final d in k.detay) d.birim}.where((b) => b.isNotEmpty).toList()..sort();
    final q = trKucuk(_ara);
    final l = k.detay
        .where((d) => (_birim == null || d.birim == _birim) &&
            (q.isEmpty || trKucuk('${d.yerA} ${d.yerB} ${d.yapilacak}').contains(q)))
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(k.baslik, maxLines: 2, style: const TextStyle(fontSize: 16))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          if (k.kaynakA.isNotEmpty) _KaynakSatiri('Kaynak 1', k.kaynakA, k.linkA),
          if (k.kaynakB.isNotEmpty) _KaynakSatiri('Kaynak 2', k.kaynakB, k.linkB),
          if (k.duzeltme.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Ne yapılmalı: ${k.duzeltme}', style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search), hintText: 'Ara: sayfa adı, satır, belge no…', isDense: true),
            onChanged: (v) => setState(() => _ara = v),
          ),
          if (birimler.length > 1)
            SizedBox(
              height: 46,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final b in birimler)
                  Padding(
                    padding: const EdgeInsets.only(right: 6, top: 6),
                    child: ChoiceChip(
                      label: Text(b),
                      selected: _birim == b,
                      onSelected: (_) => setState(() => _birim = _birim == b ? null : b),
                    ),
                  ),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('${l.length} kayıt · satır numaraları Excel satırlarıdır (başlık satırı 1)',
                style: const TextStyle(fontSize: 12, color: Renk.soluk)),
          ),
          for (final d in l.take(_sinir))
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(border: Border(left: BorderSide(color: widget.renk, width: 3))),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text([if (d.tarih != null) tarihKisa(d.tarih!), if (d.birim.isNotEmpty) d.birim].join(' · '),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  _Yer('Kaynak 1', d.yerA, d.tutarA),
                  if (d.yerB.isNotEmpty || d.tutarB != null) _Yer('Kaynak 2', d.yerB, d.tutarB),
                  if (d.yapilacak.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(d.yapilacak, style: const TextStyle(fontSize: 12.5)),
                  ],
                ]),
              ),
            ),
          if (l.length > _sinir)
            TextButton(onPressed: () => setState(() => _sinir += 200), child: Text('Daha fazla göster (${l.length - _sinir})')),
        ],
      ),
    );
  }
}

class _Yer extends StatelessWidget {
  const _Yer(this.etiket, this.yer, this.tutar);
  final String etiket, yer;
  final double? tutar;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text.rich(TextSpan(style: const TextStyle(fontSize: 12.5), children: [
          TextSpan(text: '$etiket: ', style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: yer.isEmpty ? '—' : yer),
          if (tutar != null) TextSpan(text: '  ${tl(tutar)}', style: const TextStyle(fontWeight: FontWeight.w700)),
        ])),
      );
}

/// Tutarı para birimiyle yazar: TL için [tl], dövizde "12.345,67 EUR".
String para(double v, String pb) => pb == 'TRY' ? tl(v) : '${sayi(v, ondalik: 2)} $pb';

/// Düzeltme talebinin önizlemesi (ortak paylaşım önizlemesiyle).
class DuzeltmeTalebiEkran extends StatelessWidget {
  const DuzeltmeTalebiEkran({super.key, required this.bulgular});
  final List<MaliKontrol> bulgular;

  @override
  Widget build(BuildContext context) => PaylasimOnizleme(
      baslik: 'Düzeltme talebi',
      konu: '2026 Gelen Fatura Raporları – kayıt düzeltme',
      metin: duzeltmeTalebi(bulgular));
}
