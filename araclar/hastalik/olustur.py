"""Hastalık Dağılımı arşivini (assets/veri/hastalik.json) yalnızca Drive'daki
"SAĞLIK RAPORLARI" klasörünün dosyalarından üretir.

Kullanım:  python3 olustur.py <xlsx klasörü> <çıktı.json>

Klasördeki dosyalar şu adlarla beklenir (Drive'dan .xlsx olarak indirilir):
  sek_revir_<yıl>, sek_buz_<yıl>, sek_dogol_<yıl>, sek_kesim_<yıl>_<ay>, fethiye_2026,
  aslim_<yıl>, pangev_<yıl>
Eksik dosya atlanır.

KVKK: Çıktıda yalnızca yıl, ay, (gün,) çiftlik, hayvan cinsi, hastalık grubu, sonuç ve
adet bulunur.

Çıktı: "kayit" aylık sayımdır; "gunluk" aynı sayımın vakanın kaynakta ilk görüldüğü
güne göre kırılımıdır (gün 0 = kaynakta tarih yok). Her ayın günlük toplamı aylık
sayıya eşittir. Revir listelerinde gün, "GG.AA.YYYY REVİR …" gün başlığından; buzağılık
listelerinde ilk sütundaki tarihten; diğer listelerde satır tarihinden alınır. Küpe/tasma numaraları yalnızca aynı vakayı tekrar saymamak için
bellekte kullanılır; personel, veteriner ve eksper adları hiç okunmaz.

Sayım birimi "vaka"dır:
  - Günlük doz listelerinde (revir, buzağılık, Pangev tedavi) aynı hayvanın aynı
    ay içindeki aynı hastalık grubu tek vaka sayılır.
  - Aslım tedavi satırında "24 DANA" gibi toplu kayıtlar o kadar vaka sayılır.
  - Ölüm satırı = 1 ölüm. Kesim listelerinde yalnızca hastalık/zorunlu
    kesimler alınır; normal kesim ve besi sonu kesimler alınmaz.
"""
import datetime as dt
import glob
import json
import os
import re
import sys
import warnings

import openpyxl

warnings.filterwarnings('ignore')

AYLAR = ['OCAK', 'ŞUBAT', 'MART', 'NİSAN', 'MAYIS', 'HAZİRAN', 'TEMMUZ',
         'AĞUSTOS', 'EYLÜL', 'EKİM', 'KASIM', 'ARALIK']
AY_KISA = {'AĞUTOS': 8}


def buyuk(s):
    return str(s or '').replace('i', 'İ').replace('ı', 'I').upper().strip()


