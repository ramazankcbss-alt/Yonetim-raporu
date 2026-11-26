"""Sürü Sağlığı ve Üreme arşivini yalnızca Drive'daki "SAĞLIK RAPORLARI" klasörünün
veteriner uygulama dosyalarından üretir (doğum, tohumlama, senkronizasyon, gebelik
muayenesi, aşı, gelen hayvan, hayvan satışı, süt analizi, diğer uygulamalar ve
Şekersüt günlük tohumlama bilgisi).

Kullanım:  python3 uygulamalar.py <xlsx klasörü> <çıktı.json>

Klasördeki dosyalar şu adlarla beklenir (.xlsx): fethiye_<yıl>, pangev_<yıl>, aslim_<yıl>,
sek_dogol_<yıl> (Şekersüt doğan ve ölen buzağılar), toh_<yıl> (Şekersüt tohumlama bilgisi).
Fethiye = Şekersüt, Erentepe = Pangev.

KVKK: Çıktıda yalnızca tarih, çiftlik, hayvan grubu, sonuç/tür, adet ve sayısal ölçüler
bulunur. Küpe/tasma/kemer numaraları yalnızca aynı kaydı iki kez saymamak için bellekte
kullanılır. Tohumlayan, uygulayan, sorumlu, eksper, alıcı/satıcı (geldiği yer, satılan
firma) ve plaka sütunları okunmaz.
"""
import datetime as dt
import glob
import json
import os
import re
import sys
import warnings

import openpyxl

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from olustur import baslik_bul, buyuk, hucre, satirlar, sutun, tarih  # noqa: E402

warnings.filterwarnings('ignore')

SEKIL = ['Normal', 'Müdahale/güç doğum', 'Günsüz', 'Ölü doğum', 'Abort']
GRUP = ['İnek', 'Düve', 'Belirtilmemiş']
GEBELIK = ['Gebe', 'Boş', 'Boş (kist)', 'Diğer']
YONTEM = ['Gözlem', 'Senkronizasyon', 'Belirtilmemiş']


def sayi(v):
    if isinstance(v, (int, float)):
        return float(v)
    s = str(v or '').strip().replace(' ', '')
    if not s:
        return None
    if ',' in s and '.' in s:
        s = s.replace('.', '').replace(',', '.')
    else:
        s = s.replace(',', '.')
    try:
        return float(s)
    except ValueError:
        return None


def grup_bul(m):
    m = buyuk(m)
    if 'DÜVE' in m:
        return 1
    if re.search(r'İNEK|SAĞMAL|KURU', m):
        return 0
    return 2


def sekil_bul(m):
    m = buyuk(m)
    if 'ABORT' in m or 'YAVRU AT' in m or 'MUMUF' in m or 'MUMİF' in m:
        return 4
    if 'ÖLÜ DOĞ' in m:
        return 3
    if re.search(r'MÜDAHALE|GÜÇ|ZOR|TERS|SEZARYEN|DİSTOS', m):
        return 1
    if 'GÜNSÜZ' in m:
        return 2
    return 0


class Arsiv:
    def __init__(self):
        self.ciftlik = []
        self.dogum = {}       # (t, ci, grup, sekil) -> [adet, ikiz, disi, erkek, olu]
        self.dogum_g = set()
        self.toh = {}         # (t, ci, grup, sira, yontem) -> adet
        self.toh_g = set()
        self.boga = {}        # (y, m, ci, boga) -> adet
        self.senk = {}        # (t, ci) -> hayvan
        self.geb = {}         # (t, ci, grup, sonuc) -> adet
        self.geb_g = set()
        self.asi = {}         # (t, ci, asi, kapsam) -> kayıt
        self.gelen = {}       # (t, ci, nevi) -> [adet, kg]
        self.satis = {}       # (t, ci, tur) -> [adet, tutar, kg]
        self.satis_g = set()
        self.sut = {}         # (t, ci) -> {alan: değer}
        self.diger = {}       # (t, ci, tur) -> adet
        self.suru = {}        # t -> [değerler]

    def ci(self, ad):
        if ad not in self.ciftlik:
            self.ciftlik.append(ad)
        return ad


def gecerli(t):
    return t is not None and 2010 <= t.year <= dt.date.today().year and t <= dt.date.today()


