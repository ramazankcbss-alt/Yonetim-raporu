import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../servis/veri_servisi.dart';
import '../tema.dart';

/// Bağlantı linkini alır (kurulum e-postasından kopyalanan
/// https://script.google.com/…/exec?anahtar=… adresi).
class KurulumEkrani extends StatefulWidget {
  const KurulumEkrani({super.key, required this.ilk});

  /// İlk açılış mı (geri butonu yok), Ayarlar'dan mı geliniyor?
  final bool ilk;

  @override
  State<KurulumEkrani> createState() => _KurulumEkraniState();
}

class _KurulumEkraniState extends State<KurulumEkrani> {
  final _link = TextEditingController();
  bool _mesgul = false;
  String? _hata;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _yapistir() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text?.trim() ?? '';
    if (t.isEmpty) {
      if (mounted) bildir(context, 'Panoda metin yok. Önce linki kopyalayın.');
      return;
    }
    // E-postadan kopyalanan metnin içindeki linki bul.
    final m = RegExp(r'https://script\.google\.com/\S+').firstMatch(t);
    setState(() {
      _link.text = m?.group(0) ?? t;
      _hata = null;
    });
  }

  Future<void> _baglan() async {
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      await VeriDeposu.ben.linkKaydet(_link.text);
      if (!mounted) return;
      if (!widget.ilk) {
        bildir(context, 'Bağlantı güncellendi.');
        Navigator.of(context).pop();
      }
      // İlk kurulumda Kapı, link kaydedilince ana ekrana geçer.
    } on VeriHatasi catch (e) {
      setState(() => _hata = e.mesaj);
    } catch (_) {
      setState(() => _hata =
          'Bağlanılamadı. İnternet bağlantınızı ve linki kontrol edin.');
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ilk ? 'Yönetim Raporu' : 'Bağlantı linki'),
        automaticallyImplyLeading: !widget.ilk,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (widget.ilk)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Çiftlik raporu verilerini görmek için bağlantı linkini girin.',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600, color: Renk.yazi),
              ),
            ),
          Panel(
            baslik: 'Bağlantı linki',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _link,
                  minLines: 2,
                  maxLines: 4,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: 'https://script.google.com/macros/s/…/exec?anahtar=…',
                    errorText: _hata,
                    errorMaxLines: 4,
                  ),
                  onChanged: (_) {
                    if (_hata != null) setState(() => _hata = null);
                  },
                ),
                const SizedBox(height: 12),
                Buton(
                  yazi: 'Panodan yapıştır',
                  ikon: Icons.content_paste,
                  renk: ButonRenk.ikincil,
                  onTap: _yapistir,
                ),
                const SizedBox(height: 10),
                Buton(
                  yazi: 'Bağlan',
                  ikon: Icons.link,
                  mesgul: _mesgul,
                  onTap: _baglan,
                ),
              ],
            ),
          ),
          const Panel(
            baslik: 'Link nereden alınır?',
            child: Text(
              '1. Bilgisayarda Haftalik_Yonetim_Raporu_Ciftlikler Google E-Tablosunu açın.\n'
              '2. Uzantılar → Apps Script\'e girin, size verilen Kod.gs içeriğini yapıştırıp kaydedin.\n'
              '3. Dağıt → Yeni dağıtım → Web uygulaması (Yürütme: Ben, Erişim: Herkes) → Dağıt.\n'
              '4. Çıkan web uygulaması adresini kodun başındaki WEB_URL satırına yapıştırın, kaydedin.\n'
              '5. "kurulum" fonksiyonunu çalıştırın. Bağlantı linki e-postanıza gelir.\n'
              '6. E-postayı telefonda açın, linki kopyalayın ve buraya yapıştırın.\n\n'
              'Link rapor verilerini okumaya yeter; kimseyle paylaşmayın.',
              style: TextStyle(fontSize: 14, height: 1.5, color: Renk.yazi),
            ),
          ),
        ],
      ),
    );
  }
}