# Teşhis metni → hastalık grubu (ilk eşleşen kural geçerli; sıra önemlidir).
KURALLAR = [
    ('Anafilaktik şok (aşı sonrası)', r'ANAF[İI]LAK|AŞI SONRASI'),
    ('TB şüphesi', r'\bTB\b|TÜBERK|TUBERK|TBC'),
    ('Kan paraziti', r'THE[İI]?LER|BABES|ANAPLAS|KAN PARAZ'),
    ('Abomasum deplasmanı', r'DEPLAS|DEPLES|ABOMAS|\bLDA\b|\bRDA\b|ŞİRDEN'),
    ('Süt humması/hipokalsemi', r'HUMMA|HİPO ?KALS|HIPOKALS|SÜT HUM|YATALAK'),
    ('Ketoz', r'KETOZ|KETOS|KETON'),
    ('Son atılmaması (retensiyo)', r'RETENS|SON ATIL|ATILMAYAN|SONU AT'),
    ('Prolapsus (sarkma)', r'PROLAP|SARKMA'),
    ('Ölü doğum', r'ÖLÜ DOĞ'),
    ('Abort', r'ABORT|YAVRU AT|ATIK|NEOSPORA'),
    ('Leptospirozis', r'LEPTOS'),
    ('Şap', r'\bŞAP\b'),
    ('Güç doğum', r'GÜÇ DOĞ|DİSTO|DISTO|ZOR DOĞ|SEZARYEN'),
    ('Doğum travması/yırtık', r'YIRTIK|DOĞUM TRAV|VAJ.*YIR'),
    ('Son atılmaması (retensiyo)', r'UTERUS.*YAPIŞ'),
    ('Prolapsus (sarkma)', r'PROLAB'),
    ('Mastit', r'MAST[İI]T|MEME|KANLI|SAĞ ÖN|SOL ÖN|SAĞ ARKA|SOL ARKA|KÖR|GÖĞÜS|GÖGÜS|SUBKL|PEYNİR'),
    ('Metrit', r'METR[İI]T|METİR|MERİT|ENDOMET|AKINTI|P[İI]YOMET'),
    ('İnfertilite', r'İNFERT|INFERT|KİST|KIST|GEBE KAL|DÖL|ANÖSTR|ANOSTR|REPEAT|BOŞ KAL'),
    ('Solunum/pnömoni', r'PN[EÖOU]*M|PN\w*MON|PNÖM|PNOM|PNEUM|SOLUNUM|HIRILTI|AKCİĞER|AKÇİĞER|AMF[İI]ZEM|BRONŞ|ÖKSÜR|NEFES'),
    ('İshal', r'İSHAL|ISHAL|D[İI]ARE|DEH[İI]DRAS'),
    ('Enterit/enterotoksemi', r'ENTER[İI]T|ENTEROTOK|ENTERETOK|GASTRO'),
    ('Göbek iltihabı', r'GÖBEK|OMFAL|OMFOL|OMPHAL'),
    ('Septisemi', r'SEPT[İI]'),
    ('Peritonit', r'PER[İI]TON'),
    ('Blat (şişkinlik)', r'TİMPAN|TIMPAN|BLAT|ŞİŞKİNLİK|GAZ'),
    ('İndigesyon', r'İNDİGES|INDIGES|KONS?T[İI]P|KABIZ|ASİDOZ|ASIDOZ'),
    ('Sindirim bozukluğu', r'SİNDİRİM|HAZIMSIZ|RUMEN'),
    ('Mide/bağırsak', r'MİDE|BAĞIRSAK|BARSAK|ATRES|İNVAJ|VOLVUL|TIKANIK|KOLİK|SEKUM|SECUM|OBST'),
    ('Topallık/ayak', r'TOPAL|AYAK|TIRNAK|ÖKÇE|DERMAT|PANARİ|LAMİNİT|YÜRÜY|HOOF|TABAN ÜLSER'),
    ('Eklem/artrit', r'ARTR[İI]T|ARTH|ART[İI]T[İI]S|EKLEM'),
    ('Kırık/travma', r'KIRIK|KIRIĞ|TRAVMA|SIKIŞ|ÇIKIK|LUX|LUKZ|KOPMA|EZİL|BURKUL|DARBE|DÜŞME|ATLAMA|ÇATI AYIR'),
    ('Yatma/kalkamama', r'YATT|YATMIŞ|YATI+\b|KALKAMI|KALKMADA'),
    ('Felç', r'FELÇ|PARAL|PARAPL|SİNİRSEL'),
    ('Kalp yetmezliği', r'KALP'),
    ('Karaciğer yetmezliği/dejenerasyon', r'KARAC[İI]ĞER|KARAÇİĞER|KARACIĞER|HEPAT|DEJENER|DEJERENA'),
    ('İdrar yolu/taş', r'İDRAR|IDRAR|S[İI]ST[İI]T|ÜROL|TAŞ|ANÜRİ|NEFRİT'),
    ('Apse', r'APSE|ABSE'),
    ('Yara/pişik', r'YARA|PİŞİK|PIŞIK|KAŞINT|UYUZ|MANTAR'),
    ('Göz', r'GÖZ|KERAT|KONJ'),
    ('Kulak', r'KULAK'),
    ('Kanama', r'KANAMA|HEMOR|DAMAR'),
    ('Şişlik', r'ŞİŞ'),
    ('Ödem', r'ÖDEM'),
    ('Ateş', r'ATEŞ|ATES'),
    ('Durgunluk/iştahsızlık', r'DURGUN|İŞTAH|ISTAH|HALSİZ|YEM YEME|KAŞEKT|GELİŞİM BOZ|GENEL DURUM|TÜYÜ KARIŞIK'),
    ('Günsüz/zayıf doğum', r'GÜNSÜZ|ZAYIF|PREMAT|ERKEN DOĞ'),
    ('Doğumsal anomali', r'ANOMAL|KONJEN|SAKAT DOĞ|FREEMART'),
    ('Ani ölüm', r'AN[İI] ÖLÜM'),
    ('Şok', r'ŞOK'),
    ('Yaşlılık', r'YAŞLI'),
    ('Verim düşüklüğü', r'VER[İI]M|SÜTÜ? DÜŞÜK|SÜTÜ YOK|DAMIZLIK DEĞER|DAM\. DEĞER'),
]
DERLENMIS = [(ad, re.compile(d)) for ad, d in KURALLAR]
BOS = re.compile(r'^(NONE|-+|\.|0|TESP[İI]T ED[İI]LEMED[İI].*|HASTALIK TESP[İI]T.*)?$')