# ---------- Doğum ----------
def dogum_ekle(a, ci, t, grup, sekil, anahtar, ikiz=False, cins=(), olu=0, adet=1):
    if not gecerli(t):
        return
    if anahtar is not None:
        k = (ci, t, anahtar)
        if k in a.dogum_g:
            return
        a.dogum_g.add(k)
    d = a.dogum.setdefault((t, a.ci(ci), grup, sekil), [0, 0, 0, 0, 0])
    d[0] += adet
    d[1] += 1 if ikiz else 0
    for c in cins:
        c = buyuk(c)
        if 'ÖL' in c:
            d[4] += 1
        if c.startswith('D'):
            d[2] += 1
        elif c.startswith('E'):
            d[3] += 1
    d[4] += olu


def dogum_sayfasi(a, ci, rows):
    bi, h = baslik_bul(rows, 'İKİZ', 'CİNSİYET')
    if bi is None:
        return
    # Doğum tarihi: 'D.TARİHİ' sütunlarından bu yıla ait olanı (Fethiye'de ilk D.TARİHİ annenin eski kaydıdır)
    ctl = [i for i, x in enumerate(h) if 'D.TAR' in x or x == 'TARİH']
    cg, cik, ca = sutun(h, 'DÜVE /', 'GRUP'), sutun(h, 'İKİZ'), sutun(h, 'AÇIKLAMA')
    cc = [i for i, x in enumerate(h) if x.startswith('CİNSİYET')]
    ck = sutun(h, 'KÜPE NO', 'DOĞURAN', 'TASMA')
    for r in rows[bi + 1:]:
        ts = [tarih(hucre(r, i)) for i in ctl]
        ts = [t for t in ts if t]
        if not ts:
            continue
        t = max(ts)
        anne = buyuk(hucre(r, ck))
        if not anne:
            continue
        acik = buyuk(hucre(r, ca)) + ' ' + buyuk(hucre(r, cik))
        cins = [hucre(r, i) for i in cc if hucre(r, i) not in (None, '') and not str(hucre(r, i)).strip().startswith('-')]
        olu = 0
        if 'ÖLDÜ' in acik and not any('ÖL' in buyuk(c) for c in cins):
            olu = 1
        dogum_ekle(a, ci, t, grup_bul(hucre(r, cg)) if cg is not None else 2, sekil_bul(acik), anne,
                   ikiz='İKİZ' in buyuk(hucre(r, cik)), cins=cins, olu=olu)


def abort_sayfasi(a, ci, rows, varsayilan):
    bi, h = baslik_bul(rows, 'TARİH', 'AÇIKLAMA')
    if bi is None:
        return
    ct = sutun(h, 'ABORT.TAR', 'D.TAR', 'TARİH')
    cg, ck, ca = sutun(h, 'GRUP'), sutun(h, 'KÜPE NO', 'DOĞURAN'), sutun(h, 'AÇIKLAMA')
    for r in rows[bi + 1:]:
        t = tarih(hucre(r, ct)) or tarih(hucre(r, sutun(h, 'TARİH')))
        anne = buyuk(hucre(r, ck))
        if not t or not anne:
            continue
        s = sekil_bul(hucre(r, ca))
        dogum_ekle(a, ci, t, grup_bul(hucre(r, cg)), s if s in (3, 4) else varsayilan, anne)


def sek_dogol(a, yol):
    wb = openpyxl.load_workbook(yol, read_only=True, data_only=True)
    for ws in wb.worksheets:
        rows = satirlar(ws)
        bi, h = baslik_bul(rows, 'KULAK NO', 'CİNSİYET')
        if bi is None:
            continue
        # Doğan buzağı bölümü: ilk KULAK NO, D.T., cinsiyet
        ck, cdt, cc = h.index('KULAK NO'), h.index('D.T.'), h.index('CİNSİYET')
        abort_t = [i for i, x in enumerate(h) if x == 'TARİH']
        ca = sutun(h, 'GEBELİK GÜN')
        cn = sutun(h, 'ANNE NO')
        for r in rows[bi + 1:]:
            t = tarih(hucre(r, cdt))
            if t and hucre(r, ck) not in (None, ''):
                dogum_ekle(a, 'Şekersüt', t, 2, 0, ('buzagi', buyuk(hucre(r, ck))), cins=[hucre(r, cc) or ''])
            if abort_t and ca is not None:
                t2 = tarih(hucre(r, abort_t[-1]))
                if t2 and hucre(r, cn) not in (None, ''):
                    s = sekil_bul(hucre(r, ca))
                    dogum_ekle(a, 'Şekersüt', t2, 2, s if s in (3, 4) else 4, ('abort', buyuk(hucre(r, cn))))


