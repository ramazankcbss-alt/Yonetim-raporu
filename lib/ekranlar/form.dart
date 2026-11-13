import 'package:flutter/material.dart';

import '../tema.dart';

/// Formdaki tek bir alan.
class AlanTanim {
  const AlanTanim(this.anahtar, this.etiket,
      {this.cokSatir = false, this.zorunlu = false, this.baslangic = ''});

  final String anahtar;
  final String etiket;

  /// Düzenleme formlarında alanın dolu gelen değeri.
  final String baslangic;
  final bool cokSatir;
  final bool zorunlu;
}

/// Alt sayfada bir form açar; "Gönder"e basınca [gonder] çağrılır.
/// Başarılıysa sayfa kapanır ve true döner.
Future<bool?> formGoster(
  BuildContext context, {
  required String baslik,
  required List<AlanTanim> alanlar,
  required Future<void> Function(Map<String, String>) gonder,
  String gonderYazi = 'Gönder',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _Form(
        baslik: baslik,
        alanlar: alanlar,
        gonder: gonder,
        gonderYazi: gonderYazi),
  );
}

class _Form extends StatefulWidget {
  const _Form({
    required this.baslik,
    required this.alanlar,
    required this.gonder,
    required this.gonderYazi,
  });

  final String baslik;
  final List<AlanTanim> alanlar;
  final Future<void> Function(Map<String, String>) gonder;
  final String gonderYazi;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final Map<String, TextEditingController> _c = {
    for (final a in widget.alanlar) a.anahtar: TextEditingController(text: a.baslangic)
  };
  bool _mesgul = false;
  String? _hata;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _gonder() async {
    final deger = {
      for (final a in widget.alanlar) a.anahtar: _c[a.anahtar]!.text.trim()
    };
    for (final a in widget.alanlar) {
      if (a.zorunlu && (deger[a.anahtar] ?? '').isEmpty) {
        setState(() => _hata = '${a.etiket} boş olamaz.');
        return;
      }
    }
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      await widget.gonder(deger);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _mesgul = false;
          _hata = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final altBosluk = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + altBosluk),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                    color: Renk.cizgi,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(widget.baslik,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Renk.yazi)),
            const SizedBox(height: 14),
            for (final a in widget.alanlar) ...[
              TextField(
                controller: _c[a.anahtar],
                minLines: a.cokSatir ? 3 : 1,
                maxLines: a.cokSatir ? 8 : 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: a.etiket),
              ),
              const SizedBox(height: 12),
            ],
            if (_hata != null) ...[
              Text(_hata!,
                  style: const TextStyle(color: Renk.kirmizi, fontSize: 13.5)),
              const SizedBox(height: 10),
            ],
            Buton(
                yazi: widget.gonderYazi,
                ikon: Icons.check,
                mesgul: _mesgul,
                onTap: _gonder),
          ],
        ),
      ),
    );
  }
}