# Teşhis olmayan rutin kayıtlar (aşı, protokol, kontrol, konum, gün başlığı):
# hastalık vakası sayılmaz.
RUTIN = re.compile(r'^(HASTALIK|TEŞHİS|ZYLEX|HİPRA|DOĞUMHANE|DOGUMHANE|DOĞUM PROTOK|SÜT TAKİB|'
                   r'SAĞIMHANEYE SIĞ|DOĞUM YAPTI|DOĞUM HAYVAN|KESİM|FRESH|KAN TEST|KURUYA AYRIL|'
                   r'FATRO|BOYNUZ$|TEMİZ$|SÜTÜNE BAK|SÜTÜ ÖLÇ|EŞ AL|EŞ ATA|GEBE \d|TOHUMLAMANIN|LOHUSA|DOHUMHANE|DOĞUM PROT|SAĞIM YAPILAMA|KURUYA AL|TR\d{6,}|ŞEKERSÜT \d+|[\d.,\s]+$)|KONTROL')


def grup(metin):
    m = buyuk(metin)
    if BOS.match(m):
        return 'Belirtilmemiş'
    if RUTIN.search(m) and not re.search(r'MAST|METR|PN|SOLUNUM|TOPAL|İSHAL', m):
        return 'Belirtilmemiş'
    for ad, d in DERLENMIS:
        if d.search(m):
            return ad
    return 'Diğer'


def tarih(v):
    if isinstance(v, dt.datetime):
        return v.date()
    if isinstance(v, dt.date):
        return v
    m = re.match(r'(\d{1,2})[./](\d{1,2})[./](\d{4})', str(v or '').strip())
    if m:
        try:
            return dt.date(int(m.group(3)), int(m.group(2)), int(m.group(1)))
        except ValueError:
            return None
    return None


def sayfa_ayi(ad):
    a = buyuk(ad)
    for k, v in AY_KISA.items():
        if a.startswith(k):
            return v
    for i, ay in enumerate(AYLAR):
        if a.startswith(ay) or a.endswith(' ' + ay) or (' ' + ay + ' ') in (' ' + a + ' '):
            return i + 1
    return None


def satirlar(ws):
    return [list(r) for r in ws.iter_rows(values_only=True)]


def baslik_bul(rows, *gerekli):
    for i, r in enumerate(rows[:12]):
        h = [buyuk(c) for c in r]
        if all(any(g in x for x in h) for g in gerekli):
            return i, h
    return None, None


def sutun(h, *adlar):
    for ad in adlar:
        for i, x in enumerate(h):
            if ad in x:
                return i
    return None


class Arsiv:
    def __init__(self):
        self.say = {}
        self.gun = {}
        self.vaka = set()

    def ekle(self, yil, ay, ciftlik, cins, hastalik, sonuc, adet=1, anahtar=None, gun=None):
        if not yil or not ay or adet <= 0 or yil < 2015:
            return
        if anahtar is not None:
            k = (yil, ay, ciftlik, hastalik, anahtar)
            if k in self.vaka:
                return
            self.vaka.add(k)
        k = (yil, ay, ciftlik, cins, hastalik, sonuc)
        self.say[k] = self.say.get(k, 0) + adet
        # Günlük kırılım: vakanın ilk görüldüğü gün. Gün, kaynağın ayıyla uyuşmuyorsa
        # "tarihi belirsiz" (0) yazılır; aylık sayım hiçbir durumda değişmez.
        g = gun.day if gun is not None and (gun.year, gun.month) == (yil, ay) else 0
        kg = k + (g,)
        self.gun[kg] = self.gun.get(kg, 0) + adet