def aslim_dogum(a, rows):
    bi, h = baslik_bul(rows, 'DOĞUM TAR', 'DOĞUM ŞEK')
    if bi is None:
        return
    ct, cs, cc, ck, ca = (sutun(h, 'DOĞUM TAR'), sutun(h, 'DOĞUM ŞEK'), sutun(h, 'CİNSİYET'),
                          sutun(h, 'KULAK KÜPE', 'ANNE'), sutun(h, 'AÇIKLAMA'))
    for r in rows[bi + 1:]:
        t = tarih(hucre(r, ct))
        if not t:
            continue
        dogum_ekle(a, 'Aslım', t, 2, sekil_bul(hucre(r, cs)), buyuk(hucre(r, ck)) or str(id(r)),
                   ikiz='İKİZ' in buyuk(hucre(r, ca)), cins=[hucre(r, cc) or ''])


# ---------- Tohumlama ----------
def tohumlama_sayfasi(a, ci, rows):
    bi, h = baslik_bul(rows, 'TARİH', 'TOHUM')
    if bi is None:
        return
    ct = sutun(h, 'TOH. TAR', 'TOHUMLAMA TAR', 'TARİH')
    cg, cs = sutun(h, 'DÜVE /', 'GRUP'), sutun(h, 'TOH. SAY')
    cb, cy = sutun(h, 'BOĞA', 'TOHUM ADI'), sutun(h, 'TESPİT', 'UYGULAMA')
    ckl = [i for i in (sutun(h, 'KÜPE'), sutun(h, 'TASMA'), sutun(h, 'HAYVAN BİLGİSİ')) if i is not None]
    for r in rows[bi + 1:]:
        t = tarih(hucre(r, ct))
        kim = next((buyuk(hucre(r, i)) for i in ckl if buyuk(hucre(r, i))), '')
        if not gecerli(t) or not kim:
            continue
        k = (ci, t, kim)
        if k in a.toh_g:
            continue
        a.toh_g.add(k)
        n = sayi(hucre(r, cs))
        sira = 0 if n is None else (1 if n <= 1 else 2 if n == 2 else 3)
        y = buyuk(hucre(r, cy))
        yontem = 1 if 'SE' in y and 'RON' in y else 0 if 'GÖZLEM' in y else 2
        key = (t, a.ci(ci), grup_bul(hucre(r, cg)) if cg is not None else 2, sira, yontem)
        a.toh[key] = a.toh.get(key, 0) + 1
        b = buyuk(hucre(r, cb))
        if b and len(b) > 1:
            kb = (t.year, t.month, ci, b)
            a.boga[kb] = a.boga.get(kb, 0) + 1


# ---------- Senkronizasyon ----------
HAYVAN = re.compile(r'^(HAZIR|AÇIK|TOHUMLANMAYA HAZIR)$')
PROTOKOL = re.compile(r'GNRH|PGF|PRİD|PRID|TOHUMLAMA|OVAREL|PSG')


def senk_sayfasi(a, ci, rows):
    blok, tarihler, onceki_t = 0, [], None

    def kapat():
        nonlocal blok, tarihler
        if blok:
            t = min(tarihler) if tarihler else onceki_t
            if gecerli(t):
                k = (t, a.ci(ci))
                a.senk[k] = a.senk.get(k, 0) + blok
        blok, tarihler = 0, []

    for r in rows:
        metin = [buyuk(c) for c in r if isinstance(c, str)]
        ts = [tarih(c) for c in r if isinstance(c, (dt.date, dt.datetime))]
        hayvan = any(HAYVAN.match(m) for m in metin)
        if hayvan:
            if tarihler:      # önceki bloğun protokolü bitti, yeni blok başlıyor
                kapat()
            blok += 1
        elif blok and (ts or any(PROTOKOL.search(m) for m in metin)):
            tarihler += [t for t in ts if t]
        elif ts and not blok:
            onceki_t = ts[0]
    kapat()


