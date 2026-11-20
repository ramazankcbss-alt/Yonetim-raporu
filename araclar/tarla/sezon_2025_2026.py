#!/usr/bin/env python3
"""2025-2026 sezonu ekiliş verisi: "Yerlerim Gücel 03.12.2025.kmz" → assets/veri/tarla_2025_2026.json

Kullanım: python3 -I kmz_oku.py doc.kml pm.json && python3 -I sezon_2025_2026.py pm.json CIKTI.json
KMZ'deki etiketler (nokta adları) ekiliş beyanı, alan çizimleri (poligon) ölçülen alan olarak alınır.
KVKK: dosyada kişi adı yoktur; kişi adı içeren etiket çıkarsa alınmaz.
"""
import json, sys, math
L = json.load(open(sys.argv[1]))
P = {}
for x in L:
    if x['tur'] == 'alan':
        P.setdefault((x['yol'].split(' / ')[1], x['ad']), []).append(x)

def poly(ciftlik, ad, i=0):
    return P[(ciftlik, ad)][i]

def sade(c, n=48):
    if len(c) <= n: return [[round(a, 6), round(b, 6)] for a, b in c]
    k = len(c) / n
    return [[round(c[int(i * k)][0], 6), round(c[int(i * k)][1], 6)] for i in range(n)]

def p(ad, tip, urunler, beyan, kaynak, not_='', i=0):
    k = poly(*kaynak, i=i) if kaynak else None
    return dict(ad=ad, tip=tip, urunler=[[u, d] for u, d in urunler], beyan=beyan,
                olculen=round(k['olcu'] / 1000, 1) if k else None,
                etiket=k['ad'] if k else '', not_=not_, koord=sade(k['koord']) if k else [])

