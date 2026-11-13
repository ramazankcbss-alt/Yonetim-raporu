import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/model.dart';
import '../veri/ozel.dart';
import 'bilesenler.dart';
import 'form.dart';
import 'kisiler.dart' show MesajEkran;

/// Danışmanlık: bir konuyu sor, hazırlanan değerlendirmeyi gör.
class DanismanlikEkran extends StatefulWidget {
  const DanismanlikEkran({super.key});

  @override
  State<DanismanlikEkran> createState() => _DanismanlikEkranState();
}

class _DanismanlikEkranState extends State<DanismanlikEkran> {
  late Future<OzelVeri> _f;

  @override
  void initState() {
    super.initState();
    _f = VeriDeposu.ben.ozelGetir();
  }

  void _yenile() => setState(() {
        _f = VeriDeposu.ben.ozelGetir();
      });

  Future<void> _soruSor() async {
    final sonuc = await formGoster(
      context,
      baslik: 'Yeni danışma',
      gonderYazi: 'Gönder',
      alanlar: const [
        AlanTanim('konu', 'Konu', zorunlu: true),
        AlanTanim('soru', 'Sormak istediğin', cokSatir: true, zorunlu: true),
      ],
      gonder: (d) => VeriDeposu.ben.ozelGonder('danismanlik', d),
    );
    if (sonuc == true && mounted) {
      bildir(context, 'Soru kaydedildi. Değerlendirme hazırlanınca burada görünür.');
      _yenile();
    }
  }

  /// Değerlendirmeyi seçilen kişiye WhatsApp veya e-posta ile gönderir.
  Future<void> _paylas(DanismanlikKaydi k) async {
    final kisiler = [...?VeriDeposu.ben.veri?.kisiler]
      ..sort((a, b) {
        final c = a.makam.compareTo(b.makam);
        return c != 0 ? c : a.ad.compareTo(b.ad);
      });
    final secilen = await showModalBottomSheet<Kisi>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _KisiSec(kisiler: kisiler),
    );
    if (secilen == null || !mounted) return;
    final listede = secilen.ad != _listedeYok;
    final ilkAd = secilen.ad.split(' ').first;
    final konu = k.konu.isEmpty ? 'Danışma' : k.konu;
    final metin = '${listede ? 'Merhaba $ilkAd Bey/Hanım' : 'Merhaba'},\n\n'
        '"$konu" konusundaki değerlendirme aşağıdadır.\n\n'
        '${k.soru.isEmpty ? '' : 'Soru: ${k.soru}\n\n'}'
        '${k.yanit.trim()}\n\n'
        'Ramazan Kocabaş';
    final sonuc = await Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => MesajEkran(
            kisi: secilen, konu: 'Değerlendirme: $konu', metin: metin)));
    if (sonuc != null && mounted) bildir(context, sonuc);
  }

  bool _satirVar(DanismanlikKaydi k) {
    if (k.satir != null) return true;
    bildir(context,
        'Değiştirme/silme için Apps Script kodu güncellenip yeni sürüm olarak dağıtılmalı.');
    return false;
  }

  Future<void> _duzenle(DanismanlikKaydi k) async {
    if (!_satirVar(k)) return;
    final sonuc = await formGoster(
      context,
      baslik: 'Soruyu değiştir',
      gonderYazi: 'Kaydet',
      alanlar: [
        AlanTanim('konu', 'Konu', zorunlu: true, baslangic: k.konu),
        AlanTanim('soru', 'Sormak istediğin',
            cokSatir: true, zorunlu: true, baslangic: k.soru),
      ],
      gonder: (d) => VeriDeposu.ben
          .danismaDuzenle(k.satir!, k.soru, d['konu'] ?? '', d['soru'] ?? ''),
    );
    if (sonuc == true && mounted) {
      bildir(context, 'Soru değiştirildi; değerlendirme yeniden hazırlanacak.');
      _yenile();
    }
  }

  Future<void> _sil(DanismanlikKaydi k) async {
    if (!_satirVar(k)) return;
    final evet = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Soru silinsin mi?'),
        content: Text(
            '"${k.konu.isEmpty ? k.soru : k.konu}" sorusu${k.yanit.isEmpty ? '' : ' ve değerlendirmesi'} silinecek. Geri alınamaz.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgeç')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Renk.kirmizi),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (evet != true || !mounted) return;
    try {
      await VeriDeposu.ben.danismaSil(k.satir!, k.soru);
      if (!mounted) return;
      bildir(context, 'Soru silindi.');
      _yenile();
    } catch (e) {
      if (mounted) bildir(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danışmanlık'),
        actions: [
          IconButton(
              tooltip: 'Yenile',
              onPressed: _yenile,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _soruSor,
          icon: const Icon(Icons.add),
          label: const Text('Soru sor')),
      body: FutureBuilder<OzelVeri>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return HataGovde(mesaj: '${snap.error}', yenile: _yenile);
          }
          final liste = snap.data!.danismanlik.reversed.toList();
          if (liste.isEmpty) {
            return const BosDurum(
                ikon: Icons.forum_outlined,
                yazi:
                    'Henüz danışılan bir konu yok.\nSağ alttan soru sorabilirsin.');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final k in liste)
                _Kart(
                    k: k,
                    duzenle: () => _duzenle(k),
                    sil: () => _sil(k),
                    paylas: () => _paylas(k))
            ],
          );
        },
      ),
    );
  }
}

