import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../bicim.dart';
import '../pdf/rapor_pdf.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'ayarlar.dart';
import 'bilesenler.dart';

/// Üst yöneticiye gönderilecek PDF raporu: önizle, paylaş.
class RaporEkran extends StatefulWidget {
  const RaporEkran({super.key, required this.veri});

  final RaporVerisi veri;

  @override
  State<RaporEkran> createState() => _RaporEkranState();
}

class _RaporEkranState extends State<RaporEkran> {
  bool _haftalik = false;
  DateTime? _gun;
  DateTime? _hafta;
  bool _mesgul = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.veri;
    final ayar = VeriDeposu.ben.ayar;
    final gunler = v.gunler;
    final haftalar = v.haftalar;
    final gun = (_gun != null && gunler.contains(_gun))
        ? _gun
        : (v.sonGun != null && gunler.contains(v.sonGun)
            ? v.sonGun
            : (gunler.isEmpty ? null : gunler.first));
    final hafta = (_hafta != null && haftalar.contains(_hafta))
        ? _hafta
        : (haftalar.isEmpty ? null : haftalar.first);
    final hazir = _haftalik ? hafta != null : gun != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
                value: false,
                label: Text('Günlük'),
                icon: Icon(Icons.today_outlined)),
            ButtonSegment(
                value: true,
                label: Text('Haftalık'),
                icon: Icon(Icons.date_range_outlined)),
          ],
          selected: {_haftalik},
          onSelectionChanged: (s) => setState(() => _haftalik = s.first),
        ),
        const SizedBox(height: 12),
        if (!_haftalik && gun != null)
          Secici<DateTime>(
            secenekler: gunler,
            secili: gun,
            etiket: tarihUzun,
            degisti: (d) => setState(() => _gun = d),
          ),
        if (_haftalik && hafta != null)
          Secici<DateTime>(
            secenekler: haftalar,
            secili: hafta,
            etiket: haftaEtiketi,
            degisti: (d) => setState(() => _hafta = d),
          ),
        if (!hazir)
          const BilgiKutusu(
              uyari: true, yazi: 'Rapor oluşturmak için henüz veri yok.'),
        Panel(
          baslik: 'Raporun içeriği',
          child: Text(
            _haftalik
                ? '• Özet göstergeler (haftalık süt, ortalama verim, satılan süt, '
                    'personel, doğan buzağı, kesilen dana)\n'
                    '• Günlük süt üretimi tablosu\n'
                    '• İşletme bazlı canlı hayvan tablosu\n'
                    '• Fethiye / Erentepe sürü değişimi\n'
                    '• Haftanın tarımsal faaliyetleri\n'
                    '• Ekim alanları, hasat/verim ve besi planı'
                : '• Özet göstergeler (hayvan, sağılan, süt, satılan süt, '
                    'personel, doğan buzağı, kesilen dana)\n'
                    '• İşletme bazlı canlı hayvan tablosu\n'
                    '• Fethiye / Erentepe önceki günle karşılaştırma\n'
                    '• Günün tarımsal faaliyetleri',
            style: const TextStyle(fontSize: 14, height: 1.5, color: Renk.yazi),
          ),
        ),
        if (ayar.hazirlayan.trim().isEmpty || ayar.alici.trim().isEmpty)
          BilgiKutusu(
            yazi: 'Raporun başına hitap (ör. "Sayın Genel Müdürüm") ve sonuna '
                'adınız/ünvanınız eklenebilir. Ayarlar\'dan girin.',
          ),
        if (ayar.hazirlayan.trim().isEmpty || ayar.alici.trim().isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AyarlarEkran()));
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Rapor bilgilerini düzenle'),
            ),
          ),
        const SizedBox(height: 8),
        Buton(
          yazi: 'Önizle',
          ikon: Icons.visibility_outlined,
          renk: ButonRenk.ikincil,
          onTap: hazir ? () => _onizle(v, gun, hafta, ayar) : null,
        ),
        const SizedBox(height: 10),
        Buton(
          yazi: 'Paylaş (e-posta, WhatsApp…)',
          ikon: Icons.share_outlined,
          mesgul: _mesgul,
          onTap: hazir ? () => _paylas(v, gun, hafta, ayar) : null,
        ),
      ],
    );
  }

  Future<Uint8List> _olustur(
      RaporVerisi v, DateTime? gun, DateTime? hafta, RaporAyari a) {
    return _haftalik
        ? haftalikRaporPdf(v, hafta!, a)
        : gunlukRaporPdf(v, gun!, a);
  }

  String _dosyaAdi(DateTime? gun, DateTime? hafta) =>
      _haftalik ? haftalikDosyaAdi(hafta!) : gunlukDosyaAdi(gun!);

  void _onizle(RaporVerisi v, DateTime? gun, DateTime? hafta, RaporAyari a) {
    final ad = _dosyaAdi(gun, hafta);
    final baslik = _haftalik ? haftaEtiketi(hafta!) : tarihKisa(gun!);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text('Önizleme · $baslik')),
        body: PdfPreview(
          build: (_) => _olustur(v, gun, hafta, a),
          pdfFileName: ad,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          allowPrinting: true,
          allowSharing: true,
        ),
      ),
    ));
  }

  Future<void> _paylas(
      RaporVerisi v, DateTime? gun, DateTime? hafta, RaporAyari a) async {
    setState(() => _mesgul = true);
    try {
      final b = await _olustur(v, gun, hafta, a);
      await Printing.sharePdf(bytes: b, filename: _dosyaAdi(gun, hafta));
    } catch (e) {
      if (mounted) bildir(context, 'Rapor oluşturulamadı: $e');
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }
}