S, A, T, F = 'ŞEKERSÜT', 'ASLIM', 'TAŞAĞIL', 'FİDANLIK'
ciftlikler = [
 dict(ad='Şekersüt', parseller=[
   p('1. pivot', 'pivot', [('Buğday', 800)], 800, (S, '1.pivot')),
   p('2. pivot', 'pivot', [('Buğday', 200)], 200, (S, '2. pivot Buğday 200 da')),
   p('3. pivot', 'pivot', [('Buğday', 400)], 400, (S, '3. Pivot 400 da Buğday')),
   p('4. pivot', 'pivot', [('Şeker pancarı', 400)], 400, (S, '4. Pivot 400 da. Pancar')),
   p('5. pivot', 'pivot', [('Buğday', 300)], 300, (S, '5.Pivot 300 da. S.Mısır'),
     'Haritadaki işaret "Buğday 300 da", alan çizimi "S.Mısır 300 da" yazıyor; ürün teyit edilmeli.'),
   p('1. parsel', 'parsel', [('Silajlık mısır', 270)], 270, (S, 'MISIR 270 da.')),
   p('2. parsel', 'parsel', [('Silajlık mısır', 100)], 100, (S, 'Mısır 100 da.')),
   p('3. parsel', 'parsel', [('Silajlık mısır', 140)], 140, (S, '3. parsel Mısır 140 da')),
   p('4. parsel', 'parsel', [('Silajlık mısır', 70)], 70, (S, '4.parsel Mısır 70 da.')),
   p('5. parsel', 'parsel', [('Silajlık mısır', 80)], 80, (S, '5. parsel 80 da. Mısır')),
   p('6. parsel', 'parsel', [('Silajlık mısır', 70)], 70, (S, '6. Mısır 70 da.')),
   p('7. parsel', 'parsel', [('Şeker pancarı', 270)], 270, (S, '7.Parsel 270 da. Pancar')),
  ], tesis=dict(kuyu=11, hayvansalKuyu=1),
  notlar=['Haritadaki "AÇIKLAMA" tablosu: mısır silajı 1.000, arpa danelik 570, buğday danelik 400, tritikale danelik 1.610, yonca 950; toplam 4.530 da. Bu tablo parsel etiketleriyle uyuşmuyor (eski sezon ya da başka bir plan olabilir).']),
 dict(ad='Aslım', parseller=[
   p('1. pivot', 'pivot', [('Arpa', 450)], 450, (A, '1.pivot'), 'Pivot uzunluğu 407 m'),
   p('2. pivot', 'pivot', [('Yonca', 470)], 470, (A, '2.pivot'), 'Açıklama: "Survivor arpa"; pivot uzunluğu 385 m'),
   p('3. pivot', 'pivot', [('Yonca', 470)], 470, (A, '3.pivot'), '2024 güz döneminde ekildi'),
   p('4. pivot', 'pivot', [('Şeker pancarı', 400)], 400, (A, '4.pivot')),
   p('5. pivot', 'pivot', [("4'lü karışım (yem bitkisi)", 210), ('Silajlık mısır (2. ürün)', 210)], 460, (A, '5.pivot'),
     "Etiket: \"460 da. 210 da 4'lü karışım 2. ekim mısır\"; kalan 250 da'nın ürünü yazılmamış. Pivot uzunluğu 380 m"),
   p('6. pivot', 'pivot', [('Yonca', 470)], 470, (A, '6.pivot'), 'Pivot uzunluğu 380 m'),
   p('7. pivot', 'pivot', [('Arpa', 250), ('Buğday', 250)], 500, (A, '7.pivot')),
   p('8. pivot', 'pivot', [('Buğday', 290), ('Arpa', 120)], 410, (A, '8.pivot')),
   p('1. ara parsel', 'parsel', [('Buğday', 100)], 100, (A, '1. parsel')),
   p('2. ara parsel', 'parsel', [('Şeker pancarı', 90)], 90, (A, '2.parsel 90 da. Pancar')),
   p('3. ara parsel', 'parsel', [('Şeker pancarı', 200)], 200, (A, '3. Parsel 200 da. Pancar')),
   p('4. ara parsel', 'parsel', [('Şeker pancarı', 155)], 155, (A, '4.Parsel 155 da. Pancar')),
   p('Buğday parseli', 'parsel', [('Buğday', 120)], 120, (A, 'Buğday 120 da.')),
   p('Arpa parseli', 'parsel', [('Arpa', 285)], 285, (A, '285 da. Arpa')),
   p('1. ekim mısır parseli', 'parsel', [('Silajlık mısır', 140)], 140, (A, '1. Ekim mısır 200 da.'),
     'İşaret "140 da", alan çizimi "200 da" yazıyor.'),
   p('Boş alan (135 da)', 'bos', [], 135, (A, 'Boş alan 135 da.')),
   p('Boş alan (70 da)', 'bos', [], 70, (A, 'Boş alan 70 da.')),
   p('Boş alan (30 da)', 'bos', [], 30, (A, 'Boş alan 30 da.')),
  ], tesis=dict(kuyu=15, direk=9), notlar=['15 kuyudan biri gözlem kuyusu, biri içme suyu kuyusu; OG hatları ve yeraltı enerji hatları haritada çizili.']),
 dict(ad='Taşağıl', parseller=[
   p('Tarım alanı (400 da)', 'parsel', [('Patates', 400)], 400, (T, 'TARIM ALANI 400 DEKAR')),
   p('Tarım alanı (50 da)', 'parsel', [('Patates', 50)], 50, (T, 'TARIM ALANI 50 DEKAR')),
   p('Pancar parseli', 'parsel', [('Şeker pancarı', 300)], 300, (T, 'Pancar 300 DA.')),
  ], tesis={}, notlar=['Çiftlik sınırı haritada 1.001 da olarak ölçülüyor (tarım alanları dahil).']),
 dict(ad='Fidanlık', parseller=[
   p('1. parsel', 'parsel', [('Buğday', 80)], 80, (F, '1. Mısır silajı 80 da.'),
     'İşaret "Buğday 80 da", alan çizimleri "Mısır silajı 80 da" yazıyor (iki üst üste çizim).'),
   p('2. parsel', 'parsel', [('Buğday', 70)], 70, (F, '2. Parsel Buğday 70 da.'), 'Aynı yerde "Arpa 70 da" çizimi de var.'),
   p('3. parsel', 'parsel', [('Silajlık mısır', 100)], 100, (F, '3. Mısır 100 da.'),
     'Aynı yerde "Arge deneme buğday / toprak dökme alanı 100 da" çizimi de var.'),
   p('4. parsel', 'parsel', [('Arpa', 100)], 100, (F, '4. Arpa  100 da.'), 'Aynı yerde "Buğday 100 da" çizimi de var.'),
   p('5. parsel', 'parsel', [('Arpa', 210)], 210, (F, '5. Arpa 210 da.'), 'Aynı yerde "Buğday 210 da" çizimi de var.'),
   p('6. parsel', 'parsel', [('Arpa', 160)], 160, (F, 'Arpa 180 da.'), 'İşaret "160 da", alan çizimi "180 da" yazıyor.'),
   p('7. parsel', 'parsel', [('Arpa', 150)], 150, (F, '7. Parsel Arpa 150 da.')),
   p('Deneme alanı', 'diger', [('Deneme', 15)], 15, (F, 'Deneme alanı 15 da.')),
   p('Ceviz ve üzüm', 'diger', [('Ceviz ve üzüm', 42)], 42, (F, 'Ceviz ve Üzüm yeri 42 da.')),
   p('Pancar toprağı döküm alanı', 'diger', [], 0, (F, 'pancar toprağı'), 'Tel örgü ile çevrili'),
  ], tesis=dict(kuyu=5), notlar=['Fidanlıkta parseller iki kez çizilmiş (farklı ürün adlarıyla); ürün olarak parsel işaretleri esas alındı.']),
 dict(ad='Pangev (Erentepe)', parseller=[p('Ahır alanı', 'diger', [], 80, ('PANGEV A.Ş', 'Pangev ahır alanı'))], tesis={}, notlar=[]),
 dict(ad='Pankent (Gevrekli)', parseller=[
   p('Gevrekli parseli', 'parsel', [], 27, ('PANKENT A.Ş GEVREKLİ', 'Gevrekli Parsel 27 da.'), 'Ürün belirtilmemiş'),
   p('Ahır alanı', 'diger', [], 47, ('PANKENT A.Ş GEVREKLİ', 'Gevrekli ahır alanı 47 da.'))], tesis={}, notlar=[]),
]
out = dict(sezon='2025-2026', kaynak='Yerlerim Gücel 03.12.2025.kmz', tarih='2025-12-03', ciftlikler=ciftlikler)
json.dump(out, open(sys.argv[2], 'w'), ensure_ascii=False, separators=(',', ':'))
import os; print(os.path.getsize(sys.argv[2]))
for c in ciftlikler:
    t = {}
    for x in c['parseller']:
        for u, d in x['urunler']: t[u] = t.get(u, 0) + d
    print(c['ad'], t)
