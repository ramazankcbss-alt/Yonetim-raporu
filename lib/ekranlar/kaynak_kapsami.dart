// Veri Kalitesi › Kaynak Kapsamı ve Kaynak Gezgini: kaynak dosyaların her sayfası, sütunu, notu ve satırı.
import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/kaynak_envanteri.dart';
import 'bilesenler.dart';

Color _renk(String d) => switch (d) {
      'kullaniliyor' => Renk.yesil,
      'kullanilmiyor' => Renk.amber,
      'kvkk' => Colors.blueGrey,
      'hata' => Colors.red,
      _ => Colors.grey,
    };

class KaynakKapsamiEkran extends StatefulWidget {
  const KaynakKapsamiEkran({super.key});
  @override
  State<KaynakKapsamiEkran> createState() => _KaynakKapsamiEkranState();
}

class _KaynakKapsamiEkranState extends State<KaynakKapsamiEkran> {
  late Future<KaynakEnvanteri> _f = _yukle();
  String _filtre = 'tum';

  Future<KaynakEnvanteri> _yukle() async => KaynakEnvanteri.json(await VeriDeposu.ben.kaynakEnvanteri());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Kaynak Kapsamı'), actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() => _f = _yukle())),
        ]),
        body: FutureBuilder<KaynakEnvanteri>(
          future: _f,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (s.hasError) return Padding(padding: const EdgeInsets.all(16), child: BilgiKutusu(uyari: true, yazi: '${s.error}'));
            final e = s.data!;
            final top = <String, int>{};
            for (final k in e.kaynaklar) {
              KaynakEnvanteri.sayac(k).forEach((d, n) => top[d] = (top[d] ?? 0) + n);
            }
            return ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 30), children: [
              BilgiKutusu(
                  yazi: 'Piramidi besleyen bütün kaynak dosyaların her sayfası satır ve sütun sınırı olmadan incelenir; '
                      'xlsx dosyaları otomatik E-Tabloya dönüştürülür. Bir sayfaya dokunarak sütunlarını, notlarını ve '
                      'bütün satırlarını görebilirsiniz. KVKK: kişi bilgisi içeren sayfalar açılmaz, kişi bilgisi sütunları maskelidir.'
                      '${e.olusturma.isEmpty ? '' : '\nSon inceleme: ${e.olusturma.substring(0, e.olusturma.length.clamp(0, 16)).replaceFirst('T', ' ')} (UTC)'}'
                      '${e.tamam ? '' : '\nİnceleme sürüyor; kalan dosyalar birkaç dakika içinde eklenecek.'}'),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4, children: [
                for (final (k, ad) in const [
                  ('tum', 'Tümü'),
                  ('kullanilmiyor', 'Kullanılmayan'),
                  ('kullaniliyor', 'Kullanılan'),
                  ('kvkk', 'KVKK hariç'),
                  ('hata', 'Okunamayan'),
                ])
                  ChoiceChip(
                    label: Text(k == 'tum' ? ad : '$ad (${top[k] ?? 0})'),
                    selected: _filtre == k,
                    onSelected: (_) => setState(() => _filtre = k),
                  ),
              ]),
              for (final k in e.kaynaklar) _grup(context, k),
            ]);
          },
        ),
      );

  Widget _grup(BuildContext context, KaynakGrubu k) {
    final dosyalar = [
      for (final d in k.dosyalar)
        if (_filtre == 'tum' || d.sayfalar.any((s) => s.durum == _filtre) || (_filtre == 'hata' && d.hata.isNotEmpty)) d,
    ];
    if (dosyalar.isEmpty && _filtre != 'tum') return const SizedBox.shrink();
    final say = KaynakEnvanteri.sayac(k);
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: ExpansionTile(
        title: Text(k.ad, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${k.dosyalar.length} dosya · ${say.values.fold(0, (a, b) => a + b)} sayfa'
            '${(say['kullanilmiyor'] ?? 0) > 0 ? ' · ${say['kullanilmiyor']} kullanılmıyor' : ''}'
            '${k.hata.isNotEmpty ? ' · ${k.hata}' : ''}',
            style: const TextStyle(fontSize: 12.5)),
        children: [
          for (final d in dosyalar)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(d.ad, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                Text(
                    [
                      if (d.guncelleme.isNotEmpty) 'güncelleme ${d.guncelleme}',
                      if (!d.tablo) 'tablo değil (PDF / görsel / JSON)',
                      if (d.ayni.isNotEmpty) 'aynı tablo: ${d.ayni}',
                      if (d.not.isNotEmpty) d.not,
                      if (d.yarim) 'inceleme sürüyor',
                      if (d.hata.isNotEmpty) 'HATA: ${d.hata}',
                    ].join(' · '),
                    style: TextStyle(fontSize: 12, color: d.hata.isNotEmpty ? Colors.red : Colors.black54)),
                for (final s in d.sayfalar)
                  if (_filtre == 'tum' || s.durum == _filtre)
                    InkWell(
                      onTap: s.durum == 'kvkk' ? null : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => KaynakSayfaEkran(dosya: d, sayfa: s))),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          Icon(Icons.circle, size: 10, color: _renk(s.durum)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s.ad.trim().isEmpty ? '(adsız)' : s.ad.trim(), style: const TextStyle(fontSize: 13.5)),
                              Text(
                                  '${s.durumAdi}${s.kullanim.isNotEmpty ? ' · ${s.kullanim}' : ''} · '
                                  '${s.satir} satır × ${s.sutun} sütun${s.notlar.isNotEmpty ? ' · ${s.notlar.length} not' : ''}'
                                  '${s.hata > 0 ? ' · ${s.hata} formül hatası' : ''}',
                                  style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
                            ]),
                          ),
                          if (s.durum != 'kvkk') const Icon(Icons.chevron_right, size: 18),
                        ]),
                      ),
                    ),
              ]),
            ),
        ],
      ),
    );
  }
}

