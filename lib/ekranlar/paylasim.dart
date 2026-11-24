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

  Future<void> _yap(String tur, {String id = '', String etiket = '', String yetki = 'gor'}) async {
    setState(() => _mesgul = true);
    try {
      final m = await VeriDeposu.ben.paylasimYonet(tur, id: id, etiket: etiket, yetki: yetki);
      if (mounted) bildir(context, m);
    } catch (e) {
      if (mounted) bildir(context, '$e');
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _ekle() async {
    final r = await showDialog<(String, String)>(context: context, builder: (_) => const _PaylasimEkle());
    if (r != null) await _yap('paylasimEkle', etiket: r.$1, yetki: r.$2);
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
            appBar: AppBar(title: const Text('Tarla Haritası paylaşımı')),
            floatingActionButton: FloatingActionButton.extended(
                onPressed: _mesgul ? null : _ekle, icon: const Icon(Icons.person_add_alt), label: const Text('Yeni paylaşım')),
            body: ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 90), children: [
              const BilgiKutusu(
                  yazi: 'Paylaşım linkiyle uygulamayı kuran kişi yalnızca Tarla Haritası\'nı görür; rapor, mali, hayvan ve '
                      'araç verileri gitmez. "Düzenleme" yetkisinde parsel ürünü/dekarı ve sınırları değiştirebilir; '
                      'girişler tabloda paylaşım adıyla işaretlenir. Paylaşımı kapattığınızda link hemen çalışmaz olur ve '
                      'karşı taraftaki harita verisi silinir. KVKK: paylaşım adına kişi adı değil görev/birim yazın.'),
              if (_mesgul) const LinearProgressIndicator(),
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
                      Wrap(spacing: 4, children: [
                        TextButton.icon(
                            onPressed: !p.acik || p.link.isEmpty
                                ? null
                                : () => Share.share(
                                    'Tarla Haritası paylaşımı (${p.yetki == 'duzenle' ? 'düzenleme' : 'görüntüleme'} yetkisi).\n'
                                    '1) Yönetim Raporu uygulamasını kurun: '
                                    'https://github.com/ramazankcbss-alt/Yonetim-raporu/releases/latest\n'
                                    '2) Uygulama açılınca bu linki yapıştırın:\n${p.link}',
                                    subject: 'Tarla Haritası paylaşımı'),
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
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(
              onPressed: _ad.text.trim().isEmpty ? null : () => Navigator.pop(context, (_ad.text.trim(), _yetki)),
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
