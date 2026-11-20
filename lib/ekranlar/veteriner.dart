import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesenler.dart';
import 'gonder.dart';

/// Veteriner Kontrol Paneli (uygulama sahibi tarafı): veteriner hekimlerin
/// web panelinden gönderdiği değerlendirmeler ve panel erişim kodları.
///
/// Veteriner hekimler panel adresini tarayıcıda açar, verilen kodla giriş
/// yapar; Hayvancılık göstergelerini ve Hastalık Dağılımını (etken, önleme
/// tedbirleri) inceleyip yanlış, eksik ya da yetersiz bulduklarını bildirir.
class VeterinerEkran extends StatelessWidget {
  const VeterinerEkran({super.key, required this.veri});

  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VeriDeposu.ben,
      builder: (context, _) {
        final v = VeriDeposu.ben.veri ?? veri;
        final yeni = v.vetBildirimleri.where((b) => b.yeni).length;
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Veteriner Kontrol Paneli'),
              actions: const [TabloGuncelleButonu()],
              bottom: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xCCFFFFFF),
                indicatorColor: Colors.white,
                tabs: [
                  Tab(text: yeni > 0 ? 'Bildirimler ($yeni yeni)' : 'Bildirimler'),
                  const Tab(text: 'Erişim kodları'),
                ],
              ),
            ),
            body: Column(children: [
              _PanelDurumu(acik: v.vetPanelAcik),
              Expanded(child: TabBarView(children: [
              GonderAlani(
                  konu: 'Veteriner Kontrol Paneli – Bildirimler',
                  gizle: [for (final k in v.vetKodlari) k.etiket, for (final k in v.vetKodlari) k.kod],
                  child: _Bildirimler(liste: v.vetBildirimleri)),
              // Erişim kodları gizli bilgidir; gönderilmez.
              _Kodlar(kodlar: v.vetKodlari),
            ])),
            ]),
          ),
        );
      },
    );
  }
}

Color _degRenk(String d) => switch (d) {
      'Doğru' => Renk.yesil,
      'Yanlış' => Renk.kirmizi,
      'Eksik' || 'Yetersiz' => Renk.amber,
      _ => Renk.mavi,
    };

Color _durumRenk(String d) => switch (d) {
      'Yeni' => Renk.amber,
      'Düzeltildi' => Renk.yesil,
      'Katılmıyorum' => Renk.kirmizi,
      _ => Renk.mavi,
    };

class _Bildirimler extends StatefulWidget {
  const _Bildirimler({required this.liste});
  final List<VetBildirim> liste;

  @override
  State<_Bildirimler> createState() => _BildirimlerState();
}

class _BildirimlerState extends State<_Bildirimler> {
  bool _yalnizYeni = false;
  String? _bolum;

  @override
  Widget build(BuildContext context) {
    final bolumler = {for (final b in widget.liste) b.bolum}.where((e) => e.isNotEmpty).toList()..sort();
    final l = widget.liste
        .where((b) => (!_yalnizYeni || b.yeni) && (_bolum == null || b.bolum == _bolum))
        .toList();
    final say = <String, int>{};
    for (final b in widget.liste) {
      say.update(b.degerlendirme, (n) => n + 1, ifAbsent: () => 1);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        const BilgiKutusu(
            yazi: 'Veteriner hekimlerin Hayvancılık ve Hastalık Dağılımı analizleri için '
                'gönderdiği değerlendirmeler. İnceledikçe durumunu işaretleyin; yanıt '
                'yazarsanız veteriner panelinde görür.'),
        const SizedBox(height: 8),
        if (say.isNotEmpty)
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final e in say.entries)
              Chip(
                label: Text('${e.key} ${e.value}'),
                labelStyle: TextStyle(color: _degRenk(e.key), fontWeight: FontWeight.w700),
                backgroundColor: _degRenk(e.key).withValues(alpha: .10),
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              ),
          ]),
        Wrap(spacing: 6, children: [
          FilterChip(
            label: const Text('Yalnızca yeni'),
            selected: _yalnizYeni,
            onSelected: (s) => setState(() => _yalnizYeni = s),
          ),
          for (final b in bolumler)
            ChoiceChip(
              label: Text(b),
              selected: _bolum == b,
              onSelected: (_) => setState(() => _bolum = _bolum == b ? null : b),
            ),
        ]),
        const SizedBox(height: 8),
        if (l.isEmpty)
          const BilgiKutusu(
              yazi: 'Henüz bildirim yok. Erişim kodları sekmesinden veteriner hekim için kod '
                  'oluşturup panel adresiyle birlikte iletin.'),
        for (final b in l) _BildirimKarti(b: b),
      ],
    );
  }
}

