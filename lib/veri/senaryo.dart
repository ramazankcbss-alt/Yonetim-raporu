// İki senaryo karşılaştırması: "2026 Yılı Çiftlik Raporları" dosyasında her
// çiftliğin iki sayfası vardır.
//  - "1605 - Aslım" vb.: çiftlikte üretilip grup içinde kullanılan ürünler
//    maliyet bedeliyle aktarılır (maliyet senaryosu).
//  - "1605 - Aslım 2" vb.: aynı ürünler dışarı satılsaydı piyasa satış
//    fiyatıyla, dışarıdan alınsaydı piyasa alış fiyatıyla değerlenir
//    (piyasa senaryosu).
// Veri araclar/ciftlik_rapor/uret.py tarafından ciftlik_rapor_2026.json içine
// "senaryo" anahtarıyla yazılır. KVKK: yalnızca çiftlik bazında toplam tutar.
import '../bicim.dart';
import 'ciftlik_rapor.dart';

const kSenaryoToplam = 'Çiftliklerimiz (ESK hariç)';
const senaryoKalemleri = [
  'Net satışlar',
  'Satışların maliyeti',
  'Brüt satış kârı/zararı',
  'Faaliyet giderleri',
  'Faaliyet dışı net',
  'Dönem net kârı/zararı',
];

class SenaryoAy {
  const SenaryoAy(this.ayNo, this.s1, this.s2, this.satis1, this.satis2);
  final int ayNo;

  /// Dönem net sonucu: maliyet senaryosu (s1), piyasa senaryosu (s2).
  final double s1, s2;

  /// Net satışlar: maliyet senaryosu, piyasa senaryosu.
  final double satis1, satis2;
  double get fark => s2 - s1;
  String get ay => raporAylari[ayNo - 1];
}

class SenaryoCiftlik {
  const SenaryoCiftlik(this.ciftlik, this.kalemler, this.aylik);
  final String ciftlik;

  /// kalem → (maliyet senaryosu, piyasa senaryosu)
  final Map<String, (double, double)> kalemler;
  final List<SenaryoAy> aylik;

  double s1(String k) => kalemler[k]?.$1 ?? 0;
  double s2(String k) => kalemler[k]?.$2 ?? 0;
  double fark(String k) => s2(k) - s1(k);
  double get net1 => s1('Dönem net kârı/zararı');
  double get net2 => s2('Dönem net kârı/zararı');
  double get netFark => net2 - net1;
}

class SenaryoKontrol {
  const SenaryoKontrol(this.tur, this.baslik, this.aciklama, this.ciftlik);

  /// 'tutarsizlik' | 'bilgi'
  final String tur, baslik, aciklama, ciftlik;
}

class Senaryo {
  const Senaryo({required this.aciklama, required this.donem, required this.ciftlikler, required this.kontrol});
  final String aciklama, donem;
  final List<SenaryoCiftlik> ciftlikler;
  final List<SenaryoKontrol> kontrol;

  SenaryoCiftlik? ciftlik(String c) => ciftlikler.where((x) => x.ciftlik == c).firstOrNull;

  static Senaryo? json(Map<String, dynamic>? j) {
    if (j == null) return null;
    List<Map<String, dynamic>> l(Map<String, dynamic> m, String k) => ((m[k] as List?) ?? const []).cast<Map<String, dynamic>>();
    double d(Object? v) => (v as num).toDouble();
    return Senaryo(
      aciklama: j['aciklama'] as String? ?? '',
      donem: j['donem'] as String? ?? '',
      ciftlikler: [
        for (final c in l(j, 'ciftlikler'))
          SenaryoCiftlik(
            c['ciftlik'] as String,
            {for (final k in l(c, 'kalemler')) k['kalem'] as String: (d(k['s1']), d(k['s2']))},
            [for (final a in l(c, 'aylik')) SenaryoAy(a['ay_no'] as int, d(a['s1']), d(a['s2']), d(a['satis1']), d(a['satis2']))],
          ),
      ],
      kontrol: [
        for (final k in l(j, 'kontrol'))
          SenaryoKontrol(k['tur'] as String, k['baslik'] as String, k['aciklama'] as String, k['ciftlik'] as String? ?? ''),
      ],
    );
  }
}

/// "+12,1 mn ₺" / "−6,8 mn ₺"
String mnFark(double v) => '${v > 0 ? '+' : v < 0 ? '−' : ''}${sayi(v.abs() / 1e6, ondalik: 1)} mn ₺';