# ---------- Gebelik muayenesi ----------
def gebelik_sayfasi(a, ci, rows):
    bi, h = baslik_bul(rows, 'TARİH', 'GEBELİK')
    if bi is None:
        bi, h = baslik_bul(rows, 'TARİH', 'SONUÇ')
    if bi is None:
        return
    ct = sutun(h, 'TARİH', 'KONTROL TAR')
    cs = sutun(h, 'SONUÇ', 'GEBELİK MUAYENES', 'GEBELİK DURUM')
    cg = sutun(h, 'İNEK/DÜVE', 'DURUM')
    if cg == cs:
        cg = None
    ck = sutun(h, 'KÜPE', 'TASMA', 'HAYVAN NO')
    for r in rows[bi + 1:]:
        t, s = tarih(hucre(r, ct)), buyuk(hucre(r, cs))
        kim = buyuk(hucre(r, ck))
        if not gecerli(t) or not s:
            continue
        k = (ci, t, kim or str(id(r)))
        if k in a.geb_g:
            continue
        a.geb_g.add(k)
        sonuc = 2 if 'KİST' in s else 1 if s.startswith('BOŞ') else 0 if s.startswith('GEBE') else 3
        key = (t, a.ci(ci), grup_bul(hucre(r, cg)) if cg is not None else 2, sonuc)
        a.geb[key] = a.geb.get(key, 0) + 1


# ---------- Aşı ----------
def asi_sayfasi(a, ci, rows):
    bi, h = baslik_bul(rows, 'TARİH', 'AŞI')
    if bi is None:
        return
    ct, cad = sutun(h, 'UYGULAMA TAR', 'TARİH'), sutun(h, 'YAPILAN AŞI', 'UYGULANAN AŞI', 'AŞI ADI')
    ck = sutun(h, 'UYGULANAN GRUP', 'KONUM')
    for r in rows[bi + 1:]:
        t, ad = tarih(hucre(r, ct)), re.sub(r'\s+', ' ', buyuk(hucre(r, cad)))
        if not gecerli(t) or not ad:
            continue
        key = (t, a.ci(ci), ad, re.sub(r'\s+', ' ', buyuk(hucre(r, ck))))
        a.asi[key] = a.asi.get(key, 0) + 1


# ---------- Gelen hayvan (Aslım) ----------
def gelen_sayfasi(a, ci, rows):
    bi, h = baslik_bul(rows, 'TARİH', 'ADET')
    if bi is None:
        return
    ct, cn, cad, cto = sutun(h, 'TARİH'), sutun(h, 'NEVİ'), sutun(h, 'ADET'), sutun(h, 'TONAJ')
    for r in rows[bi + 1:]:
        t, n = tarih(hucre(r, ct)), sayi(hucre(r, cad))
        if not gecerli(t) or not n:
            continue
        key = (t, a.ci(ci), buyuk(hucre(r, cn)) or 'BELİRTİLMEMİŞ')
        d = a.gelen.setdefault(key, [0, 0.0])
        d[0] += int(n)
        d[1] += sayi(hucre(r, cto)) or 0


# ---------- Hayvan satışı (Pangev) ----------
def satis_sayfasi(a, ci, rows):
    bi, h = baslik_bul(rows, 'DURUM KODU', 'TARİH')
    if bi is None:
        return
    ct = sutun(h, 'SATILDIĞI TAR')
    if ct is None:
        ct = max(i for i, x in enumerate(h) if x == 'TARİH')
    ctur, ckg = sutun(h, 'DURUM KODU'), sutun(h, 'CANLI KG')
    cf = sutun(h, 'SATIŞ FİYAT', 'TUTAR')
    ck = sutun(h, 'KAYIT', 'HAYVAN NO')
    for r in rows[bi + 1:]:
        t = tarih(hucre(r, ct))
        kim = buyuk(hucre(r, ck))
        if not gecerli(t) or not kim:
            continue
        k = (ci, kim)
        if k in a.satis_g:
            continue
        a.satis_g.add(k)
        tur = buyuk(hucre(r, ctur))
        tur = 'Erkek buzağı' if 'ERKEK' in tur and ('BUZ' in tur or 'BZ' in tur) else tur.capitalize() or 'Belirtilmemiş'
        d = a.satis.setdefault((t, a.ci(ci), tur), [0, 0.0, 0.0])
        d[0] += 1
        d[1] += sayi(hucre(r, cf)) or 0
        d[2] += sayi(hucre(r, ckg)) or 0


# ---------- Süt analizi ----------
SUT_ALAN = [('miktar', 'MİKTAR'), ('yag', 'YAĞ'), ('protein', 'PROTEİN'), ('ykm', 'YKM'), ('tkm', 'TKM'),
            ('tkm', 'KURU MADDE'), ('ph', 'PH'), ('laktik', 'LAKTİK'), ('shs', 'SOMATİK'), ('bakteri', 'BAKTERİ')]