def hucre(r, i):
    return r[i] if i is not None and i < len(r) else None


# ---- Şekersüt revir (inek) ----
def sek_revir(a, yol, yil):
    wb = openpyxl.load_workbook(yol, read_only=True, data_only=True)
    for ws in wb.worksheets:
        ay = sayfa_ayi(ws.title)
        if not ay:
            continue
        rows = satirlar(ws)
        bi, h = baslik_bul(rows, 'TASMA', 'TEŞH')
        if bi is None:
            continue
        ct, ck, cte = sutun(h, 'TASMA'), sutun(h, 'KÜPE'), sutun(h, 'TEŞH')
        gun = tarih(hucre(rows[bi - 1], 0)) if bi > 0 else None
        for r in rows[bi + 1:]:
            gb = tarih(hucre(r, 0))
            if gb and hucre(r, ct) in (None, ''):
                gun = gb
                continue
            t = hucre(r, cte)
            kim = hucre(r, ct) or hucre(r, ck)
            if t in (None, '') or kim in (None, '') or buyuk(t) == 'TEŞHİS':
                continue
            g = grup(t)
            if g == 'Belirtilmemiş':
                continue
            m = buyuk(t)
            sonuc = 'Kuru' if re.search(r'KÖR|KURUYA|KURU ÇIK|KURUT', m) else 'Tedavi (kalım)'
            a.ekle(yil, ay, 'Şekersüt', 'İnek', g, sonuc, anahtar=('revir', buyuk(kim)), gun=gun)


# ---- Şekersüt buzağılık tedavi ----
def sek_buz(a, yol, yil):
    wb = openpyxl.load_workbook(yol, read_only=True, data_only=True)
    for ws in wb.worksheets:
        ay = sayfa_ayi(ws.title)
        if not ay:
            continue
        rows = satirlar(ws)
        bi, h = baslik_bul(rows, 'KÜPE', 'HASTALIK')
        if bi is None:
            continue
        ck, cku, ch = sutun(h, 'KÜPE'), sutun(h, 'KULUBE'), sutun(h, 'HASTALIK')
        gun = None
        for r in rows[bi + 1:]:
            gb = tarih(hucre(r, 0))
            if gb:
                gun = gb
            t = hucre(r, ch)
            kim = hucre(r, ck) or hucre(r, cku)
            if t in (None, '') or kim in (None, ''):
                continue
            g = grup(t)
            if g == 'Belirtilmemiş':
                continue
            a.ekle(yil, ay, 'Şekersüt', 'Buzağı', g, 'Tedavi (kalım)', anahtar=('buz', buyuk(kim)), gun=gun)


# ---- Şekersüt doğan ve ölen buzağılar (ölüm bölümü) ----
def sek_dogol(a, yol, yil):
    wb = openpyxl.load_workbook(yol, read_only=True, data_only=True)
    for ws in wb.worksheets:
        if not sayfa_ayi(ws.title):
            continue
        rows = satirlar(ws)
        bi, h = baslik_bul(rows, 'ÖLÜM TAR', 'ÖLÜM SEB')
        if bi is None:
            continue
        cot, cos = sutun(h, 'ÖLÜM TAR'), sutun(h, 'ÖLÜM SEB')
        ck = cot - 3  # ölen buzağının kulak no sütunu
        for r in rows[bi + 1:]:
            t = tarih(hucre(r, cot))
            if not t or hucre(r, ck) in (None, ''):
                continue
            a.ekle(t.year, t.month, 'Şekersüt', 'Buzağı', grup(hucre(r, cos)), 'Ölüm',
                   anahtar=('olum', buyuk(hucre(r, ck))), gun=t)


