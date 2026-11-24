import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../servis/guncelleme.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesenler.dart';
import 'esk.dart';
import 'hastalik.dart';
import 'mali.dart';
import 'tarim.dart';
import 'tarla.dart';
import 'uretim_karlilik.dart';

/// Paylaşımlar (uygulama sahibi için): bölümler, görüntüleme / düzenleme yetkisi, aç-kapat, ad, sil.
/// Her paylaşımın kendi linki vardır; ana bağlantı linki paylaşılmaz. Link, uygulamanın web sürümünü
/// açar (kurulum gerekmez); yalnızca işaretlenen bölümlerin verisi gönderilir.
class PaylasimEkrani extends StatefulWidget {
  const PaylasimEkrani({super.key});
  @override
  State<PaylasimEkrani> createState() => _PaylasimEkraniState();
}

class _PaylasimEkraniState extends State<PaylasimEkrani> {
  bool _mesgul = false;

  Future<void> _yap(String tur, {String id = '', String etiket = '', String yetki = 'gor', List<String> bolumler = const []}) async {
    setState(() => _mesgul = true);
    try {
      final m = await VeriDeposu.ben.paylasimYonet(tur, id: id, etiket: etiket, yetki: yetki, bolumler: bolumler);
      if (mounted) bildir(context, m);
    } catch (e) {
      if (mounted) bildir(context, '$e');
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _ekle() async {
    final r = await showDialog<(String, String, List<String>)>(context: context, builder: (_) => const _PaylasimEkle());
    if (r != null) await _yap('paylasimEkle', etiket: r.$1, yetki: r.$2, bolumler: r.$3);
  }

  Future<void> _sil(PaylasimKaydi p) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
              title: Text('${p.etiket} paylaşımı silinsin mi?'),
              content: const Text('Link kalıcı olarak geçersiz olur. Tekrar paylaşmak için yeni paylaşım açmanız gerekir.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Vazgeç')),
                FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Sil')),
              ],
            ));
    if (ok == true) await _yap('paylasimSil', id: p.id);
  }

  Future<void> _adDegistir(PaylasimKaydi p) async {
    final t = TextEditingController(text: p.etiket);
    final ad = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
              title: const Text('Paylaşım adı'),
              content: TextField(
                  controller: t,
                  maxLength: 40,
                  decoration: const InputDecoration(helperText: 'KVKK: kişi adı değil görev / birim yazın')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d), child: const Text('Vazgeç')),
                FilledButton(onPressed: () => Navigator.pop(d, t.text.trim()), child: const Text('Kaydet')),
              ],
            ));
    t.dispose();
    if (ad != null && ad.isNotEmpty && ad != p.etiket) await _yap('paylasimAd', id: p.id, etiket: ad);
  }

  Future<void> _bolumDegistir(PaylasimKaydi p, String b, bool sec) async {
    final l = {...p.bolumler};
    sec ? l.add(b) : l.remove(b);
    if (l.isEmpty) {
      bildir(context, 'En az bir bölüm seçili olmalı.');
      return;
    }
    await _yap('paylasimBolum', id: p.id, bolumler: [for (final k in paylasimBolumleri.keys) if (l.contains(k)) k]);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: VeriDeposu.ben,
        builder: (context, _) {
          final l = VeriDeposu.ben.veri?.paylasimlar ?? const <PaylasimKaydi>[];
          return Scaffold(
            appBar: AppBar(title: const Text('Paylaşım')),
            floatingActionButton: FloatingActionButton.extended(
                onPressed: _mesgul ? null : _ekle, icon: const Icon(Icons.person_add_alt), label: const Text('Yeni paylaşım')),
            body: ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 90), children: [
              const BilgiKutusu(
                  yazi: 'Paylaşım linki tarayıcıda uygulamanın web sürümünü açar (kurulum gerekmez). Karşı taraf yalnızca '
                      'işaretlediğiniz bölümleri görür; diğer bölümlerin verisi gönderilmez. "Düzenleme" yetkisi yalnızca '
                      'Tarla Haritası içindir (ürün/dekar, bölme, birleştirme, çizim, sınır, yeni parsel); diğer bölümler '
                      'her zaman yalnızca görüntülenir. Paylaşımı kapattığınızda link hemen çalışmaz olur. KVKK: paylaşım '
                      'adına kişi adı değil görev/birim yazın; mali raporda tedarikçi adları bulunur.'),
              if (_mesgul) const LinearProgressIndicator(),
              if (l.isEmpty)
                const Padding(padding: EdgeInsets.all(16), child: Text('Henüz paylaşım yok.', style: TextStyle(color: Renk.soluk))),
              for (final p in l)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(child: Text(p.etiket, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                        Text(p.acik ? 'Açık' : 'Kapalı',
                            style: TextStyle(fontWeight: FontWeight.w700, color: p.acik ? Renk.yesil : Renk.amber)),
                        Switch(
                            value: p.acik,
                            onChanged: _mesgul ? null : (x) => _yap(x ? 'paylasimAc' : 'paylasimKapat', id: p.id)),
                      ]),
                      Text('Açılış: ${p.olusturma}${p.degisiklik.isEmpty ? '' : ' · son değişiklik: ${p.degisiklik}'}',
                          style: const TextStyle(fontSize: 12, color: Renk.soluk)),
                      const SizedBox(height: 8),
                      const Text('Görebileceği bölümler', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      Wrap(spacing: 6, runSpacing: 0, children: [
                        for (final e in paylasimBolumleri.entries)
                          FilterChip(
                            label: Text(e.value),
                            selected: p.bolumler.contains(e.key),
                            onSelected: _mesgul ? null : (x) => _bolumDegistir(p, e.key, x),
                          ),
                      ]),
                      const SizedBox(height: 6),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'gor', label: Text('Görüntüleme'), icon: Icon(Icons.visibility_outlined)),
                          ButtonSegment(value: 'duzenle', label: Text('Haritada düzenleme'), icon: Icon(Icons.edit_outlined)),
                        ],
                        selected: {p.yetki},
                        onSelectionChanged: _mesgul ? null : (x) => _yap('paylasimYetki', id: p.id, yetki: x.first),
                      ),
                      Wrap(spacing: 4, children: [
                        TextButton.icon(
                            onPressed: !p.acik || p.link.isEmpty
                                ? null
                                : () => Share.share(
                                    'Yönetim Raporu – paylaşılan bölümler: '
                                    '${p.bolumler.map((b) => paylasimBolumleri[b]).join(', ')}. '
                                    'Linki telefonda ya da bilgisayarda tarayıcıda açın:\n${p.link}',
                                    subject: 'Yönetim Raporu paylaşımı'),
                            icon: const Icon(Icons.send_outlined),
                            label: const Text('Linki gönder')),
                        TextButton.icon(
                            onPressed: !p.acik || p.link.isEmpty
                                ? null
                                : () {
                                    Clipboard.setData(ClipboardData(text: p.link));
                                    bildir(context, 'Link kopyalandı.');
                                  },
                            icon: const Icon(Icons.copy),
                            label: const Text('Kopyala')),
                        TextButton.icon(
                            onPressed: _mesgul ? null : () => _adDegistir(p),
                            icon: const Icon(Icons.drive_file_rename_outline),
                            label: const Text('Adını değiştir')),
                        TextButton.icon(
                            onPressed: _mesgul ? null : () => _sil(p),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Sil')),
                      ]),
                    ]),
                  ),
                ),
            ]),
          );
        },
      );
}