class _BildirimKarti extends StatelessWidget {
  const _BildirimKarti({required this.b});
  final VetBildirim b;

  Future<void> _durum(BuildContext context, String durum, {bool yanitIste = false}) async {
    String? yanit;
    if (yanitIste) {
      final c = TextEditingController(text: b.yanit);
      final ok = await showDialog<bool>(
        context: context,
        builder: (c2) => AlertDialog(
          title: Text(durum),
          content: TextField(
            controller: c,
            maxLines: 4,
            decoration: const InputDecoration(
                hintText: 'Veterinere yanıt (isteğe bağlı). Kişi adı yazmayın.'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c2, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(c2, true), child: const Text('Kaydet')),
          ],
        ),
      );
      if (ok != true) return;
      yanit = c.text.trim();
    }
    try {
      await VeriDeposu.ben.vetBildirimDurum(b, durum, yanit: yanit);
      if (context.mounted) bildir(context, 'Durum: $durum');
    } catch (e) {
      if (context.mounted) bildir(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final dr = _degRenk(b.degerlendirme);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: dr.withValues(alpha: .12), borderRadius: BorderRadius.circular(6)),
              child: Text(b.degerlendirme, style: TextStyle(color: dr, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(b.bolum, style: const TextStyle(color: Renk.soluk, fontSize: 12.5))),
            Text(b.durum, style: TextStyle(color: _durumRenk(b.durum), fontWeight: FontWeight.w700, fontSize: 12.5)),
          ]),
          const SizedBox(height: 6),
          Text(b.konu, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (b.aciklama.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(b.aciklama),
          ],
          const SizedBox(height: 4),
          Text('${b.etiket} · ${b.tarih}', style: const TextStyle(fontSize: 11.5, color: Renk.soluk)),
          if (b.yanit.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Yanıtınız: ${b.yanit}', style: const TextStyle(fontSize: 12.5, color: Renk.mavi)),
          ],
          Wrap(spacing: 4, children: [
            if (b.yeni) TextButton(onPressed: () => _durum(context, 'Görüldü'), child: const Text('Görüldü')),
            TextButton(
                onPressed: () => _durum(context, 'Düzeltildi', yanitIste: true), child: const Text('Düzeltildi')),
            TextButton(
                onPressed: () => _durum(context, 'Katılmıyorum', yanitIste: true),
                child: const Text('Katılmıyorum')),
          ]),
        ]),
      ),
    );
  }
}

class _Kodlar extends StatelessWidget {
  const _Kodlar({required this.kodlar});
  final List<VetKod> kodlar;

