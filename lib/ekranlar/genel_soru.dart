import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tema.dart';
import '../veri/ciftlik_rapor.dart';
import '../veri/ciftlik_soru.dart';
import '../veri/genel_soru.dart';
import '../veri/hastalik.dart';
import '../veri/model.dart';
import 'bilesenler.dart';
import 'gonder.dart';

/// Asistan › Soru Sor: uygulamadaki tüm bölümlerin verisinden cevap.
class GenelSoruEkran extends StatefulWidget {
  const GenelSoruEkran({super.key, required this.veri});
  final RaporVerisi veri;
  @override
  State<GenelSoruEkran> createState() => _GenelSoruEkranState();
}

class _GenelSoruEkranState extends State<GenelSoruEkran> {
  static const _anahtar = 'asistan_sorular';
  final _kutu = TextEditingController();
  final _sorular = <String>[];
  CiftlikRaporu? _rapor;
  List<HastalikKaydi> _hastalik = const [];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _sorular.addAll(p.getStringList(_anahtar) ?? const []));
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
    super.dispose();
  }

  Future<void> _kaydet() async => (await SharedPreferences.getInstance()).setStringList(_anahtar, _sorular);

  void _sor([String? hazir]) {
    final q = (hazir ?? _kutu.text).trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sorular
        ..remove(q)
        ..insert(0, q);
      if (_sorular.length > 20) _sorular.removeRange(20, _sorular.length);
      _kutu.clear();
    });
    _kaydet();
  }

  void _sil(String q) {
    setState(() => _sorular.remove(q));
    _kaydet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Soru Sor')),
      body: GonderAlani(
        konu: 'Asistan – Soru Sor',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 2, bottom: 8),
              child: Text(
                  'Sorunuzu yazın; cevap uygulamadaki tüm bölümlerin verisinden (süt ve sürü, tarım faaliyetleri, ekim ve hasat, ürün takibi, '
                  'ESK, hastalık, araç, bakım onarım, faturalar, veteriner, geçmiş yıllar, Çiftlikler Rapor) hesaplanır ve kaynağı belirtilir. '
                  'Kayıt yoksa tahmin yapılmaz. Hesaplama bu cihazda yapılır, veri dışarıya gönderilmez; sorular yalnızca bu cihazda saklanır.',
                  style: TextStyle(fontSize: 12.5, color: Renk.soluk, height: 1.4)),
            ),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _kutu,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sor(),
                  decoration: const InputDecoration(hintText: 'Örn. Geçen hafta Pan-Gev’de süt ne kadar?'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(tooltip: 'Sor', onPressed: _sor, icon: const Icon(Icons.send)),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final o in genelOrnekSorular)
                ActionChip(label: Text(o, style: const TextStyle(fontSize: 12)), onPressed: () => _sor(o)),
            ]),
            const SizedBox(height: 12),
            if (_sorular.isEmpty)
              const BilgiKutusu(yazi: 'Henüz soru sorulmadı. Yukarıdaki örneklerden birine dokunabilir ya da kendi sorunuzu yazabilirsiniz.'),
            for (final q in _sorular)
              _CevapKarti(
                y: genelCevapla(widget.veri, q, rapor: _rapor, hastalik: _hastalik),
                sil: () => _sil(q),
              ),
          ],
        ),
      ),
    );
  }
}

class _CevapKarti extends StatelessWidget {
  const _CevapKarti({required this.y, required this.sil});
  final GenelYanit y;
  final VoidCallback sil;

  @override
  Widget build(BuildContext context) {
    final olumsuz = [for (final b in y.bulgular) if (b.tur == BulguTuru.olumsuz) b];
    final tutarsiz = [for (final b in y.bulgular) if (b.tur == BulguTuru.tutarsizlik) b];
    return Panel(
      baslik: y.soru,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final b in y.bolumler) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Text(b.baslik, style: const TextStyle(fontWeight: FontWeight.w700, color: Renk.anaKoyu, fontSize: 14)),
          ),
          for (final p in b.paragraflar)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(p, style: const TextStyle(fontSize: 13.5, color: Renk.yazi, height: 1.45)),
            ),
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
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(onPressed: sil, icon: const Icon(Icons.delete_outline, size: 18), label: const Text('Sil')),
        ),
      ]),
    );
  }
}
