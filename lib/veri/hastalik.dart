import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'model.dart';

/// Hastalık dağılımı: ay × çiftlik × cins × hastalık × sonuç (adet).
class HastalikKaydi {
  const HastalikKaydi(this.yil, this.ay, this.ciftlik, this.cins, this.hastalik, this.sonuc, this.adet);
  final int yil, ay;
  final String ciftlik, cins, hastalik, sonuc;
  final int adet;
}

const sonuclar = ['Ölüm', 'Tedavi (kalım)', 'Kuru', 'Kesim', 'İmha'];
const aylar = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

/// Paketlenmiş arşiv (assets/veri/hastalik.json) çözümleyici.
List<HastalikKaydi> hastalikJsonCoz(String metin) {
  final j = jsonDecode(metin) as Map<String, dynamic>;
  List<String> l(String k) => (j[k] as List).cast<String>();
  final cf = l('ciftlik'), cins = l('cins'), h = l('hastalik'), s = l('sonuc');
  return [
    for (final r in (j['kayit'] as List).cast<List>())
      HastalikKaydi(r[0] as int, r[1] as int, cf[r[2] as int], cins[r[3] as int], h[r[4] as int], s[r[5] as int], r[6] as int),
  ];
}

/// Bilgi Bankası'na sonradan eklenen "Hastalık kaydı" satırları
/// (Gösterge: "Cins · Hastalık · Sonuç", Değer: adet).
HastalikKaydi? gecmistenHastalik(GecmisVeri x) {
  if (x.konu != 'Hastalık kaydı') return null;
  final p = x.gosterge.split(' · ');
  final ay = aylar.indexOf(x.ay) + 1;
  if (p.length != 3 || ay == 0 || x.yilNo == 0) return null;
  return HastalikKaydi(x.yilNo, ay, x.alan, p[0], p[1], p[2], (x.sayi ?? 1).round());
}

Future<List<HastalikKaydi>> hastalikYukle(List<GecmisVeri> gecmis) async {
  var arsiv = <HastalikKaydi>[];
  try {
    arsiv = hastalikJsonCoz(await rootBundle.loadString('assets/veri/hastalik.json'));
  } catch (_) {}
  // Sonradan gelen satırlar arşivde olmayan (yıl, ay, çiftlik) dilimlerini tamamlar.
  final var_ = {for (final k in arsiv) '${k.yil}|${k.ay}|${k.ciftlik}'};
  final ek = [
    for (final x in gecmis)
      if (gecmistenHastalik(x) case final k? when !var_.contains('${k.yil}|${k.ay}|${k.ciftlik}')) k,
  ];
  return [...arsiv, ...ek];
}

/// Hastalık → etken ve önleme tedbirleri (genel bilgi; çiftlik veterineri ile teyit edilir).
class Tedbir {
  const Tedbir(this.etken, this.tedbirler);
  final String etken;
  final List<String> tedbirler;
}

const _genel = Tedbir('Kayıtta teşhis yazılmamış / sınıflandırılamadı', [
  'Her vakada teşhis, tedavi ve sonuç (iyileşti/kuru/kesim/ölüm) eksiksiz yazılsın.',
  'Ölümlerde otopsi istenip sonucu kayda geçsin; tekrar eden nedenler ancak böyle görülür.',
]);