def sut_sayfasi(a, ci, rows):
    bi, h = baslik_bul(rows, 'TARİH', 'YAĞ')
    if bi is None:
        return
    ct = sutun(h, 'TARİH')
    for r in rows[bi + 1:]:
        t = tarih(hucre(r, ct))
        if not gecerli(t):
            continue
        d = {}
        for ad, b in SUT_ALAN:
            i = sutun(h, b)
            v = sayi(hucre(r, i)) if i is not None else None
            if v is not None and ad not in d:
                d[ad] = round(v, 4)
        if d:
            a.sut[(t, a.ci(ci))] = d


# ---------- Diğer uygulamalar ----------
def diger_sayfasi(a, ci, rows, tur):
    bi, h = baslik_bul(rows, 'TAR')
    if bi is None:
        return
    ct = sutun(h, 'BAKIM TAR', 'UYGULAMA TAR', 'TARİH')
    for r in rows[bi + 1:]:
        t = tarih(hucre(r, ct))
        if not gecerli(t):
            continue
        k = (t, a.ci(ci), tur)
        a.diger[k] = a.diger.get(k, 0) + 1


# ---------- Şekersüt günlük tohumlama bilgisi ----------
SURU = [('sagmal', 'SAĞMAL SAY'), ('bos_inek', 'BOŞ İNEK'), ('toh_inek', 'BUGÜN TOHUMLANAN İNE'),
        ('tohumlu_inek', 'TOHUMLU İNEK'), ('gebe_inek', 'TOPLAM GEBE İNEK'), ('kuru_gebe', 'KURU GEBE'),
        ('genc_duve', 'GENÇ DÜVE'), ('bos_duve', 'BOŞ DÜVE'), ('uygun_duve', 'TOHUMA UYGUN'),
        ('toh_duve', 'BUGÜN TOHUMLANAN DÜV'), ('tohumlu_duve', 'TOHUMLU DÜVE'), ('gebe_duve', 'TOPLAM GEBE DÜVE'),
        ('kizginlik', 'KIZGINLIK')]


def toh_bilgi(a, yol):
    wb = openpyxl.load_workbook(yol, read_only=True, data_only=True)
    for ws in wb.worksheets:
        rows = satirlar(ws)
        bi, h = baslik_bul(rows, 'TARİH', 'SAĞMAL')
        if bi is None:
            continue
        idx = [sutun(h, b) for _, b in SURU]
        for r in rows[bi + 1:]:
            t = tarih(hucre(r, 0))
            if not gecerli(t):
                continue
            v = [sayi(hucre(r, i)) if i is not None else None for i in idx]
            if v[0] is None:
                continue
            a.suru[t] = [None if x is None else int(x) for x in v]
    a.ci('Şekersüt')


def veteriner_dosyasi(a, yol, ci):
    wb = openpyxl.load_workbook(yol, read_only=True, data_only=True)
    for ws in wb.worksheets:
        ad = buyuk(ws.title)
        rows = satirlar(ws)
        if ad.startswith('DOĞUM'):
            if ci == 'Aslım':
                aslim_dogum(a, rows)
            else:
                dogum_sayfasi(a, ci, rows)
        elif 'ABORT' in ad or 'YAVRU AT' in ad:
            abort_sayfasi(a, ci, rows, 4)
        elif ad.startswith('ÖLÜ DOĞUM'):
            abort_sayfasi(a, ci, rows, 3)
        elif ad.startswith('TOHUMLAMA'):
            tohumlama_sayfasi(a, ci, rows)
        elif ad.startswith('SENKRON'):
            senk_sayfasi(a, ci, rows)
        elif ad.startswith('GEBELİK'):
            gebelik_sayfasi(a, ci, rows)
        elif ad.startswith('AŞI'):
            asi_sayfasi(a, ci, rows)
        elif ad.startswith('GELEN'):
            gelen_sayfasi(a, ci, rows)
        elif 'SATIŞ' in ad:
            satis_sayfasi(a, ci, rows)
        elif ad.startswith('SÜT ANAL'):
            sut_sayfasi(a, ci, rows)
        elif ad.startswith('TIRNAK'):
            diger_sayfasi(a, ci, rows, 'Tırnak bakımı')
        elif ad.startswith('MIKNATIS'):
            diger_sayfasi(a, ci, rows, 'Mıknatıs uygulaması')
        elif ad.startswith('BOYNUZ'):
            diger_sayfasi(a, ci, rows, 'Boynuz köreltme')