class _PaylasimEkle extends StatefulWidget {
  const _PaylasimEkle();
  @override
  State<_PaylasimEkle> createState() => _PaylasimEkleState();
}

class _PaylasimEkleState extends State<_PaylasimEkle> {
  final _ad = TextEditingController();
  String _yetki = 'gor';
  final _bolumler = <String>{'tarla'};
  @override
  void dispose() {
    _ad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Yeni paylaşım'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              controller: _ad,
              maxLength: 40,
              decoration: const InputDecoration(
                  labelText: 'Paylaşım adı (görev / birim)', hintText: 'Ör. Ziraat mühendisi – Aslım',
                  helperText: 'KVKK: kişi adı yazmayın'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            const Text('Görebileceği bölümler', style: TextStyle(fontWeight: FontWeight.w700)),
            for (final e in paylasimBolumleri.entries)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _bolumler.contains(e.key),
                title: Text(e.value),
                onChanged: (x) => setState(() => x == true ? _bolumler.add(e.key) : _bolumler.remove(e.key)),
              ),
            const SizedBox(height: 4),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'gor', label: Text('Görüntüleme')),
                ButtonSegment(value: 'duzenle', label: Text('Haritada düzenleme')),
              ],
              selected: {_yetki},
              onSelectionChanged: (x) => setState(() => _yetki = x.first),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Düzenleme yalnızca Tarla Haritası içindir; diğer bölümler yalnızca görüntülenir.',
                  style: TextStyle(fontSize: 12, color: Renk.soluk)),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(
              onPressed: _ad.text.trim().isEmpty || _bolumler.isEmpty
                  ? null
                  : () => Navigator.pop(context,
                      (_ad.text.trim(), _yetki, [for (final k in paylasimBolumleri.keys) if (_bolumler.contains(k)) k])),
              child: const Text('Oluştur')),
        ],
      );
}