def cins_grubu(metin, varsayilan='İnek'):
    m = buyuk(metin)
    if re.search(r'BUZAĞI|BUZAGI|İGLO|IGLO|SÜTTEN KES|DOĞUMHANE BUZ', m):
        return 'Buzağı'
    if 'DÜVE' in m:
        return 'Düve'
    if re.search(r'DİŞİ DANA|DISI DANA', m):
        return 'Dişi dana'
    if 'DANA' in m:
        return 'Besi danası'
    if re.search(r'ERKEK|BOĞA', m):
        return 'Besi danası'
    if re.search(r'İNEK|SAĞMAL|KURU|FRESH|YÜKSEK|DÜŞÜK|ORTA|REVİR', m):
        return 'İnek'
    return varsayilan


NORMAL_KESIM = re.compile(r'NORMAL|BES[İI] SONU|BESİ|EKONOM|MALİYET|SATIŞ|EMANET')


# ---- Fethiye (Şekersüt) 2026: ölüm ve kesim listeleri ----
def fethiye(a, yol):
    wb = openpyxl.load_workbook(yol, read_only=True, data_only=True)
    for ws in wb.worksheets:
        ad = buyuk(ws.title)
        rows = satirlar(ws)
        if ad.startswith('ÖLÜM'):
            bi, h = baslik_bul(rows, 'ÖLÜM SEB')
            if bi is None:
                continue
            ct, cg, cs, ck = sutun(h, 'ÖLÜM TAR'), sutun(h, 'GRUB'), sutun(h, 'ÖLÜM SEB'), sutun(h, 'KÜPE')
            for r in rows[bi + 1:]:
                t = tarih(hucre(r, ct))
                if not t:
                    continue
                a.ekle(t.year, t.month, 'Şekersüt', cins_grubu(hucre(r, cg), 'Belirtilmemiş'),
                       grup(hucre(r, cs)), 'Ölüm', anahtar=('olum', buyuk(hucre(r, ck))), gun=t)
        elif ad.startswith('REVİR'):
            # Şekersüt revir dosyasıyla aynı işletme: aynı hayvanın aynı ay/hastalık vakası
            # ('revir', tasma) anahtarıyla bir kez sayılır (revir dosyası önce işlenir).
            bi, h = baslik_bul(rows, 'TEŞH', 'BAŞLANGI')
            if bi is None:
                continue
            cte, cb = sutun(h, 'TEŞH'), sutun(h, 'BAŞLANGI')
            for r in rows[bi + 1:]:
                t, kim, te = tarih(hucre(r, cb)), hucre(r, 0), hucre(r, cte)
                if not t or kim in (None, '') or te in (None, ''):
                    continue
                g = grup(te)
                if g == 'Belirtilmemiş':
                    continue
                m = buyuk(te)
                sonuc = 'Kuru' if re.search(r'KÖR|KURUYA|KURU ÇIK|KURUT', m) else 'Tedavi (kalım)'
                a.ekle(t.year, t.month, 'Şekersüt', 'İnek', g, sonuc, anahtar=('revir', buyuk(kim)), gun=t)
        elif ad.startswith('BUZA'):
            bi, h = baslik_bul(rows, 'KÜPE', 'HASTALIK')
            if bi is None:
                continue
            ck, cku, ch, cb = sutun(h, 'KÜPE'), sutun(h, 'KULUBE'), sutun(h, 'HASTALIK'), sutun(h, 'BAŞLANGI')
            for r in rows[bi + 1:]:
                t, te = tarih(hucre(r, cb)), hucre(r, ch)
                kim = hucre(r, ck) or hucre(r, cku)
                if not t or te in (None, '') or kim in (None, ''):
                    continue
                g = grup(te)
                if g == 'Belirtilmemiş':
                    continue
                a.ekle(t.year, t.month, 'Şekersüt', 'Buzağı', g, 'Tedavi (kalım)', anahtar=('buz', buyuk(kim)), gun=t)
        elif ad.startswith('KESİM'):
            bi, h = baslik_bul(rows, 'KESİM ŞEK', 'HASTALIK')
            if bi is None:
                continue
            ct, cg, chs, ck = sutun(h, 'TARİH'), sutun(h, 'GRUB'), sutun(h, 'HASTALIK'), sutun(h, 'KÜPE')
            for r in rows[bi + 1:]:
                t = tarih(hucre(r, ct))
                neden = buyuk(hucre(r, chs))
                if not t or not neden or NORMAL_KESIM.search(neden):
                    continue
                sonuc = 'İmha' if 'İMHA' in neden else 'Kesim'
                a.ekle(t.year, t.month, 'Şekersüt', cins_grubu(hucre(r, cg)), grup(neden), sonuc,
                       anahtar=('kesim', buyuk(hucre(r, ck))), gun=t)