def main(klasor, cikti):
    a = Arsiv()
    for yol in sorted(glob.glob(os.path.join(klasor, '*.xlsx'))):
        ad = os.path.basename(yol)[:-5]
        if ad.startswith('fethiye'):
            veteriner_dosyasi(a, yol, 'Şekersüt')
        elif ad.startswith('pangev'):
            veteriner_dosyasi(a, yol, 'Pangev')
        elif ad.startswith('aslim'):
            veteriner_dosyasi(a, yol, 'Aslım')
        elif ad.startswith('sek_dogol'):
            sek_dogol(a, yol)
        elif ad.startswith('toh_'):
            toh_bilgi(a, yol)
    cf = sorted(a.ciftlik)
    ci = {c: i for i, c in enumerate(cf)}
    gun = lambda t: [t.year, t.month, t.day]  # noqa: E731
    bogalar = sorted({k[3] for k in a.boga})
    asilar = sorted({k[2] for k in a.asi})
    j = {
        'ciftlik': cf, 'sekil': SEKIL, 'grup': GRUP, 'gebelik': GEBELIK, 'yontem': YONTEM,
        'bogalar': bogalar, 'asilar': asilar,
        # [y, a, g, çiftlik, grup, şekil, doğum, ikiz, dişi, erkek, ölü buzağı]
        'dogum': [gun(k[0]) + [ci[k[1]], k[2], k[3]] + v for k, v in sorted(a.dogum.items())],
        # [y, a, g, çiftlik, grup, tohumlama sırası (0 bilinmiyor, 1, 2, 3 = 3 ve üzeri), yöntem, adet]
        'tohumlama': [gun(k[0]) + [ci[k[1]], k[2], k[3], k[4], v] for k, v in sorted(a.toh.items())],
        # [y, a, çiftlik, boğa, adet]
        'boga': [[k[0], k[1], ci[k[2]], bogalar.index(k[3]), v] for k, v in sorted(a.boga.items())],
        # [y, a, g (program başlangıcı), çiftlik, hayvan]
        'senk': [gun(k[0]) + [ci[k[1]], v] for k, v in sorted(a.senk.items())],
        # [y, a, g, çiftlik, grup, sonuç, adet]
        'gebelikMuayene': [gun(k[0]) + [ci[k[1]], k[2], k[3], v] for k, v in sorted(a.geb.items())],
        # [y, a, g, çiftlik, aşı, kapsam, kayıt sayısı]
        'asi': [gun(k[0]) + [ci[k[1]], asilar.index(k[2]), k[3].capitalize(), v] for k, v in sorted(a.asi.items())],
        # [y, a, g, çiftlik, nevi, adet, toplam kg]
        'gelen': [gun(k[0]) + [ci[k[1]], k[2].capitalize(), v[0], round(v[1])] for k, v in sorted(a.gelen.items())],
        # [y, a, g, çiftlik, tür, adet, tutar TL, toplam canlı kg]
        'satis': [gun(k[0]) + [ci[k[1]], k[2], v[0], round(v[1]), round(v[2], 1)] for k, v in sorted(a.satis.items())],
        # [y, a, g, çiftlik, {ölçüm: değer}]
        'sut': [gun(k[0]) + [ci[k[1]], v] for k, v in sorted(a.sut.items())],
        # [y, a, g, çiftlik, tür, adet]
        'diger': [gun(k[0]) + [ci[k[1]], k[2], v] for k, v in sorted(a.diger.items())],
        # Şekersüt günlük sürü/tohumlama durumu: alanlar 'suruAlan' sırasıyla
        'suruAlan': [x for x, _ in SURU],
        'suru': [gun(t) + v for t, v in sorted(a.suru.items())],
        'kaynak': "Drive › SAĞLIK RAPORLARI: Fethiye (Şekersüt), Pangev (Erentepe) ve Aslım veteriner uygulama dosyaları; "
                  "Şekersüt doğan ve ölen buzağılar; Şekersüt tohumlama bilgisi. Kişi adı, küpe numarası ve plaka içermez.",
        'olusturma': dt.date.today().isoformat(),
    }
    with open(cikti, 'w', encoding='utf-8') as f:
        json.dump(j, f, ensure_ascii=False, separators=(',', ':'))
    print({k: len(v) for k, v in j.items() if isinstance(v, list)})


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
