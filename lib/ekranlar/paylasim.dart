import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../servis/guncelleme.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesenler.dart';
import 'tarla.dart';

/// Tarla Haritası paylaşımları (uygulama sahibi için): görüntüleme / düzenleme yetkisi, aç-kapat, sil.
/// Her paylaşımın kendi linki vardır; ana bağlantı linki paylaşılmaz.
class PaylasimEkrani extends StatefulWidget {
  const PaylasimEkrani({super.key});
  @override
  State<PaylasimEkrani> createState() => _PaylasimEkraniState();
}

class _PaylasimEkraniState extends State<PaylasimEkrani> {
  bool _mesgul = false;

  Future<void> _yap(String tur, {String id = '', String etiket = '', String yetki = 'gor', List<String>? menuler}) async {
    setState(() => _mesgul = true);
    try {
      final m = await VeriDeposu.ben.paylasimYonet(tur, id: id, etiket: etiket, yetki: yetki, menuler: menuler);
      if (mounted) bildir(context, m);
    } catch (e) {
      if (mounted) bildir(context, '$e');
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _ekle() async {
    final r = await showDialog<(String, String, List<String>)>(context: context, builder: (_) => const _PaylasimEkle());
    if (r != null) await _yap('paylasimEkle', etiket: r.$1, yetki: r.$2, menuler: r.$3);
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: VeriDeposu.ben,
        builder: (context, _) {
          final l = VeriDeposu.ben.veri?.paylasimlar ?? const <PaylasimKaydi>[];
          return Scaffold(
            appBar: AppBar(title: const Text('Tarım ve Hayvancılık paylaşımı')),
            floatingActionButton: FloatingActionButton.extended(
                onPressed: _mesgul ? null : _ekle, icon: const Icon(Icons.person_add_alt), label: const Text('Yeni paylaşım')),
            body: ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 90), children: [
              const BilgiKutusu(
                  yazi: 'Paylaşım linki tarayıcıda "Tarım ve Hayvancılık" web panelini açar (uygulama kurmak gerekmez). '
                      'Her paylaşımda hangi menülerin (Ziraat, Hayvancılık, Tarla Haritaları) görüneceğini işaretleyin; işareti '
                      'kaldırdığınız menü ve verisi o kişiye hemen kapanır. Ziraat ve Hayvancılık yalnızca görüntülenir; personel/taşeron '
                      'sayıları gönderilmez. Rapor, mali ve araç verileri gitmez. "Düzenleme" yetkisinde Tarla Haritası\'nda sizin yapabildiğiniz her işlem '
                      '(ürün/dekar/tohum, bölme, birleştirme, çizgi ve şekille bölge, sınır düzenleme, yeni parsel) yapılabilir; '
                      '"Görüntüleme" yetkisinde hiçbir şey değiştirilemez. Girişler tabloda paylaşım adıyla '
                      'işaretlenir. Paylaşımı kapattığınızda link hemen çalışmaz olur. KVKK: paylaşım adına kişi adı değil '
                      'görev/birim yazın.'),
              if (_mesgul) const LinearProgressIndicator(),
              if (l.isNotEmpty) _GorunumOzeti(l: l),
              if (l.isEmpty)
                const Padding(padding: EdgeInsets.all(16), child: Text('Henüz paylaşım yok.', style: TextStyle(color: Renk.soluk))),
              for (final p in l)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(
                            child: Text(p.etiket, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                        Text(p.acik ? 'Açık' : 'Kapalı',
                            style: TextStyle(fontWeight: FontWeight.w700, color: p.acik ? Renk.yesil : Renk.amber)),
                        Switch(
                            value: p.acik,
                            onChanged: _mesgul ? null : (x) => _yap(x ? 'paylasimAc' : 'paylasimKapat', id: p.id)),
                      ]),
                      Text('Açılış: ${p.olusturma}${p.degisiklik.isEmpty ? '' : ' · son değişiklik: ${p.degisiklik}'}',
                          style: const TextStyle(fontSize: 12, color: Renk.soluk)),
                      const SizedBox(height: 6),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'gor', label: Text('Görüntüleme'), icon: Icon(Icons.visibility_outlined)),
                          ButtonSegment(value: 'duzenle', label: Text('Düzenleme'), icon: Icon(Icons.edit_outlined)),
                        ],
                        selected: {p.yetki},
                        onSelectionChanged: _mesgul ? null : (x) => _yap('paylasimYetki', id: p.id, yetki: x.first),
                      ),
                      const SizedBox(height: 6),
                      const Text('Görebileceği menüler', style: TextStyle(fontSize: 12.5, color: Renk.soluk)),
                      Wrap(spacing: 6, children: [
                        for (final m in paylasimMenuAdlari.entries)
                          FilterChip(
                            label: Text(m.value),
                            selected: p.menuler.contains(m.key),
                            onSelected: _mesgul
                                ? null
                                : (x) => _yap('paylasimMenu', id: p.id, menuler: [
                                      for (final k in paylasimMenuAdlari.keys)
                                        if (k == m.key ? x : p.menuler.contains(k)) k
                                    ]),
                          ),
                      ]),
                      Wrap(spacing: 4, children: [
                        TextButton.icon(
                            onPressed: !p.acik || p.link.isEmpty
                                ? null
                                : () => Share.share(
                                    'Tarım ve Hayvancılık (${p.menuler.map((m) => paylasimMenuAdlari[m] ?? m).join(', ')}). '
                                    'Linki telefonda ya da bilgisayarda tarayıcıda açın:\n${p.link}',
                                    subject: 'Tarım ve Hayvancılık paylaşımı'),
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

/// Kimin hangi bölümü gördüğünün özeti: menü başına paylaşımlar (yalnızca açık paylaşımlar erişebilir).
class _GorunumOzeti extends StatelessWidget {
  const _GorunumOzeti({required this.l});
  final List<PaylasimKaydi> l;

  @override
  Widget build(BuildContext context) {
    String kim(PaylasimKaydi p) => '${p.etiket} (${p.duzenler && p.menuler.contains('tarla') ? 'düzenleme' : 'görüntüleme'})';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Kim hangi bölümü görüyor', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Yalnızca açık paylaşımlar sayılır. Düzenleme yetkisi yalnızca Tarla Haritaları\'nda geçerlidir.',
              style: TextStyle(fontSize: 12, color: Renk.soluk)),
          for (final m in paylasimMenuAdlari.entries) ...[
            const SizedBox(height: 10),
            Text(m.value, style: const TextStyle(fontWeight: FontWeight.w700, color: Renk.ana)),
            Builder(builder: (_) {
              final x = [for (final p in l) if (p.acik && p.menuler.contains(m.key)) kim(p)];
              return Text(x.isEmpty ? 'Kimse görmüyor' : x.join(' · '),
                  style: TextStyle(fontSize: 13.5, color: x.isEmpty ? Renk.soluk : Renk.yazi));
            }),
          ],
          if (l.any((p) => !p.acik)) ...[
            const SizedBox(height: 10),
            Text('Kapalı paylaşımlar: ${[for (final p in l) if (!p.acik) p.etiket].join(' · ')}',
                style: const TextStyle(fontSize: 12.5, color: Renk.amber)),
          ],
        ]),
      ),
    );
  }
}

/// Paylaşımda seçilebilen menüler (web panelindeki adlarıyla).
const paylasimMenuAdlari = {'ziraat': 'Ziraat', 'hayvan': 'Hayvancılık', 'tarla': 'Tarla Haritaları'};

class _PaylasimEkle extends StatefulWidget {
  const _PaylasimEkle();
  @override
  State<_PaylasimEkle> createState() => _PaylasimEkleState();
}

class _PaylasimEkleState extends State<_PaylasimEkle> {
  final _ad = TextEditingController();
  String _yetki = 'gor';
  final _menuler = <String>{'tarla'};
  @override
  void dispose() {
    _ad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Yeni paylaşım'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            controller: _ad,
            maxLength: 40,
            decoration: const InputDecoration(
                labelText: 'Paylaşım adı (görev / birim)', hintText: 'Ör. Ziraat mühendisi – Aslım',
                helperText: 'KVKK: kişi adı yazmayın'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'gor', label: Text('Görüntüleme')),
              ButtonSegment(value: 'duzenle', label: Text('Düzenleme')),
            ],
            selected: {_yetki},
            onSelectionChanged: (x) => setState(() => _yetki = x.first),
          ),
          const SizedBox(height: 10),
          const Text('Görebileceği menüler', style: TextStyle(fontSize: 12.5, color: Renk.soluk)),
          Wrap(spacing: 6, children: [
            for (final m in paylasimMenuAdlari.entries)
              FilterChip(
                label: Text(m.value),
                selected: _menuler.contains(m.key),
                onSelected: (x) => setState(() => x ? _menuler.add(m.key) : _menuler.remove(m.key)),
              ),
          ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(
              onPressed: _ad.text.trim().isEmpty || _menuler.isEmpty
                  ? null
                  : () => Navigator.pop(context,
                      (_ad.text.trim(), _yetki, [for (final k in paylasimMenuAdlari.keys) if (_menuler.contains(k)) k])),
              child: const Text('Oluştur')),
        ],
      );
}

/// Paylaşım linkiyle kurulan uygulama: yalnızca Tarla Haritası.
class PaylasimKabugu extends StatefulWidget {
  const PaylasimKabugu({super.key, this.guncellemeKontrolu = true});
  final bool guncellemeKontrolu;
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
      if (widget.guncellemeKontrolu) Guncelleme.kontrolEt(context);
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: d,
        builder: (context, _) {
          if (d.paylasimKapali) {
            return Scaffold(
              appBar: AppBar(title: const Text('Tarla Haritası')),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const BilgiKutusu(yazi: 'Bu paylaşım kapatıldı. Harita verisi bu telefondan silindi.'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => d.yenile(), child: const Text('Tekrar dene')),
                  TextButton(onPressed: d.linkSil, child: const Text('Bağlantıyı kaldır')),
                ]),
              ),
            );
          }
          final v = d.veri;
          if (v == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Tarla Haritası')),
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
          return TarlaEkran(veri: v);
        },
      );
}