const tedbirHaritasi = <String, Tedbir>{
  'Mastit': Tedbir('Staph. aureus, Strep. agalactiae/uberis, E. coli, Klebsiella, mikoplazma; hijyen ve sağım kusurları', [
    'Sağım öncesi ön daldırma + kağıt havlu ile tek tek kurulama; sağım sonrası son daldırma.',
    'Sağım makinesi vakum/pulsatör kontrolü 6 ayda bir; meme lastikleri zamanında değişsin.',
    'Yataklık kuru ve temiz; serbest durak ve gezinti alanı günde en az 2 kez kazınsın.',
    'Kuruya çıkarmada kuru dönem tedavisi + meme başı tıkacı; klinik vakalara kültür-antibiyogram.',
    'Kronik (3+ atak) ve kör memeli inekler için ayıklama planı; SHS (somatik hücre) aylık takip.',
  ]),
  'Topallık/ayak': Tedbir('Digital dermatit (Treponema), tırnak taban ülseri, beyaz çizgi hastalığı, laminitis, ökçe çürüğü', [
    'Yılda 2 kez rutin tırnak kesimi; topal inek 48 saat içinde bakılsın.',
    'Ayak banyosu (formalin/bakır sülfat) haftada 2–3 kez, çözelti 150–200 geçişte yenilensin.',
    'Zeminde kayma, çukur ve gübre birikimi giderilsin; bekleme alanında süre kısaltılsın.',
    'Asidozu önleyen rasyon (yeterli kaba yem/efektif lif), biotin-çinko takviyesi.',
    'Aylık topallık skorlaması yapılıp kayda geçsin.',
  ]),
  'Solunum/pnömoni': Tedbir('BRSV, PI-3, IBR, BVD virüsleri; Mannheimia, Pasteurella, Histophilus, Mycoplasma bovis', [
    'Buzağı ve dana barınaklarında hava akımı var, cereyan yok; amonyak kokusu olmasın.',
    'Solunum karma aşıları (IBR-BVD-BRSV-PI3, Pasteurella) programa göre, satın alınan hayvana karantina + aşı.',
    'Kolostrum: ilk 2 saatte 4 litre, 12 saatte toplam 6 litre; pasif bağışıklık kontrolü.',
    'Grup karışımı, nakil ve sütten kesim aynı zamana gelmesin; aşırı kalabalık önlensin.',
    'İlk ateşte (39,5°C üstü) erken tedavi; ölümlerde akciğer otopsisi.',
  ]),
  'İshal': Tedbir('E. coli (K99), Rota/Corona virüs, Cryptosporidium, Salmonella, Coccidia; kolostrum yetersizliği', [
    'Kolostrum kalitesi refraktometre ile ölçülsün (≥%22 Brix); ilk 2 saatte içirilsin.',
    'Gebe ineklere doğumdan 3–6 hafta önce Rota-Corona-E. coli aşısı.',
    'Biberon/kova her kullanımdan sonra yıkanıp dezenfekte edilsin; süt sıcaklığı sabit.',
    'Doğumhane ve kulübeler her doğum/buzağı arası temizlik + kireçleme.',
    'İshalli buzağıya erken ağızdan elektrolit; sütü kesmeden ayrı besleme.',
  ]),
  'Metrit': Tedbir('Trueperella pyogenes, E. coli, Fusobacterium; son atılmaması, güç doğum, hijyensiz müdahale', [
    'Doğumhane temiz ve tek tip; doğum müdahalesi eldiven + dezenfeksiyon ile.',
    'Geçiş dönemi rasyonu (DCAD, enerji) ile süt humması ve son atılmaması önlensin.',
    'Doğum sonrası 10 gün ateş takibi; kokulu akıntıya erken tedavi.',
    'Vücut kondisyonu kuruya çıkışta 3,0–3,5 aralığında tutulsun.',
  ]),
  'Son atılmaması (retensiyo)': Tedbir('Selenyum/E vitamini eksikliği, hipokalsemi, ikiz/güç doğum, abort', [
    'Kuru dönemde Se-E vitamini ve mineral takviyesi.',
    'Geçiş dönemi kalsiyum dengesi (anyonik tuz) uygulansın.',
    'Doğum sonrası 12 saatte atılmayan son kayda geçsin, elle zorla çıkarılmasın.',
  ]),
  'Süt humması/hipokalsemi': Tedbir('Doğum çevresi kan kalsiyumu düşüşü; yaşlı ve yüksek verimli inek', [
    'Kuru dönemin son 3 haftasında anyonik rasyon ve idrar pH takibi.',
    'Riskli ineklere doğumda ağızdan kalsiyum bolusu.',
    'Kuru dönemde aşırı kalsiyum ve potasyumdan kaçınılsın.',
  ]),
  'Ketoz': Tedbir('Negatif enerji dengesi; doğum sonrası yağ mobilizasyonu', [
    'Doğum sonrası ilk 2 hafta kan BHB taraması.',
    'Kuruda aşırı yağlanma önlensin; geçiş döneminde yem tüketimi izlensin.',
    'Riskli ineklere propilen glikol desteği.',
  ]),
  'Abomasum deplasmanı': Tedbir('Doğum sonrası düşük kaba yem tüketimi, hipokalsemi, ketoz', [
    'Doğum sonrası rasyonda yeterli uzun lifli kaba yem; ani rasyon değişikliği yok.',
    'Hipokalsemi ve ketoz kontrolü ile birlikte ele alınsın.',
  ]),
  'Blat (şişkinlik)': Tedbir('Yonca/taze yeşil ot ile köpüklü gaz, tahıl fazlası, yemek borusu tıkanıklığı', [
    'Rasyon geçişleri 2–3 haftaya yayılsın; aç hayvan taze yoncaya salınmasın.',
    'Yem karışımında partikül boyutu ve kesif oranı kontrol edilsin.',
  ]),
  'Enterit/enterotoksemi': Tedbir('Clostridium perfringens tip A-D, ani rasyon değişikliği', [
    'Clostridium (enterotoksemi) aşısı programa göre tekrarlansın.',
    'Kesif yem artışı kademeli; besi başlangıcında adaptasyon dönemi.',
  ]),
  'Septisemi': Tedbir('Kolostrum yetersizliği, göbek enfeksiyonu üzerinden E. coli/Salmonella', [
    'Göbek doğumda %7 iyot ile batırılsın, 12 saat sonra tekrar.',
    'Kolostrum ve doğumhane hijyeni ishal tedbirleriyle aynı.',
  ]),
  'Göbek iltihabı': Tedbir('Kirli doğum ortamı, göbek dezenfeksiyonu eksikliği', [
    'Doğumda göbeğe iyot daldırma, kulübe yataklığı kuru.',
    'Göbek ilk hafta günlük kontrol edilsin.',
  ]),
  'Günsüz/zayıf doğum': Tedbir('Annenin beslenme/hastalığı, ikiz, BVD gibi enfeksiyonlar', [
    'Gebe düve/inek kondisyon ve mineral programı; BVD aşısı ve PI hayvan taraması.',
    'Zayıf doğana ilk saatte kolostrum (gerekirse sonda) ve ısıtma.',
  ]),
  'Güç doğum': Tedbir('İri buzağı, erken tohumlanmış/küçük düve, yanlış duruş', [
    'Düveler hedef canlı ağırlıkta tohumlansın; kolay doğum boğası seçilsin.',
    'Doğum ekibine müdahale zamanlaması eğitimi.',
  ]),
  'Ölü doğum': Tedbir('Güç doğum, enfeksiyon (BVD, Neospora, Leptospira), beslenme', [
    'Doğumların gözetimi; uzayan doğuma zamanında müdahale.',
    'Abort/ölü doğumlardan laboratuvar örneği.',
  ]),
  'Abort': Tedbir('Brusella, BVD, IBR, Neospora, Leptospira; küflü yem, stres', [
    'Brusella ve şap aşıları resmi programla; abortlar İl Müdürlüğüne bildirilsin.',
    'Fetüs ve plasenta laboratuvara; küflü silaj yedirilmesin.',
    'Köpek-kedi girişinin yem ve doğumhaneye engellenmesi (Neospora).',
  ]),
  'İnfertilite': Tedbir('Metrit, negatif enerji, kızgınlığın kaçırılması, mineral eksikliği', [
    'Doğum sonrası 30. gün rahim muayenesi, senkronizasyon programı.',
    'Kızgınlık takibi (aktivite ölçer) ve tohumlama kayıtları düzenli.',
  ]),
  'TB şüphesi': Tedbir('Mycobacterium bovis; enfekte hayvanla temas', [
    'Resmi tüberkülin testleri aksatılmasın; pozitifler mevzuata göre ayrılsın.',
    'Satın alınan hayvana karantina ve test; kesimde lezyon bulgusu kayda geçsin.',
  ]),
  'Kan paraziti': Tedbir('Theileria, Babesia, Anaplasma; kene', [
    'Kene sezonunda (bahar-yaz) dış parazit uygulaması ve ahır çevresi ilaçlama.',
    'Theileria aşısı veteriner önerisine göre.',
  ]),
  'Yara/pişik': Tedbir('Kaba zemin, sıkışma, kirli/ıslak yataklık, sinek', [
    'Demir aksam, kapı ve yemlikte keskin kenarlar giderilsin.',
    'Yataklık kuru tutulsun; sinek mücadelesi.',
  ]),
  'Kırık/travma': Tedbir('Kaygan zemin, sıkışma, kavga, kızgınlıkta atlama, nakil', [
    'Kaygan zemine oluk/kauçuk; kapı ve geçitlerde sıkışma noktaları düzeltilsin.',
    'Aşırı kalabalık önlensin; nakil ve yüklemede rampa kontrolü.',
  ]),
  'Felç': Tedbir('Süt humması, doğum felci, travma, sinir hasarı', [
    'Hipokalsemi önlemleri; yatan ineğe ilk saatlerde kaldırma desteği ve yumuşak zemin.',
  ]),
  'Göz': Tedbir('Moraxella bovis (pembe göz), sinek, toz, güneş', [
    'Sinek mücadelesi; tozlu yemlerin nemlendirilmesi; hasta hayvan ayrılsın.',
  ]),
  'Apse': Tedbir('Hijyensiz enjeksiyon, yaralanma, Trueperella', [
    'Her hayvana temiz iğne; enjeksiyon boyuna kas içi kurala uygun.',
  ]),
  'Eklem/artrit': Tedbir('Göbek enfeksiyonu yayılması, Mycoplasma, travma', [
    'Göbek bakımı ve kolostrum; mikoplazmalı sütün buzağıya verilmemesi.',
  ]),
  'Doğum travması/yırtık': Tedbir('Kaba/yanlış doğum müdahalesi, iri buzağı', [
    'Doğum müdahale eğitimi; zincir ile çekmede doğru yön ve ritim.',
  ]),
  'Prolapsus (sarkma)': Tedbir('Güç doğum, hipokalsemi, aşırı ıkınma', [
    'Hipokalsemi önlemleri; prolapsus görülen hayvan derhal veterinere.',
  ]),
  'Anafilaktik şok (aşı sonrası)': Tedbir('Aşı/ilaç reaksiyonu', [
    'Aşılama sonrası 30 dk gözlem; adrenalin el altında; seri numarası kayda.',
  ]),
  'Karaciğer yetmezliği/dejenerasyon': Tedbir('Yağlı karaciğer, kelebek (Fasciola), mikotoksin', [
    'Kuruda aşırı yağlanma önlensin; yılda 2 iç parazit programı; yem mikotoksin analizi.',
  ]),
  'Sindirim bozukluğu': Tedbir('Rasyon hatası, bozuk yem, asidoz', [
    'Silaj ve yem kalitesi kontrolü; rasyon değişikliği kademeli.',
  ]),
  'İndigesyon': Tedbir('Rasyon hatası, bozuk yem, asidoz', [
    'Silaj ve yem kalitesi kontrolü; rasyon değişikliği kademeli.',
  ]),
  'Mide/bağırsak': Tedbir('Yabancı cisim, asidoz, bağırsak düğümlenmesi', [
    'Yem karma vagonunda mıknatıs; rasyonda efektif lif yeterli.',
  ]),
  'İdrar yolu/taş': Tedbir('Besi danasında yüksek fosfor/düşük kalsiyum, az su', [
    'Rasyonda Ca:P en az 2:1, amonyum klorür desteği; temiz ve bol su.',
  ]),
  'Durgunluk/iştahsızlık': Tedbir('Başlangıç belirtisi; çok sayıda hastalık', [
    'Günlük ateş/yem tüketimi kontrolü ile erken teşhis.',
  ]),
  'Peritonit': Tedbir('Yabancı cisim (çivi, tel), abomasum ülseri', [
    'Yem hazırlığında mıknatıs ve tel/çivi kontrolü.',
  ]),
  'Verim düşüklüğü': Tedbir('Kronik mastit, topallık, yaş, beslenme', [
    'Verim ve sağlık kayıtları birlikte değerlendirilip ayıklama kararı verilsin.',
  ]),
  'Ani ölüm': Tedbir('Enterotoksemi, şarbon, zehirlenme, kalp', [
    'Mutlaka otopsi; şarbon şüphesinde leşe dokunmadan resmi bildirim.',
  ]),
};

Tedbir tedbirBul(String hastalik) => tedbirHaritasi[hastalik] ?? _genel;
