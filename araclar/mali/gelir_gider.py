#!/usr/bin/env python3
"""Mali Raporlar › Gider, Gelir, Kâr/Zarar verisi.

Kaynaklar (Drive › Mali Raporlar klasörü):
  - "aylık gider tablosu.xlsx"        (SAP gelen fatura kalemleri; muhasebe "2026 Fatura" dosyasıyla aynı)
  - "aylık gelir satış tablosu.xlsx"  (SAP satış faturaları)

Çıktı mali_veri.json içinde "gelirGider" anahtarı olarak yer alır; mali_muhasebe.py
"--gelir DOSYA" verildiğinde bu modülü çağırır:
  python3 -I mali_muhasebe.py "aylık gider tablosu.xlsx" mali_veri.json --gelir "aylık gelir satış tablosu.xlsx"

Tutarlar KDV hariçtir (gider: "Tutar", gelir: "Matrah"); karşılaştırma aynı esasla yapılır.
KVKK: satıcı/müşteri adı, kullanıcı adı, sipariş veren no, fatura/belge numarası ve kalem
açıklaması çıktıya yazılmaz; yalnızca ay, çiftlik, kategori/ürün ve toplamlar aktarılır.
"""
import collections
import datetime
import json
import re
import sys

URETIM_YERI = {'1604': 'Taşağıl (ESK)', '1605': 'Aslım', '1611': 'Tarımsal Alan', '1613': 'Şekersüt', '1614': 'Pan-Gev'}
AY = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık']


def s(v):
    return '' if v is None else str(v).strip()


def sayi(v):
    if isinstance(v, (int, float)):
        return float(v)
    t = s(v).replace(' ', '')
    if not t:
        return 0.0
    if re.fullmatch(r'-?\d{1,3}(\.\d{3})*,\d+', t) or re.fullmatch(r'-?\d+,\d+', t):
        t = t.replace('.', '').replace(',', '.')
    try:
        return float(t)
    except ValueError:
        return 0.0


def tarih(v):
    if isinstance(v, datetime.datetime):
        return v
    for b in ('%d.%m.%Y', '%m/%d/%Y', '%Y-%m-%d'):
        try:
            return datetime.datetime.strptime(s(v)[:10], b)
        except ValueError:
            pass
    return None


def hesap(firma):
    f = s(firma).upper()
    if re.search(r'KONYA ŞEKER|PANAGRO|ÇUMRA ŞEKER|PANKOBİRLİK', f):
        return 'Grup içi'
    if re.search(r'MÜDÜRLÜĞÜ|BELEDİYE|VERGİ DAİRESİ|TOPRAK MAHSULLERİ|TMO|BAŞKANLIĞI|KURUMU|NOTER|ET VE SÜT', f):
        return 'Kamu'
    return 'Grup dışı'


# Gider kalemleri için ek kurallar: mali_muhasebe.KAT'tan önce denenir (kalem metninde geçen ifadeye göre).
EK_KAT = [
    ('Gübre ve zirai ilaç', r'OT İLACI|İLAÇ OT|FUNGUSİT|FUNGİSİT|VARİANO|SİGNUM|SIVANTO|TİVMETİX|CAPRENO|INTEGRITY|KÜKÜRT|AZOTE|CUTTENG'),
    ('Canlı hayvan alımı', r'CANLI (DANA|HAYVAN|SIĞIR)|DANA ALIM|HAYVAN ALIM'),
    ('Veteriner, ilaç, aşı, tohumlama',
     r'MASTİT|VAKSİN|BOVIS|GESTAVET|KOLİBİN|CEFTISIN|PENISILIN|DALMAZİN|GENTAPAN|METECAM|CEPHANOM|PRIMAMYCINE|DOLLİSERA|HALOCUR|'
     r'THERENEKRON|ELİSA|SANİTİME|VİRKON|SİNEK|SOYKÜTÜĞÜ|ISLAH BEDELİ|\b\d+ ?ML\b'),
    ('Yem ve kaba yem', r'POSASI|POSA '),
    ('Makine ve ekipman alımı', r'DÜMENLEME|NOVATEL|\bUPS\b'),
    ('Bakım, onarım, yedek parça', r'KEPÇE ÇALIŞMA|KAYNAK İŞÇ|KAYNAK İŞC|LASTİĞİ'),
]


def gider_kategori(metin, kat):
    t = s(metin).upper()
    for k, p in EK_KAT:
        if re.search(p, t):
            return k
    return kat(metin)