# ---- Şekersüt Panagro kesim listeleri (2022-11 … 2023-03): hastalık nedenli kesimler ----
def sek_kesim(a, yol, yil, ay):
    wb = openpyxl.load_workbook(yol, read_only=True, data_only=True)
    for ws in wb.worksheets:
        t = tarih(ws.title)
        rows = satirlar(ws)
        bi = 0
        while True:
            bi2, h = baslik_bul(rows[bi:], 'HASTALIK', 'DURUM')
            if bi2 is None:
                break
            bi += bi2
            ck, chs, cd = sutun(h, 'KÜPE'), sutun(h, 'HASTALIK'), sutun(h, 'DURUM')
            for r in rows[bi + 1:]:
                if buyuk(hucre(r, chs)) == 'HASTALIK':
                    break
                neden = hucre(r, chs)
                if neden in (None, ''):
                    continue
                y, m = (t.year, t.month) if t else (yil, ay)
                a.ekle(y, m, 'Şekersüt', cins_grubu(hucre(r, cd)), grup(neden), 'Kesim',
                       anahtar=('kesim', buyuk(hucre(r, ck)) or str(id(r))), gun=t)
            bi += 1


def adet_oku(metin):
    m = re.match(r'\s*(\d{1,4})\s*(KÜPES[İI]Z\s*)?(DANA|BAŞ|HAYVAN|İTHAL|ITHAL|ERKEK|DÜVE)', buyuk(metin))
    return int(m.group(1)) if m else 1


# ---- Aslım (ve 2025 dosyasındaki Taşağıl ölüm sayfası) ----
def aslim(a, yol, yil_dosya):
    wb = openpyxl.load_workbook(yol, read_only=True, data_only=True)
    for ws in wb.worksheets:
        ad = buyuk(ws.title)
        rows = satirlar(ws)
        ciftlik = 'Taşağıl' if 'TAŞAĞIL' in ad else 'Aslım'
        if 'ÖLÜM' in ad:
            bi, h = baslik_bul(rows, 'ÖLÜM TAR')
            if bi is None:
                continue
            ct, co, ca = sutun(h, 'ÖLÜM TAR'), sutun(h, 'OTOPS'), sutun(h, 'AÇIKLAMA')
            for i, r in enumerate(rows[bi + 1:]):
                t = tarih(hucre(r, ct))
                if not t:
                    continue
                neden = hucre(r, co) or hucre(r, ca)
                a.ekle(t.year, t.month, ciftlik, 'Besi danası', grup(neden), 'Ölüm', gun=t)
        elif ad.startswith('KESİM'):
            bi, h = baslik_bul(rows, 'KESİM TAR')
            if bi is None:
                continue
            ct, ch, cd, ctp, ca = (sutun(h, 'KESİM TAR'), sutun(h, 'HAYVAN B'), sutun(h, 'KESİM DUR'),
                                   sutun(h, 'KESİM TİP'), sutun(h, 'AÇIKLAMA'))
            for r in rows[bi + 1:]:
                t = tarih(hucre(r, ct))
                tur = buyuk(hucre(r, cd)) + ' ' + buyuk(hucre(r, ctp))
                if not t or not re.search(r'ZOR|ACİL|ACIL|SİGORTA|SIGORTA|HASTA', tur):
                    continue
                a.ekle(t.year, t.month, ciftlik, 'Besi danası', grup(hucre(r, ca)), 'Kesim',
                       adet_oku(hucre(r, ch)), gun=t)
        elif ad.startswith('TEDAVİ'):
            bi, h = baslik_bul(rows, 'TEŞH')
            if bi is None:
                continue
            ct, ck, cte = sutun(h, 'TARİH'), sutun(h, 'KÜPE'), sutun(h, 'TEŞH')
            for r in rows[bi + 1:]:
                t = tarih(hucre(r, ct))
                if not t:
                    continue
                # "PNEUMONİE - BOYNUZ KIRIĞI" gibi birden çok teşhis ayrı sayılır
                for parca in re.split(r'\s+-\s+|/|\+', str(hucre(r, cte) or '')):
                    g = grup(parca)
                    if g == 'Belirtilmemiş':
                        continue
                    a.ekle(t.year, t.month, ciftlik, 'Besi danası', g, 'Tedavi (kalım)',
                           adet_oku(hucre(r, ck)), gun=t)