/// Bir çiftliğin iki senaryo arasındaki farkının nedenleri (veriden üretilir).
List<(String, String)> senaryoNedenleri(Senaryo s, SenaryoCiftlik c) {
  final l = <(String, String)>[];
  final ds = c.fark('Net satışlar'), dm = c.fark('Satışların maliyeti'), dn = c.netFark;
  final toplam = c.ciftlik == kSenaryoToplam;

  l.add((
    'Sonuç',
    'Maliyet bedeliyle aktarımda dönem sonucu ${kz(c.net1)}, piyasa fiyatlarıyla ${kz(c.net2)}; fark ${mnFark(dn)}.',
  ));
  if (ds.abs() >= 1000) {
    l.add((
      'Satışlar ${mnFark(ds)}',
      toplam
          ? 'Grup içi alım-satımlar piyasa fiyatıyla gelir yazıldığında çiftliklerin toplam cirosu ${mn(c.s1('Net satışlar'))} yerine ${mn(c.s2('Net satışlar'))} oluyor.'
          : 'Çiftliğin grup içine verdiği ürünler piyasa satış fiyatıyla gelir yazılıyor (${mn(c.s1('Net satışlar'))} → ${mn(c.s2('Net satışlar'))}).',
    ));
  }
  if (dm.abs() >= 1000) {
    l.add((
      'Satışların maliyeti ${mnFark(dm)}',
      toplam
          ? 'Grup içinden alınan girdiler piyasa alış fiyatıyla maliyete giriyor (${mn(c.s1('Satışların maliyeti'))} → ${mn(c.s2('Satışların maliyeti'))}).'
          : 'Grup içinden alınan girdiler (yem, kaba yem, hayvan vb.) piyasa alış fiyatıyla maliyete giriyor; ayrıca piyasa fiyatıyla satılan ürünün maliyeti de satış maliyetine yansıyor '
              '(${mn(c.s1('Satışların maliyeti'))} → ${mn(c.s2('Satışların maliyeti'))}).',
    ));
  }
  if (toplam) {
    if (dn.abs() >= 1e5) {
      l.add((
        'Grup toplamındaki fark',
        'Grup içi alım-satım iki tarafta da aynı fiyatla yazılırsa grup toplamı değişmez. Toplamdaki ${mnFark(dn)} fark, iç satışın alıcı çiftlikte henüz '
            'maliyete dönüşmemiş (stokta veya sürüde bekleyen) kısmından ya da satan ve alan çiftlikte farklı fiyat kullanılmasından kaynaklanır; '
            'muhasebe ile teyit edilmelidir.',
      ));
    }
  } else if (dn.abs() >= 1e5) {
    l.add(dn > 0
        ? (
            'Yorum',
            'Çiftliğin grup içine verdiği ürünlerin piyasa değeri, aldığı girdilerin piyasa değerinden yüksek. Maliyet bedeliyle aktarım bu çiftliğin '
                'kârını ${mn(dn)} düşük gösteriyor; aradaki fark grup içindeki diğer çiftliklere aktarılıyor.'
          )
        : (
            'Yorum',
            'Çiftliğin kullandığı girdilerin piyasa bedeli, ürettiği ürünün piyasa değerinden yüksek. Maliyet bedeliyle aktarım bu çiftliğin sonucunu '
                '${mn(-dn)} iyi gösteriyor; piyasa koşullarında çiftlik ${c.net2 < 0 ? 'zarar eder' : 'daha az kâr eder'}.'
          ));
  }
  final b2 = c.s2('Brüt satış kârı/zararı'), n2 = c.s2('Net satışlar');
  final b1 = c.s1('Brüt satış kârı/zararı'), n1 = c.s1('Net satışlar');
  if (n2 > 0 && n1 > 0) {
    l.add((
      'Brüt kâr marjı',
      'Maliyet senaryosunda %${sayi(b1 / n1 * 100, ondalik: 1)}, piyasa senaryosunda %${sayi(b2 / n2 * 100, ondalik: 1)}.',
    ));
  }
  final aylar = [for (final a in c.aylik) if (a.fark.abs() >= 1) a]..sort((a, b) => b.fark.abs().compareTo(a.fark.abs()));
  if (aylar.isNotEmpty) {
    l.add((
      'Farkın yoğunlaştığı aylar',
      aylar.take(3).map((a) => '${a.ay} ${mnFark(a.fark)}').join(', '),
    ));
  }
  final f = c.fark('Faaliyet giderleri').abs() + c.fark('Faaliyet dışı net').abs();
  if (f < 1000) {
    l.add(('Değişmeyen kalemler', 'Faaliyet giderleri ve faaliyet dışı gelir-giderler iki senaryoda aynıdır; fark yalnızca satış ve satış maliyetinden doğar.'));
  }
  return l;
}