/// Bir kaynak sayfanın sütunları, notları ve bütün satırları.
class KaynakSayfaEkran extends StatefulWidget {
  const KaynakSayfaEkran({super.key, required this.dosya, required this.sayfa});
  final KaynakDosya dosya;
  final KaynakSayfa sayfa;
  @override
  State<KaynakSayfaEkran> createState() => _KaynakSayfaEkranState();
}

class _KaynakSayfaEkranState extends State<KaynakSayfaEkran> {
  final _satirlar = <List<String>>[];
  int _toplam = -1;
  bool _yukleniyor = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _devam();
  }

  Future<void> _devam() async {
    if (_yukleniyor) return;
    setState(() => _yukleniyor = true);
    try {
      final j = await VeriDeposu.ben.kaynakSayfa(widget.dosya.id, widget.sayfa.ad, bas: _satirlar.length, adet: 500);
      final l = j['satirlar'] is List ? j['satirlar'] as List : const [];
      setState(() {
        _toplam = (j['toplam'] as num?)?.toInt() ?? 0;
        for (final r in l) {
          if (r is List) _satirlar.add([for (final x in r) '$x']);
        }
      });
    } catch (e) {
      setState(() => _hata = '$e');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sayfa;
    final w = _satirlar.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    return Scaffold(
      appBar: AppBar(title: Text(s.ad.trim(), overflow: TextOverflow.ellipsis)),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 30), children: [
        BilgiKutusu(
            yazi: '${widget.dosya.ad}\n${s.durumAdi}${s.kullanim.isNotEmpty ? ' (${s.kullanim})' : ''}. '
                '${s.satir} satır × ${s.sutun} sütun, ${s.dolu} dolu hücre; başlık satırı ${s.baslikSatiri}.'),
        BolumBasligi('Sütunlar (${s.sutunlar.length})', ikon: Icons.view_column_outlined),
        VeriTablosu(
          basliklar: const ['Sütun', 'Başlık', 'Dolu', 'Sayısal', 'Toplam'],
          metinSutunlari: const {0, 1},
          ilkSutunGenislik: 60,
          satirlar: [
            for (final c in s.sutunlar)
              [
                _harf(c.no),
                c.baslik.isEmpty ? '—' : c.baslik,
                '${c.dolu}',
                '${c.sayisal}',
                c.toplam == null ? '—' : sayi(c.toplam, ondalik: 2),
              ],
          ],
        ),
        if (s.notlar.isNotEmpty) ...[
          BolumBasligi('Notlar ve açıklamalar (${s.notlar.length})', ikon: Icons.sticky_note_2_outlined),
          for (final n in s.notlar)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text('${n.hucre}${n.metin ? '' : ' (not)'}: ${n.not}', style: const TextStyle(fontSize: 12.5, height: 1.35)),
            ),
        ],
        BolumBasligi(_toplam < 0 ? 'Satırlar' : 'Satırlar (${_satirlar.length} / $_toplam)', ikon: Icons.table_rows_outlined),
        if (_hata != null) BilgiKutusu(uyari: true, yazi: _hata!),
        if (_satirlar.isNotEmpty)
          VeriTablosu(
            basliklar: ['#', for (var j = 0; j < w; j++) _harf(j + 1)],
            metinSutunlari: {for (var j = 0; j <= w; j++) j},
            ilkSutunGenislik: 50,
            satirlar: [
              for (var i = 0; i < _satirlar.length; i++)
                ['${i + 1}', for (var j = 0; j < w; j++) j < _satirlar[i].length ? _satirlar[i][j] : ''],
            ],
          ),
        if (_yukleniyor) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        if (!_yukleniyor && _toplam > _satirlar.length)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: OutlinedButton(onPressed: _devam, child: Text('Sonraki 500 satır (${_toplam - _satirlar.length} kaldı)')),
          ),
      ]),
    );
  }
}