# ---- Pangev (Erentepe) ----
def pangev(a, yol):
    wb = openpyxl.load_workbook(yol, read_only=True, data_only=True)
    for ws in wb.worksheets:
        ad = buyuk(ws.title)
        rows = satirlar(ws)
        if 'TEDAVİ' in ad:
            bi, h = baslik_bul(rows, 'TEŞH')
            if bi is None:
                continue
            ct, cte = sutun(h, 'TARİH'), sutun(h, 'TEŞH')
            ckim = sutun(h, 'TASMA', 'HAYVAN NO', 'KÜPE')
            cg = sutun(h, 'GRUP', 'KONUM')
            for r in rows[bi + 1:]:
                t = tarih(hucre(r, ct))
                te = hucre(r, cte)
                if not t or te in (None, ''):
                    continue
                g = grup(te)
                if g == 'Belirtilmemiş':
                    continue
                kim = buyuk(hucre(r, ckim))
                cins = cins_grubu(str(hucre(r, cg)) + ' ' + buyuk(te))
                toplu = 'TOPLU' in buyuk(te)
                a.ekle(t.year, t.month, 'Pangev', cins, g, 'Tedavi (kalım)',
                       anahtar=('ted', kim + ('|' + str(t) if toplu else '')), gun=t)
        elif 'ABORT' in ad or ad.startswith('ÖLÜ DOĞUM'):
            # Abort: annenin kaydı (sonuç kalım); ölü doğum: buzağı ölümü.
            bi, h = baslik_bul(rows, 'TARİH', 'AÇIKLAMA')
            if bi is None:
                continue
            ct, cg, ck, ca = sutun(h, 'TARİH'), sutun(h, 'GRUP'), sutun(h, 'KÜPE'), sutun(h, 'AÇIKLAMA')
            for r in rows[bi + 1:]:
                t = tarih(hucre(r, ct))
                if not t:
                    continue
                aciklama = buyuk(hucre(r, ca))
                if 'ÖLÜ DOĞ' in aciklama or (ad.startswith('ÖLÜ DOĞUM') and 'ABORT' not in aciklama):
                    a.ekle(t.year, t.month, 'Pangev', 'Buzağı', 'Ölü doğum', 'Ölüm',
                           anahtar=('oludogum', buyuk(hucre(r, ck)), str(t)), gun=t)
                else:
                    cins = 'Düve' if 'DÜVE' in buyuk(hucre(r, cg)) else 'İnek'
                    a.ekle(t.year, t.month, 'Pangev', cins, 'Abort', 'Tedavi (kalım)',
                           anahtar=('abort', buyuk(hucre(r, ck)), str(t)), gun=t)
        elif ad.startswith('ÖLÜM'):
            bi, h = baslik_bul(rows, 'TARİH', 'AÇIKLAMA')
            if bi is None:
                continue
            ct, cc, ck, ca = sutun(h, 'TARİH'), sutun(h, 'CİNSİYET'), sutun(h, 'KONUM'), sutun(h, 'AÇIKLAMA')
            for r in rows[bi + 1:]:
                t = tarih(hucre(r, ct))
                if not t:
                    continue
                cins = cins_grubu(str(hucre(r, ck)) + ' ' + str(hucre(r, cc)))
                a.ekle(t.year, t.month, 'Pangev', cins, grup(hucre(r, ca)), 'Ölüm', gun=t)
        elif ad.startswith('KESİM'):
            bi, h = baslik_bul(rows, 'TARİH', 'AÇIKLAMA')
            if bi is None:
                continue
            ct, ck, ca = sutun(h, 'KESİM TAR', 'UYGULAMA TAR', 'TARİH'), sutun(h, 'KONUM'), sutun(h, 'AÇIKLAMA')
            for r in rows[bi + 1:]:
                t = tarih(hucre(r, ct))
                neden = buyuk(hucre(r, ca))
                if not t or (neden and NORMAL_KESIM.search(neden)):
                    continue
                a.ekle(t.year, t.month, 'Pangev', cins_grubu(hucre(r, ck)), grup(neden), 'Kesim', gun=t)


