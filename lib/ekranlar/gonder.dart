import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'bilesenler.dart';

/// Gönderilen metinlerin imzası.
const gonderImza = 'Ramazan Kocabaş\nTarım ve Hayvancılık Grup Müdürü';

/// Bir sekmenin üstüne "Bu bulguyu gönder" düğmesi koyar. Düğmeye basınca
/// sekmede görünen tüm yazılar (liste aşağı kaydırılarak) toplanır, inceleme
/// talebi metnine çevrilir ve önizleme ekranı açılır. Uygulama kendiliğinden
/// hiçbir şey göndermez; paylaşımı kullanıcı yapar.
class GonderAlani extends StatefulWidget {
  const GonderAlani({super.key, required this.konu, required this.child, this.gizle = const []});

  /// Metnin konusu, ör. "Mali Raporlar – Aylık".
  final String konu;
  final Widget child;

  /// KVKK: gönderilecek metinde "personel" ile değiştirilecek kişi adları.
  final List<String> gizle;

  @override
  State<GonderAlani> createState() => _GonderAlaniState();
}

class _GonderAlaniState extends State<GonderAlani> {
  final _icerik = GlobalKey();
  bool _topluyor = false;

  Future<void> _gonder() async {
    final ctx = _icerik.currentContext;
    if (ctx == null || _topluyor) return;
    setState(() => _topluyor = true);
    var govde = await sekmeMetni(ctx);
    for (final ad in ([...widget.gizle]..sort((a, b) => b.length.compareTo(a.length)))) {
      if (ad.trim().length > 2) govde = govde.replaceAll(ad, 'personel');
    }
    if (!mounted) return;
    setState(() => _topluyor = false);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PaylasimOnizleme(
        baslik: 'Bu bulguyu gönder',
        konu: widget.konu,
        metin: incelemeTalebi(widget.konu, govde),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
            child: Row(children: [
              Expanded(
                child: Text(widget.konu,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
              ),
              TextButton.icon(
                key: const Key('buBulguyuGonder'),
                onPressed: _topluyor ? null : _gonder,
                icon: _topluyor
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send, size: 18),
                label: const Text('Bu bulguyu gönder'),
              ),
            ]),
          ),
        ),
        Expanded(child: KeyedSubtree(key: _icerik, child: widget.child)),
      ]);
}

/// İnceleme talebi metni: konu, açıklama, bulgular, imza.
String incelemeTalebi(String konu, String govde) => [
      'Konu: $konu – inceleme talebi',
      '',
      'Merhaba,',
      'Yönetim Raporu uygulamasındaki "$konu" bölümünde yer alan aşağıdaki hususların '
          'incelenerek gerekli düzeltme ve işlemlerin yapılmasını rica ederim.',
      '',
      govde.trim(),
      '',
      'Saygılarımla,',
      gonderImza,
    ].join('\n');

/// Bir alt ağaçtaki görünen yazıları sırasıyla toplar. İlk dikey kaydırılabilir
/// alanı baştan sona kaydırarak tembel (lazy) listelerin tüm satırlarını okur,
/// sonra eski konumuna döner. Yatay listeler (seçim çipleri), simgeler ve
/// metin kutuları alınmaz.
Future<String> sekmeMetni(BuildContext ctx) async {
  final kok = ctx as Element;
  ScrollableState? sc;
  void bul(Element e) {
    if (sc != null) return;
    if (e is StatefulElement && e.state is ScrollableState) {
      final s = e.state as ScrollableState;
      if (axisDirectionToAxis(s.axisDirection) == Axis.vertical) {
        sc = s;
        return;
      }
    }
    e.visitChildElements(bul);
  }

  kok.visitChildElements(bul);
  final satirlar = <String>[];
  final gorulen = <Element>{};
  final ozel = RegExp(r'[-]');
  void topla(Element e) {
    final w = e.widget;
    if (w is Icon || w is EditableText) return;
    if (e is StatefulElement && e.state is ScrollableState) {
      final s = e.state as ScrollableState;
      if (axisDirectionToAxis(s.axisDirection) == Axis.horizontal) return;
    }
    if (w is Card || w is ListTile) {
      if (gorulen.add(e) && satirlar.isNotEmpty && satirlar.last.isNotEmpty) satirlar.add('');
    }
    if (w is RichText) {
      if (gorulen.add(e)) {
        final t = w.text.toPlainText().replaceAll(ozel, '').trim();
        if (t.isNotEmpty) satirlar.add(t);
      }
      return;
    }
    e.visitChildElements(topla);
  }

  final s = sc;
  if (s == null || !s.position.hasContentDimensions) {
    kok.visitChildElements(topla);
  } else {
    final p = s.position;
    final eski = p.pixels;
    p.jumpTo(p.minScrollExtent);
    await WidgetsBinding.instance.endOfFrame;
    for (var i = 0; i < 400; i++) {
      kok.visitChildElements(topla);
      if (p.pixels >= p.maxScrollExtent - 1) break;
      p.jumpTo(math.min(p.pixels + p.viewportDimension * 0.8, p.maxScrollExtent));
      await WidgetsBinding.instance.endOfFrame;
    }
    p.jumpTo(eski.clamp(p.minScrollExtent, p.maxScrollExtent));
  }
  final out = <String>[];
  for (final l in satirlar) {
    if (l.isEmpty && (out.isEmpty || out.last.isEmpty)) continue;
    out.add(l);
  }
  return out.join('\n').trim();
}

/// Paylaşım önizlemesi: metin düzenlenebilir, "Paylaş" telefonun paylaşım
/// menüsünü açar. Uygulama kendiliğinden hiçbir şey göndermez.
class PaylasimOnizleme extends StatefulWidget {
  const PaylasimOnizleme({super.key, required this.baslik, required this.konu, required this.metin});
  final String baslik, konu, metin;

  @override
  State<PaylasimOnizleme> createState() => _PaylasimOnizlemeState();
}

class _PaylasimOnizlemeState extends State<PaylasimOnizleme> {
  late final TextEditingController _metin = TextEditingController(text: widget.metin);

  @override
  void dispose() {
    _metin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.baslik)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          children: [
            const BilgiKutusu(
                yazi: 'Metni gerektiği gibi düzenleyebilirsiniz. "Paylaş" telefonun paylaşım menüsünü açar; '
                    'e-posta ya da mesaj uygulamasını ve alıcıyı siz seçersiniz. Yalnızca konuyla ilgili '
                    'kurum içi kişilere gönderin; kişisel veri içeren kısımları silin (KVKK).'),
            const SizedBox(height: 8),
            TextField(
              key: const Key('talepMetni'),
              controller: _metin,
              maxLines: null,
              minLines: 12,
              style: const TextStyle(fontSize: 13.5, height: 1.4),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => Share.share(_metin.text, subject: '${widget.konu} – inceleme talebi'),
              icon: const Icon(Icons.share),
              label: const Text('Paylaş'),
            ),
          ],
        ),
      );
}