String _harf(int n) {
  var s = '';
  while (n > 0) {
    final m = (n - 1) % 26;
    s = String.fromCharCode(65 + m) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

/// Bir menünün kaynak tabloları (ayrı analize bağlanmamış sayfalar, bütün hücreleriyle).
class KaynakTablolariEkran extends StatelessWidget {
  const KaynakTablolariEkran({super.key, required this.menuler, required this.baslik});
  final List<String> menuler;
  final String baslik;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(baslik)),
        body: ListenableBuilder(
          listenable: VeriDeposu.ben,
          builder: (context, _) {
            final kt = VeriDeposu.ben.veri?.kaynakTablolari ?? const KaynakTablolari();
            final l = [for (final m in menuler) ...kt.menu(m)];
            if (l.isEmpty) {
              return const Padding(
                  padding: EdgeInsets.all(16),
                  child: BilgiKutusu(yazi: 'Kaynak tabloları henüz gelmedi. Apps Script güncel olmalı.'));
            }
            final gruplar = <String, List<KaynakTablo>>{};
            for (final t in l) {
              (gruplar[t.grup] ??= []).add(t);
            }
            return ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 30), children: [
              const BilgiKutusu(
                  yazi: 'Bu sayfalar piramidin hesaplarına henüz ayrı bir analizle bağlanmadı; kaynak dosyadaki bütün hücreleriyle '
                      'burada gösterilir. KVKK: kişi bilgisi sütunları maskelidir.'),
              for (final g in gruplar.entries) ...[
                BolumBasligi(g.key, ikon: Icons.table_chart_outlined),
                for (final t in g.value)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ExpansionTile(
                      title: Text(t.sayfa, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${t.bloklar.length} tablo · ${t.bloklar.fold(0, (a, b) => a + b.length)} satır',
                          style: const TextStyle(fontSize: 12)),
                      childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                      children: [
                        for (final b in t.bloklar)
                          if (b.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: VeriTablosu(
                                basliklar: b.first,
                                metinSutunlari: {for (var j = 0; j < b.first.length; j++) j},
                                ilkSutunGenislik: 170,
                                satirlar: [
                                  for (final r in b.skip(1)) [for (var j = 0; j < b.first.length; j++) j < r.length ? r[j] : ''],
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),
              ],
            ]);
          },
        ),
      );
}

/// Menü ekranlarının üst çubuğuna eklenen "Kaynak tabloları" düğmesi.
class KaynakTablolariButonu extends StatelessWidget {
  const KaynakTablolariButonu({super.key, required this.menuler, required this.baslik});
  final List<String> menuler;
  final String baslik;
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Kaynak tabloları',
        icon: const Icon(Icons.table_chart_outlined),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => KaynakTablolariEkran(menuler: menuler, baslik: baslik))),
      );
}