def main(klasor, cikti):
    a = Arsiv()
    # Fethiye en son işlenir: aynı vakalar Şekersüt revir/buzağılık listelerinde varsa oradan sayılır.
    for yol in sorted(glob.glob(os.path.join(klasor, '*.xlsx')), key=lambda y: (os.path.basename(y).startswith('fethiye'), y)):
        ad = os.path.basename(yol)[:-5]
        yil = int(ad[-4:]) if ad[-4:].isdigit() else None
        if ad.startswith('sek_revir'):
            sek_revir(a, yol, yil)
        elif ad.startswith('sek_buz'):
            sek_buz(a, yol, yil)
        elif ad.startswith('sek_kesim'):
            sek_kesim(a, yol, int(ad[10:14]), int(ad[15:17]))
        elif ad.startswith('sek_dogol'):
            sek_dogol(a, yol, yil)
        elif ad.startswith('fethiye'):
            fethiye(a, yol)
        elif ad.startswith('aslim'):
            aslim(a, yol, yil)
        elif ad.startswith('pangev'):
            pangev(a, yol)
    bugun = dt.date.today()
    say = {k: v for k, v in a.say.items() if (k[0], k[1]) <= (bugun.year, bugun.month)}
    listeler = {}
    for alan, i in (('ciftlik', 2), ('cins', 3), ('hastalik', 4), ('sonuc', 5)):
        listeler[alan] = sorted({k[i] for k in say})
    idx = {alan: {v: n for n, v in enumerate(l)} for alan, l in listeler.items()}
    kayit = [[k[0], k[1], idx['ciftlik'][k[2]], idx['cins'][k[3]], idx['hastalik'][k[4]],
              idx['sonuc'][k[5]], v] for k, v in sorted(say.items())]
    # gunluk: [yıl, ay, gün (0 = tarihi belirsiz), çiftlik, cins, hastalık, sonuç, adet];
    # her ayın günlük toplamı "kayit"taki aylık sayıya eşittir.
    gunluk = [[k[0], k[1], k[6], idx['ciftlik'][k[2]], idx['cins'][k[3]], idx['hastalik'][k[4]],
               idx['sonuc'][k[5]], v] for k, v in sorted(a.gun.items()) if k[:6] in say]
    j = dict(listeler, kayit=kayit, gunluk=gunluk,
             kaynak='Drive › SAĞLIK RAPORLARI: Şekersüt revir-fresh, buzağılık tedavi, doğan ve ölen '
                    'buzağılar, Panagro kesim listeleri (Kas 2022–Mar 2023), 2026 Fethiye revir/buzağılık tedavi ve ölüm/kesim listeleri; '
                    'Aslım ve Pangev veteriner uygulamaları (Pangev abort/ölü doğum dahil). Fethiye = Şekersüt, Erentepe = Pangev. '
                    'Mesaj/sohbet kaynağı yok.',
             olusturma=bugun.isoformat())
    with open(cikti, 'w', encoding='utf-8') as f:
        json.dump(j, f, ensure_ascii=False, separators=(',', ':'))
    print(len(kayit), 'satır,', sum(say.values()), 'vaka')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