/// Paylaşım linkiyle açılan uygulama (web ya da telefon): yalnızca paylaşılan bölümler.
class PaylasimKabugu extends StatefulWidget {
  const PaylasimKabugu({super.key});
  @override
  State<PaylasimKabugu> createState() => _PaylasimKabuguState();
}

class _PaylasimKabuguState extends State<PaylasimKabugu> with WidgetsBindingObserver {
  final d = VeriDeposu.ben;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      d.yenile();
      if (!kIsWeb) Guncelleme.kontrolEt(context);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Öne gelince yenilenir: paylaşım kapatıldıysa veri hemen silinir.
    if (state == AppLifecycleState.resumed && !d.yukleniyor) d.yenile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _ac(Widget w) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: d,
        builder: (context, _) {
          if (d.paylasimKapali) {
            return Scaffold(
              appBar: AppBar(title: const Text('Yönetim Raporu')),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const BilgiKutusu(yazi: 'Bu paylaşım kapatıldı. Paylaşılan veriler bu cihazdan silindi.'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => d.yenile(), child: const Text('Tekrar dene')),
                  if (!kIsWeb) TextButton(onPressed: d.linkSil, child: const Text('Bağlantıyı kaldır')),
                ]),
              ),
            );
          }
          final v = d.veri;
          if (v == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Yönetim Raporu')),
              body: Center(
                  child: d.hata == null
                      ? const CircularProgressIndicator()
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(d.hata!, textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            FilledButton(onPressed: () => d.yenile(), child: const Text('Tekrar dene')),
                          ]))),
            );
          }
          final p = v.paylasim;
          final bolumler = p?.bolumler ?? const ['tarla'];
          if (bolumler.length == 1 && bolumler.first == 'tarla') return TarlaEkran(veri: v);
          Widget kart(String b, IconData ik, String alt, Widget Function() ekran) => Card(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Renk.ana.withValues(alpha: 0.12), child: Icon(ik, color: Renk.ana)),
                  title: Text(paylasimBolumleri[b]!, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(alt),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _ac(ekran()),
                ),
              );
          return Scaffold(
            appBar: AppBar(
              title: const Text('Yönetim Raporu'),
              actions: [
                IconButton(tooltip: 'Yenile', onPressed: d.yukleniyor ? null : () => d.yenile(), icon: const Icon(Icons.refresh)),
              ],
            ),
            body: ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 24), children: [
              BilgiKutusu(
                  yazi: 'Paylaşılan bölümler (${p?.etiket ?? ''}). '
                      '${p?.duzenler == true && bolumler.contains('tarla') ? 'Tarla Haritası\'nda düzenleme yetkiniz var; diğer bölümler yalnızca görüntülenir.' : 'Bölümler yalnızca görüntülenir.'}'),
              if (d.yukleniyor) const LinearProgressIndicator(),
              if (bolumler.contains('tarla'))
                kart('tarla', Icons.map_outlined, 'Parseller, sezonlar, karşılaştırma, ÇKS', () => TarlaEkran(veri: v)),
              if (bolumler.contains('tarim'))
                kart('tarim', Icons.agriculture_outlined, 'Ziraat ve hayvancılık; günlük / haftalık',
                    () => Scaffold(appBar: AppBar(title: const Text('Tarım')), body: TarimEkran(veri: v))),
              if (bolumler.contains('mali')) kart('mali', Icons.account_balance_outlined, 'Gelir-gider, faturalar', () => MaliEkran(veri: v)),
              if (bolumler.contains('esk')) kart('esk', Icons.pets_outlined, 'Besi, kesim, aylık özet', () => EskEkran(veri: v)),
              if (bolumler.contains('hastalik'))
                kart('hastalik', Icons.medical_information_outlined, 'Yıllara göre hastalık dağılımı', () => HastalikEkran(veri: v)),
              if (bolumler.contains('urun'))
                kart('urun', Icons.inventory_2_outlined, 'Ekim → maliyet → teslimat → net kazanç', () => UretimKarlilikEkran(veri: v)),
            ]),
          );
        },
      );
}

/// Web sürümü paylaşım linki olmadan açıldığında.
class WebKarsilama extends StatelessWidget {
  const WebKarsilama({super.key, this.hata});
  final String? hata;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Yönetim Raporu')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BilgiKutusu(
                uyari: hata != null,
                yazi: hata ?? 'Bu sayfa yalnızca size gönderilen paylaşım linkiyle açılır. Linkin tamamını kullanın.'),
          ]),
        ),
      );
}