def gelir_urun(metin):
    t = s(metin).upper()
    for k, p in [
        ('Çiğ süt', r'SÜT'),
        ('ESK hayvan bakım hizmeti', r'BAKIM HİZMET'),
        ('Sap balyası', r'SAP BALYA'),
        ('Yonca balyası', r'YONCA'),
        ('Buğday', r'BUĞDAY'),
        ('Arpa', r'ARPA'),
        ('Patates', r'PATATES'),
        ('Şeker pancarı', r'PANCAR'),
        ('Mısır ve silaj', r'MISIR|SİLAJ'),
        ('Canlı hayvan', r'DANA|DÜVE|İNEK|BUZAĞI|TOSUN|HAYVAN'),
        ('Hurda ve atık', r'DEMİR|ATIK|HURDA|YAĞLAR|PLASTİK'),
    ]:
        if re.search(p, t):
            return k
    return 'Diğer'


def _satirlar(yol):
    import openpyxl
    ws = openpyxl.load_workbook(yol, read_only=True, data_only=True).worksheets[0]
    rows = list(ws.iter_rows(values_only=True))
    bas = [s(x) for x in rows[0]]
    return bas, rows[1:]


def _kol(bas, *adlar):
    for a in adlar:
        if a in bas:
            return bas.index(a)
    raise SystemExit(f'Sütun bulunamadı: {adlar}')


def uret(gider_yol, gelir_yol, kat, link_gider='', link_gelir=''):
    # --- gider
    bas, rows = _satirlar(gider_yol)
    c = dict(firma=_kol(bas, 'Satıcı adı'), tarih=_kol(bas, 'Belge tarihi'), brut=_kol(bas, 'Fatura brüt tutarı'),
             net=_kol(bas, 'Tutar'), metin=_kol(bas, 'Kısa metin'), uy=_kol(bas, 'Üretim yeri'))
    gider = collections.defaultdict(lambda: [0.0, 0.0])
    ng = 0
    for r in rows:
        if not r or not s(r[c['firma']]):
            continue  # ara toplam / boş satır
        t = tarih(r[c['tarih']])
        if not t:
            continue
        ng += 1
        k = (t.year, t.month, URETIM_YERI.get(s(r[c['uy']]), 'Diğer birim'), gider_kategori(r[c['metin']], kat), hesap(r[c['firma']]))
        gider[k][0] += sayi(r[c['net']])
        gider[k][1] += sayi(r[c['brut']])
    # --- gelir
    bas, rows = _satirlar(gelir_yol)
    c = dict(org=_kol(bas, 'Satış organizasyonu'), tur=_kol(bas, 'Faturalama türü'), tarih=_kol(bas, 'Faturalama tarihi'),
             musteri=_kol(bas, 'Ad 1'), ia=_kol(bas, 'İş alanı'), mlz=_kol(bas, 'Malzeme  tnm', 'Malzeme tnm'),
             mkt=_kol(bas, 'Faturalanan miktar'), brm=_kol(bas, 'Satış ölçü birimi'), net=_kol(bas, 'Matrah'),
             brut=_kol(bas, 'KDV dahil tutar(TRY)'))
    gelir = collections.defaultdict(lambda: [0.0, 0.0, 0.0])
    nl = 0
    iade = [0, 0.0]
    for r in rows:
        if not r or not s(r[c['org']]):
            continue  # ara toplam satırı
        t = tarih(r[c['tarih']])
        if not t:
            continue
        nl += 1
        net = sayi(r[c['net']])
        if net < 0:
            iade[0] += 1
            iade[1] += net
        k = (t.year, t.month, URETIM_YERI.get(s(r[c['ia']]), 'Diğer birim'), gelir_urun(r[c['mlz']]), hesap(r[c['musteri']]),
             s(r[c['brm']]).upper())
        gelir[k][0] += sayi(r[c['mkt']])
        gelir[k][1] += net
        gelir[k][2] += sayi(r[c['brut']])
    aylar = sorted({(k[0], k[1]) for k in list(gider) + list(gelir)})
    donem = f'{AY[aylar[0][1] - 1]}–{AY[aylar[-1][1] - 1]} {aylar[-1][0]}' if aylar else ''
    return dict(
        surum=1,
        donem=donem,
        kdv='hariç',
        kaynakGider='aylık gider tablosu',
        kaynakGelir='aylık gelir satış tablosu',
        linkGider=link_gider,
        linkGelir=link_gelir,
        satirGider=ng,
        satirGelir=nl,
        iadeAdet=iade[0],
        iadeTutar=round(iade[1], 2),
        # [yıl, ay, çiftlik, kategori, hesap, KDV hariç, KDV dahil]
        gider=[[k[0], k[1], k[2], k[3], k[4], round(v[0], 2), round(v[1], 2)] for k, v in sorted(gider.items())],
        # [yıl, ay, çiftlik, ürün, hesap, birim, miktar, KDV hariç, KDV dahil]
        gelir=[[k[0], k[1], k[2], k[3], k[4], k[5], round(v[0], 3), round(v[1], 2), round(v[2], 2)] for k, v in sorted(gelir.items())],
    )
