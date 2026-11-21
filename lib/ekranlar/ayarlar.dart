import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/guncelleme.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import 'kurulum.dart';

class AyarlarEkran extends StatefulWidget {
  const AyarlarEkran({super.key});

  @override
  State<AyarlarEkran> createState() => _AyarlarEkranState();
}

class _AyarlarEkranState extends State<AyarlarEkran> {
  final d = VeriDeposu.ben;
  late final _baslik = TextEditingController(text: d.ayar.baslik);
  late final _hazirlayan = TextEditingController(text: d.ayar.hazirlayan);
  late final _unvan = TextEditingController(text: d.ayar.unvan);
  late final _alici = TextEditingController(text: d.ayar.alici);
  bool _mesgul = false;

  @override
  void dispose() {
    _baslik.dispose();
    _hazirlayan.dispose();
    _unvan.dispose();
    _alici.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    setState(() => _mesgul = true);
    await d.ayarKaydet(RaporAyari(
      baslik: _baslik.text.trim().isEmpty
          ? const RaporAyari().baslik
          : _baslik.text.trim(),
      hazirlayan: _hazirlayan.text.trim(),
      unvan: _unvan.text.trim(),
      alici: _alici.text.trim(),
    ));
    if (!mounted) return;
    setState(() => _mesgul = false);
    bildir(context, 'Rapor bilgileri kaydedildi.');
  }

  String _gizliLink(String? l) {
    if (l == null) return 'Bağlı değil';
    final u = Uri.tryParse(l);
    final a = u?.queryParameters['anahtar'] ?? '';
    final yol = u?.path ?? '';
    final kisa = yol.length > 24 ? '…${yol.substring(yol.length - 18)}' : yol;
    final ipucu = a.isEmpty ? '?' : '${a.length > 4 ? a.substring(0, 4) : a}…';
    return 'script.google.com$kisa  ·  anahtar $ipucu';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListenableBuilder(
        listenable: d,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Panel(
              baslik: 'Rapor bilgileri (PDF)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _baslik,
                    decoration:
                        const InputDecoration(labelText: 'Rapor başlığı'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _alici,
                    decoration: const InputDecoration(
                      labelText: 'Hitap (isteğe bağlı)',
                      hintText: 'Sayın Genel Müdürüm',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hazirlayan,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Hazırlayan (ad soyad)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _unvan,
                    decoration: const InputDecoration(labelText: 'Ünvan'),
                  ),
                  const SizedBox(height: 14),
                  Buton(
                      yazi: 'Kaydet',
                      ikon: Icons.check,
                      mesgul: _mesgul,
                      onTap: _kaydet),
                ],
              ),
            ),
            Panel(
              baslik: 'Veri bağlantısı',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_gizliLink(d.link),
                      style: const TextStyle(fontSize: 13, color: Renk.soluk)),
                  if (d.sonAlinma != null) ...[
                    const SizedBox(height: 4),
                    Text('Son veri alımı: ${zamanBicim(d.sonAlinma!)}',
                        style:
                            const TextStyle(fontSize: 13, color: Renk.soluk)),
                  ],
                  const SizedBox(height: 12),
                  Buton(
                    yazi: 'Bağlantı linkini değiştir',
                    ikon: Icons.link,
                    renk: ButonRenk.ikincil,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const KurulumEkrani(ilk: false))),
                  ),
                  const SizedBox(height: 10),
                  Buton(
                    yazi: 'Bağlantıyı kaldır',
                    ikon: Icons.link_off,
                    renk: ButonRenk.tehlike,
                    onTap: () async {
                      final evet = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Bağlantı kaldırılsın mı?'),
                          content: const Text(
                              'Telefondaki rapor verisi silinir. Tekrar bağlanmak için kurulum e-postasındaki link gerekir.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Vazgeç')),
                            FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Kaldır')),
                          ],
                        ),
                      );
                      if (evet == true) {
                        await d.linkSil();
                        if (context.mounted) {
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            Panel(
              baslik: 'Uygulama',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    Guncelleme.buSurum == 0
                        ? 'Sürüm: geliştirme'
                        : 'Sürüm: ${Guncelleme.buSurum}',
                    style: const TextStyle(fontSize: 14, color: Renk.yazi),
                  ),
                  const SizedBox(height: 12),
                  Buton(
                    yazi: 'Güncellemeleri kontrol et',
                    ikon: Icons.system_update_outlined,
                    renk: ButonRenk.ikincil,
                    onTap: () => Guncelleme.kontrolEt(context, elle: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
