import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tema.dart';

/// [child] ekranını basit bir PIN arkasına alır (yalnız sana özel bölümler).
/// İlk açılışta PIN oluşturulur; sonraki açılışlarda sorulur. Bu, omuz üstünden
/// bakışa karşı yerel bir kilittir; cihaz kilidi yerine geçmez.
class KilitKapisi extends StatefulWidget {
  const KilitKapisi({super.key, required this.baslik, required this.child});

  final String baslik;
  final Widget child;

  /// Testlerde kilit atlanır.
  @visibleForTesting
  static bool testAcik = false;

  static const _anahtar = 'ozel_pin';

  @override
  State<KilitKapisi> createState() => _KilitKapisiState();
}

class _KilitKapisiState extends State<KilitKapisi> {
  final _c = TextEditingController();
  final _c2 = TextEditingController();
  bool _acik = false;
  bool _yukleniyor = true;
  String? _kayitliPin;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _basla();
  }

  @override
  void dispose() {
    _c.dispose();
    _c2.dispose();
    super.dispose();
  }

  Future<void> _basla() async {
    if (KilitKapisi.testAcik) {
      setState(() {
        _acik = true;
        _yukleniyor = false;
      });
      return;
    }
    final p = await SharedPreferences.getInstance();
    setState(() {
      _kayitliPin = p.getString(KilitKapisi._anahtar);
      _yukleniyor = false;
    });
  }

  Future<void> _olustur() async {
    final a = _c.text.trim();
    final b = _c2.text.trim();
    if (a.length < 4) {
      setState(() => _hata = 'En az 4 haneli bir PIN belirleyin.');
      return;
    }
    if (a != b) {
      setState(() => _hata = 'PIN\'ler aynı değil.');
      return;
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(KilitKapisi._anahtar, a);
    setState(() {
      _kayitliPin = a;
      _acik = true;
      _hata = null;
    });
  }

  void _ac() {
    if (_c.text.trim() == _kayitliPin) {
      setState(() {
        _acik = true;
        _hata = null;
      });
    } else {
      setState(() => _hata = 'PIN yanlış.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_acik) return widget.child;
    final ilk = _kayitliPin == null;
    return Scaffold(
      appBar: AppBar(title: Text(widget.baslik)),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.lock_outline, size: 52, color: Renk.ana),
                const SizedBox(height: 12),
                Text(
                  ilk
                      ? 'Bu bölüm yalnızca sana özel. Bir PIN belirle.'
                      : 'Bu bölüm kilitli. PIN\'ini gir.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: Renk.yazi),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _c,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 8,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                      labelText: 'PIN', counterText: ''),
                  onSubmitted: ilk ? null : (_) => _ac(),
                ),
                if (ilk) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _c2,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 8,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                        labelText: 'PIN (tekrar)', counterText: ''),
                  ),
                ],
                if (_hata != null) ...[
                  const SizedBox(height: 10),
                  Text(_hata!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Renk.kirmizi, fontSize: 13.5)),
                ],
                const SizedBox(height: 18),
                Buton(
                    yazi: ilk ? 'PIN oluştur' : 'Aç',
                    ikon: ilk ? Icons.check : Icons.lock_open,
                    onTap: ilk ? _olustur : _ac),
              ],
            ),
    );
  }
}