  Future<void> _yeni(BuildContext context) async {
    final c = TextEditingController();
    final etiket = await showDialog<String>(
      context: context,
      builder: (c2) => AlertDialog(
        title: const Text('Yeni erişim kodu'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: 'Görev / rol',
                hintText: 'ör. Şekersüt veteriner hekimi'),
          ),
          const SizedBox(height: 10),
          const Text(
              'KVKK: Kişi adı değil görev/rol yazın. Kod yalnızca hayvan sayılarını ve '
              'hastalık istatistiklerini gösterir; işi biten kodu kapatın.',
              style: TextStyle(fontSize: 12, color: Renk.soluk)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c2), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(c2, c.text.trim()), child: const Text('Oluştur')),
        ],
      ),
    );
    if (etiket == null || etiket.isEmpty || !context.mounted) return;
    try {
      final kod = await VeriDeposu.ben.vetKodEkle(etiket);
      if (context.mounted) await _kodGoster(context, kod, etiket);
    } catch (e) {
      if (context.mounted) bildir(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final adres = VeriDeposu.ben.vetPanelAdresi;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Panel adresi', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              SelectableText(adres ?? 'Bağlantı linki ayarlı değil.',
                  style: const TextStyle(fontSize: 12.5)),
              const SizedBox(height: 4),
              const Text(
                  'Veteriner hekim bu adresi tarayıcıda açar ve verdiğiniz kodla giriş yapar. '
                  'Adres veri içermez; kod olmadan hiçbir bilgi görünmez.',
                  style: TextStyle(fontSize: 12, color: Renk.soluk)),
              if (adres != null)
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: adres));
                    if (context.mounted) bildir(context, 'Panel adresi kopyalandı.');
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Adresi kopyala'),
                ),
            ]),
          ),
        ),
        FilledButton.icon(
          onPressed: () => _yeni(context),
          icon: const Icon(Icons.vpn_key_outlined),
          label: const Text('Yeni erişim kodu oluştur'),
        ),
        const SizedBox(height: 12),
        if (kodlar.isEmpty) const BilgiKutusu(yazi: 'Henüz kod yok.'),
        for (final k in kodlar)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(k.etiket, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  'Kod ${k.kod} · ${k.durum}\nOluşturma ${k.olusturma}'
                  '${k.sonGiris.isEmpty ? ' · henüz giriş yok' : ' · son giriş ${k.sonGiris}'}'),
              isThreeLine: true,
              onTap: () => _kodGoster(context, k.kod, k.etiket),
              trailing: Switch(
                value: k.aktif,
                onChanged: (a) async {
                  try {
                    await VeriDeposu.ben.vetKodDurum(k.kod, acik: a);
                  } catch (e) {
                    if (context.mounted) bildir(context, e.toString());
                  }
                },
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> _kodGoster(BuildContext context, String kod, String etiket) {
  final adres = VeriDeposu.ben.vetPanelAdresi ?? '';
  final metin = 'Veteriner Kontrol Paneli\nAdres: $adres\nErişim kodu: $kod';
  return showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(etiket),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Erişim kodu', style: TextStyle(color: Renk.soluk, fontSize: 12.5)),
        SelectableText(kod, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 2)),
        const SizedBox(height: 8),
        const Text('Kodu ve panel adresini veteriner hekime iletin. Kod kişiye özeldir; '
            'işi bitince Erişim kodları sekmesinden kapatın.',
            style: TextStyle(fontSize: 12.5)),
      ]),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: metin));
            if (c.mounted) Navigator.pop(c);
            if (context.mounted) bildir(context, 'Adres ve kod kopyalandı.');
          },
          icon: const Icon(Icons.copy),
          label: const Text('Adres + kodu kopyala'),
        ),
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Kapat')),
      ],
    ),
  );
}

/// Panelin erişim durumu: açıkken veteriner hekimler kodla girer; kapalıyken
/// panel adresi veri göstermez ve hiçbir kod çalışmaz. Kodlar ve bildirimler
/// saklanır, panel yeniden açılınca aynen kullanılır.
class _PanelDurumu extends StatefulWidget {
  const _PanelDurumu({required this.acik});
  final bool acik;

  @override
  State<_PanelDurumu> createState() => _PanelDurumuState();
}

class _PanelDurumuState extends State<_PanelDurumu> {
  bool _bekle = false;

  Future<void> _degistir(bool acik) async {
    setState(() => _bekle = true);
    try {
      await VeriDeposu.ben.vetPanelDurum(acik: acik);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Durum değiştirilemedi: $e')));
      }
    } finally {
      if (mounted) setState(() => _bekle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final acik = widget.acik;
    return Material(
      color: (acik ? Renk.yesil : Renk.kirmizi).withValues(alpha: 0.10),
      child: SwitchListTile(
        secondary: Icon(acik ? Icons.lock_open : Icons.lock_outline,
            color: acik ? Renk.yesil : Renk.kirmizi),
        title: Text(acik ? 'Panel erişime açık' : 'Panel erişime kapalı',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(acik
            ? 'Aktif kodu olan veteriner hekimler giriş yapabilir.'
            : 'Hiçbir kod çalışmaz; kodlar ve bildirimler saklanır.'),
        value: acik,
        onChanged: _bekle ? null : _degistir,
      ),
    );
  }
}
