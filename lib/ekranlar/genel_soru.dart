import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tema.dart';
import '../veri/ciftlik_rapor.dart';
import '../veri/ciftlik_soru.dart';
import '../veri/genel_soru.dart';
import '../veri/hastalik.dart';
import '../veri/model.dart';
import '../veri/sureme.dart';
import 'bilesenler.dart';
import 'gonder.dart';

/// Asistan › Soru Sor: sohbet akışı. Her soru bir öncekinin bağlamını
/// (çiftlik, ürün, konu, dönem) devralır; cevap önce kısa, istenirse ayrıntılı
/// gösterilir ve altında konuşmayı ilerletecek öneriler yer alır.
class GenelSoruEkran extends StatefulWidget {
  const GenelSoruEkran({super.key, required this.veri});
  final RaporVerisi veri;
  @override
  State<GenelSoruEkran> createState() => _GenelSoruEkranState();
}

class _GenelSoruEkranState extends State<GenelSoruEkran> {
  static const _anahtar = 'asistan_sohbet';
  final _kutu = TextEditingController();
  final _kaydirma = ScrollController();

  /// Konuşmadaki sorular (eskiden yeniye).
  final _sorular = <String>[];
  CiftlikRaporu? _rapor;
  List<HastalikKaydi> _hastalik = const [];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _sorular.addAll(p.getStringList(_anahtar) ?? const []));
      _asagi();
    });
    CiftlikRaporu.yukle().then((r) {
      if (mounted) setState(() => _rapor = r);
    }).catchError((_) {});
    hastalikYukle(widget.veri.gecmis).then((l) {
      if (mounted) setState(() => _hastalik = l);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _kutu.dispose();
    _kaydirma.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async => (await SharedPreferences.getInstance()).setStringList(_anahtar, _sorular);

  void _asagi() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_kaydirma.hasClients) {
          _kaydirma.animateTo(_kaydirma.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  void _sor([String? hazir]) {
    final q = (hazir ?? _kutu.text).trim();
    if (q.isEmpty) return;
    setState(() {
      _sorular.add(q);
      if (_sorular.length > 30) _sorular.removeRange(0, _sorular.length - 30);
      _kutu.clear();
    });
    _kaydet();
    _asagi();
  }

  void _yeni() {
    setState(_sorular.clear);
    _kaydet();
  }

  /// Konuşmanın cevapları, her soru bir öncekinin bağlamıyla.
  List<GenelYanit> _cevaplar() {
    final l = <GenelYanit>[];
    SoruBaglami? b;
    final sureme = SuremeArsiv.yukle();
    for (final q in _sorular) {
      final y = genelCevapla(widget.veri, q, rapor: _rapor, hastalik: _hastalik, sureme: sureme, onceki: b);
      l.add(y);
      b = y.baglam;
    }
    return l;
  }

  @override
  Widget build(BuildContext context) {
    final cevaplar = _cevaplar();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soru Sor'),
        actions: [
          if (_sorular.isNotEmpty)
            IconButton(tooltip: 'Yeni konuşma', onPressed: _yeni, icon: const Icon(Icons.add_comment_outlined)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: GonderAlani(
            konu: 'Asistan – Soru Sor',
            child: ListView(
              controller: _kaydirma,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              children: [
                if (_sorular.isEmpty) ...[
                  const BilgiKutusu(
                      yazi: 'Sorunuzu yazın; cevap uygulamadaki tüm bölümlerin verisinden (süt ve sürü, sürü sağlığı ve üreme, tarım faaliyetleri, '
                          'ekim, ÇKS, hasat, ürün takibi, ESK, hastalık, araç, bakım onarım, Mali Raporlar gelir/gider, veteriner, geçmiş yıllar, '
                          'Çiftlikler Rapor) hesaplanır ve kaynağı belirtilir. '
                          'Cevabın altından devam sorusu sorabilirsiniz (ör. “Peki Pan-Gev’de?”, “Geçen ay?”, “Neden?”); '
                          'çiftlik, ürün ve dönem önceki sorudan devralınır. Kayıt yoksa tahmin yapılmaz. '
                          'Hesaplama bu cihazda yapılır, veri dışarıya gönderilmez; konuşma yalnızca bu cihazda saklanır.'),
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final o in genelOrnekSorular)
                      ActionChip(label: Text(o, style: const TextStyle(fontSize: 12)), onPressed: () => _sor(o)),
                  ]),
                ],
                for (final (i, y) in cevaplar.indexed) ...[
                  _SoruBalonu(y.soru),
                  _CevapBalonu(y: y, son: i == cevaplar.length - 1, sor: _sor),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Renk.cizgi))),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _kutu,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sor(),
                  decoration: InputDecoration(
                    hintText: _sorular.isEmpty ? 'Örn. Geçen hafta Pan-Gev’de süt ne kadar?' : 'Devam sorusu yazın…',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(tooltip: 'Sor', onPressed: _sor, icon: const Icon(Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _SoruBalonu extends StatelessWidget {
  const _SoruBalonu(this.metin);
  final String metin;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Renk.ana, borderRadius: BorderRadius.circular(16)),
          child: Text(metin, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.35)),
        ),
      );
}

class _CevapBalonu extends StatelessWidget {
  const _CevapBalonu({required this.y, required this.son, required this.sor});
  final GenelYanit y;
  final bool son;
  final void Function(String) sor;

  @override
  Widget build(BuildContext context) {
    final olumsuz = [for (final b in y.bulgular) if (b.tur == BulguTuru.olumsuz) b];
    final tutarsiz = [for (final b in y.bulgular) if (b.tur == BulguTuru.tutarsizlik) b];
    const yazi = TextStyle(fontSize: 13.5, color: Renk.yazi, height: 1.45);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 24, bottom: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Renk.cizgi),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (y.devralinan.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(y.devralinan, style: const TextStyle(fontSize: 11.5, color: Renk.soluk, fontStyle: FontStyle.italic)),
                ),
              for (final o in y.ozet)
                Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(o, style: yazi)),
              if (olumsuz.isNotEmpty || tutarsiz.isNotEmpty)
                Text('⚠ ${olumsuz.length} olumsuz sonuç, ${tutarsiz.length} veri tutarsızlığı (ayrıntıda)',
                    style: const TextStyle(fontSize: 12.5, color: Renk.kirmizi, fontWeight: FontWeight.w600)),
            ]),
          ),
          if (y.anlasildi)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                title: const Text('Ayrıntılar ve kaynaklar', style: TextStyle(fontSize: 13, color: Renk.anaKoyu, fontWeight: FontWeight.w600)),
                children: [
                  for (final b in y.bolumler) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 2),
                      child: Text(b.baslik, style: const TextStyle(fontWeight: FontWeight.w700, color: Renk.anaKoyu, fontSize: 14)),
                    ),
                    for (final p in b.paragraflar) Padding(padding: const EdgeInsets.only(top: 4), child: Text(p, style: yazi)),
                    if (b.kaynak.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Kaynak: ${b.kaynak}', style: const TextStyle(fontSize: 12, color: Renk.soluk, fontStyle: FontStyle.italic)),
                      ),
                  ],
                  for (final (baslik, l) in [('Olumsuz sonuçlar', olumsuz), ('Veri tutarsızlıkları', tutarsiz)])
                    if (l.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Renk.kirmiziAcik,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Renk.kirmizi.withValues(alpha: 0.35)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Text('$baslik (${l.length})', style: const TextStyle(fontWeight: FontWeight.w700, color: Renk.kirmizi)),
                          for (final x in l)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text.rich(TextSpan(children: [
                                TextSpan(text: '${x.baslik}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                                TextSpan(text: x.aciklama),
                              ]), style: const TextStyle(fontSize: 13, color: Renk.yazi, height: 1.4)),
                            ),
                        ]),
                      ),
                ],
              ),
            )
          else
            const SizedBox(height: 8),
          if (son && y.oneriler.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final o in y.oneriler)
                  ActionChip(
                    avatar: const Icon(Icons.subdirectory_arrow_right, size: 16),
                    label: Text(o, style: const TextStyle(fontSize: 12)),
                    onPressed: () => sor(o),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }
}