class _Kart extends StatelessWidget {
  const _Kart(
      {required this.k, required this.duzenle, required this.sil, required this.paylas});

  final DanismanlikKaydi k;
  final VoidCallback duzenle, sil, paylas;

  @override
  Widget build(BuildContext context) {
    final renk = k.yanitlandi ? Renk.yesil : Renk.amber;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(k.konu.isEmpty ? 'Danışma' : k.konu,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Renk.yazi)),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: renk.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(k.yanitlandi ? 'Yanıtlandı' : 'Bekliyor',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: renk)),
              ),
              SizedBox(
                width: 32,
                height: 24,
                child: PopupMenuButton<String>(
                  tooltip: 'Değiştir / Sil',
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  icon: const Icon(Icons.more_vert, color: Renk.soluk),
                  onSelected: (s) => s == 'sil'
                      ? sil()
                      : s == 'paylas'
                          ? paylas()
                          : duzenle(),
                  itemBuilder: (_) => [
                    if (k.yanit.isNotEmpty)
                      const PopupMenuItem(
                          value: 'paylas',
                          child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.share_outlined),
                              title: Text('Paylaş'))),
                    const PopupMenuItem(
                        value: 'duzenle',
                        child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Değiştir'))),
                    const PopupMenuItem(
                        value: 'sil',
                        child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.delete_outline, color: Renk.kirmizi),
                            title: Text('Sil'))),
                  ],
                ),
              ),
            ],
          ),
          if (k.tarih != null) ...[
            const SizedBox(height: 2),
            Text(tarihKisa(k.tarih!),
                style: const TextStyle(fontSize: 12, color: Renk.soluk)),
          ],
          if (k.soru.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(k.soru,
                style: const TextStyle(
                    fontSize: 14, color: Renk.yazi, height: 1.4)),
          ],
          if (k.yanit.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Renk.anaAcik,
                  borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Değerlendirme${k.yanitTarihi != null ? ' · ${tarihKisa(k.yanitTarihi!)}' : ''}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Renk.anaKoyu)),
                  const SizedBox(height: 4),
                  Text(k.yanit,
                      style: const TextStyle(
                          fontSize: 14, color: Renk.yazi, height: 1.4)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: paylas,
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Paylaş (kişi / WhatsApp)'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const _listedeYok = 'WhatsApp\'ta kişi seçeceğim';

/// Paylaşılacak kişiyi seçtiren alt sayfa (Kişiler listesi + arama).
class _KisiSec extends StatefulWidget {
  const _KisiSec({required this.kisiler});
  final List<Kisi> kisiler;

  @override
  State<_KisiSec> createState() => _KisiSecState();
}

class _KisiSecState extends State<_KisiSec> {
  String _ara = '';

  @override
  Widget build(BuildContext context) {
    final a = trKucuk(_ara);
    final l = widget.kisiler
        .where((k) => a.isEmpty || trKucuk('${k.ad} ${k.birim}').contains(a))
        .toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Kime gönderilsin?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Renk.yazi)),
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(
                isDense: true, prefixIcon: Icon(Icons.search), hintText: 'Kişi ara'),
            onChanged: (s) => setState(() => _ara = s.trim()),
          ),
          const SizedBox(height: 6),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
                backgroundColor: Renk.yesilAcik, child: Icon(Icons.chat_outlined, color: Renk.yesil)),
            title: const Text('WhatsApp\'ta kişi seç'),
            subtitle: const Text('Listede olmayan biri / grup'),
            onTap: () => Navigator.pop(context, const Kisi(ad: _listedeYok)),
          ),
          const Divider(),
          Expanded(
            child: l.isEmpty
                ? const Center(
                    child: Text('Kişi bulunamadı.', style: TextStyle(color: Renk.soluk)))
                : ListView.builder(
                    itemCount: l.length,
                    itemBuilder: (_, i) {
                      final k = l[i];
                      final kanal = [
                        if (k.telefonVar) 'WhatsApp',
                        if (k.epostaVar) 'e-posta',
                      ];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                            backgroundColor: Renk.anaAcik,
                            child: Text(k.ad.isEmpty ? '?' : k.ad[0],
                                style: const TextStyle(color: Renk.anaKoyu))),
                        title: Text(k.ad),
                        subtitle: Text([
                          if (k.birim.isNotEmpty) k.birim,
                          kanal.isEmpty ? 'iletişim bilgisi yok' : kanal.join(' · '),
                        ].join(' — ')),
                        onTap: () => Navigator.pop(context, k),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
