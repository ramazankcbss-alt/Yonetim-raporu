// Testler için: rapor E-Tablosundaki 01–05.11.2026 verisi (Apps Script'in
// döndürdüğü biçimde). Beklenen sonuçlar E-Tablonun haftalık sayfasından.

List<Object> _gun(String t, List<List<Object>> isletmeler) => [
      for (final r in isletmeler) [t, ...r]
    ];

final Map<String, dynamic> ornekJson = {
  'ok': true,
  'surum': 1,
  'olusturma': '2026-11-06T15:40:00',
  // No, Konu, Çiftlik, Kaynak, Açılış, Durum, Son değişiklik, Son durum, Sorumlu
  'isler': [
    [
      '1', 'Vetkim ödemesi', 'Çiftlikler', 'Chat – Ödeme', '2026-09-28',
      'Bekliyor', '2026-11-02', 'Firma sürekli arıyor', 'Özge Demirel'
    ],
    [
      '2', 'Sağım sistemi bakımı', 'Şekersüt', 'Gmail', '2026-11-09',
      'Devam ediyor', '2026-11-10', 'Teklif alındı, karar bekliyor', 'Bakım'
    ],
    [
      '3', 'Yağmurluk alımı', 'Çiftlikler', 'Chat – Satınalma', '2026-10-27',
      'Tamamlandı', '2026-11-04', 'İhsan Kocak\'tan alındı', 'Murat Bala'
    ],
  ],
  // No, Başlık, Bölüm, Durum, Firma, Tutar, Anahtar, Açılış, Son güncelleme,
  // Kaynak, Sonraki adım, Detay
  'isakisi': [
    [
      '1', 'Soya küspesi siparişi', 'Satınalma', 'SAT açıldı',
      'Çukurova Yem', '', '2-412888', '08.11.2026', '10.11.2026',
      'Chat – Satınalma', 'Malzeme teslim bekleniyor', ''
    ],
    [
      '2', 'Vetkim ilaç ödemesi', 'Finans', 'Ödeme bekliyor',
      'Vetkim', '48.500 TL', '', '20.10.2026', '01.11.2026',
      'Chat – Ödeme', 'Finans ödemeyi planlasın', ''
    ],
    [
      '3', 'Sağım sistemi fatura', 'Muhasebe', 'Fatura geldi',
      'DeLaval', '', 'FT-2026-551', '25.10.2026', '11.11.2026',
      'Gmail', 'Ödeme planına eklenecek', ''
    ],
    [
      '4', 'Traktör dingil arızası', 'Arıza-Bakım', 'Serviste',
      '42 VU 717', '', '', '05.11.2026', '09.11.2026',
      'Chat – Satınalma', 'Parça bekleniyor', ''
    ],
    [
      '5', 'Yağmurluk alımı', 'Tamamlandı', 'Ödendi',
      'İhsan Kocak', '', '', '27.10.2026', '04.11.2026',
      'Chat – Satınalma', '', ''
    ],
  ],
  // Tarih, Kategori, Konu, Gönderen, Özet, Ekler, Periyot
  'arsiv': [
    [
      '02.11.2026', 'Puantaj / İK',
      'Çiftlikler Puantaj ve Fazla Mesailer (Ekim2026)',
      'Osman Konuk (abholding)',
      'Ekim ek ödemeler: Pangev/Pankent yemek-yol ücreti',
      'ÇİFTLİKLER PUANTAJ VE MESAİLER 2026 EKİM', 'Ekim 2026'
    ],
    [
      '10.11.2026', 'Sipariş / Satınalma', 'Sağımhane dezenfektan talebi',
      'Sinem', 'Şekersüt/Fethiye şartname iletildi', '', ''
    ],
  ],
  // Dönem, Tür, Konu, Gönderen, Özet, Belge, Tarih
  'personel': [
    [
      'Ekim 2026', 'Puantaj', 'Çiftlikler Puantaj ve Fazla Mesailer',
      'Osman Konuk (İK/işveren)', 'Ekim puantaj ve fazla mesailer; ek ödemeler',
      'ÇİFTLİKLER PUANTAJ VE MESAİLER 2026 EKİM', '02.11.2026'
    ],
    [
      'Ekim 2026', 'Taşeron Puantaj', 'Çiftlikler Taşeron Personel Puantajı',
      'Osman Konuk', 'Taşeron personel puantajı', '', '02.11.2026'
    ],
  ],
  'hayvanOzet': [
    ..._gun('2026-11-02', [
      ['Fethiye Şube', 41, 2, 981, 419, 10471, 0, 3, 1, 1],
      ['Fethiye Şube Holstein Besi', '', '', 811, '', '', '', '', '', ''],
      ['Pankent Çiftliği', 1, '', '', '', '', '', '', '', ''],
      ['Erentepe Şube', 6, 1, 283, 117, 3170, 0, 0, 0, 0],
      ['Aslım Çiftliği Besi Danası', 19, '', '', '', '', '', '', '', ''],
      ['ESK-Taşağıl Çiftliği Besi Danası', 6, 7, 3966, '', '', '', '', '', 142],
      ['Yönetici - Müdür', 3, '', '', '', '', '', '', '', ''],
      ['Fethiye Şube Güvenlik', 4, '', '', '', '', '', '', '', ''],
      ['Çumpaş Çiftliği', 1, '', '', '', '', '', '', '', ''],
      ['Aslım Çiftliği Güvenlik', 4, '', '', '', '', '', '', '', ''],
      ['ESK-Taşağıl Çiftliği Güvenlik', 3, '', '', '', '', '', '', '', ''],
      ['Konya Merkez Şeker Süt', 3, '', '', '', '', '', '', '', ''],
    ]),
    ..._gun('2026-11-03', [
      ['Fethiye Şube', 41, 2, 981, 419, 10700, 0, 0, 0, 0],
      ['Fethiye Şube Holstein Besi', '', '', 811, '', '', '', '', '', ''],
      ['Pankent Çiftliği', 1, '', '', '', '', '', '', '', ''],
      ['Erentepe Şube', 6, 1, 283, 117, 3180, 0, 0, 0, 0],
      ['Aslım Çiftliği Besi Danası', 19, '', '', '', '', '', '', '', ''],
      ['ESK-Taşağıl Çiftliği Besi Danası', 6, 7, 3756, '', '', '', '', '', 210],
      ['Yönetici - Müdür', 3, '', '', '', '', '', '', '', ''],
      ['Fethiye Şube Güvenlik', 4, '', '', '', '', '', '', '', ''],
      ['Çumpaş Çiftliği', 1, '', '', '', '', '', '', '', ''],
      ['Aslım Çiftliği Güvenlik', 4, '', '', '', '', '', '', '', ''],
      ['ESK-Taşağıl Çiftliği Güvenlik', 3, '', '', '', '', '', '', '', ''],
      ['Konya Merkez Şeker Süt', 3, '', '', '', '', '', '', '', ''],
    ]),
    ..._gun('2026-11-04', [
      ['Fethiye Şube', 41, 2, 981, 417, 9864, 0, 0, 0, 1],
      ['Fethiye Şube Holstein Besi', '', '', 810, '', '', '', '', '', ''],
      ['Pankent Çiftliği', 1, '', '', '', '', '', '', '', ''],
      ['Erentepe Şube', 6, 1, 285, 118, 3154, 2, 0, 0, 0],
      ['Aslım Çiftliği Besi Danası', 19, '', '', '', '', '', '', '', ''],
      ['ESK-Taşağıl Çiftliği Besi Danası', 6, 7, 3686, '', '', '', '', '', 70],
      ['Yönetici - Müdür', 3, '', '', '', '', '', '', '', ''],
      ['Fethiye Şube Güvenlik', 4, '', '', '', '', '', '', '', ''],
      ['Çumpaş Çiftliği', 1, '', '', '', '', '', '', '', ''],
      ['Aslım Çiftliği Güvenlik', 4, '', '', '', '', '', '', '', ''],
      ['ESK-Taşağıl Çiftliği Güvenlik', 3, '', '', '', '', '', '', '', ''],
      ['Konya Merkez Şeker Süt', 3, '', '', '', '', '', '', '', ''],
    ]),
    ..._gun('2026-11-05', [
      ['Fethiye Şube', 41, 2, 982, 418, 9382, 1, 0, 0, 0],
      ['Fethiye Şube Holstein Besi', '', '', 810, '', '', '', '', '', ''],
      ['Pankent Çiftliği', 1, '', '', '', '', '', '', '', ''],
      ['Erentepe Şube', 6, 1, 287, 119, 3266, 2, 0, 0, 0],
      ['Aslım Çiftliği Besi Danası', 19, '', '', '', '', '', '', '', ''],
      ['ESK-Taşağıl Çiftliği Besi Danası', 6, 7, 3686, '', '', '', '', '', 0],
      ['Yönetici - Müdür', 3, '', '', '', '', '', '', '', ''],
      ['Fethiye Şube Güvenlik', 4, '', '', '', '', '', '', '', ''],
      ['Çumpaş Çiftliği', 1, '', '', '', '', '', '', '', ''],
      ['Aslım Çiftliği Güvenlik', 4, '', '', '', '', '', '', '', ''],
      ['ESK-Taşağıl Çiftliği Güvenlik', 3, '', '', '', '', '', '', '', ''],
      ['Konya Merkez Şeker Süt', 3, '', '', '', '', '', '', '', ''],
    ]),
  ],
  'hayvanGunluk': [
    ['2026-11-01', 1797, 423, 49, 964, 10410, 9320, 283, 117, 19, 21, 3060, 2810],
    ['2026-11-02', 1792, 419, 51, 963, 10471, 9381, 283, 117, 19, 21, 3170, 2970],
    ['2026-11-03', 1792, 419, 51, 963, 10700, 9450, 283, 117, 19, 21, 3180, 2955],
    ['2026-11-04', 1791, 417, 53, 962, 9864, 8784, 285, 118, 18, 22, 3154, 2872],
    ['2026-11-05', 1792, 418, 52, 963, 9382, 8562, 287, 119, 17, 22, 3266, 2912],
  ],
  'tarim': [
    ['2026-10-27', 'Fidanlık', 'Arpa ekimi yapıldı: 82 dekar'],
    ['2026-11-01', 'Aslım', 'Tarla hazırlığı yapılıyor'],
    ['2026-11-01', 'Şekersüt', 'Yağmurlama boruları toplanıyor'],
    ['2026-11-03', 'Şekersüt',
      '100 dekar pancar toprağı çekili alanda 13 bacak çekimi yapıldı, akabinde kobra çekimine başlandı (5. pivot yanı)'],
    ['2026-11-04', 'Aslım',
      'Yonca: 3. pivot 300 da tırmık çekildi (kalan 170 da, Ahmet Ali Dursun); 6. pivot biçim 150 da oldu (kalan 320 da, Ahmet Ali Dursun). 5. pivot: fire toprağı sürümü 180 da (kalan 20 da, Mehmet Sert), alabora çekimi 150 da (kalan 50 da, Hakkı Sert). Teslim alındı: 10.650 kg Lucilla buğday tohumu, 35.000 Halis buğday tohumu'],
    ['2026-11-04', 'Taşağıl', 'Personeller Fidanlık tarımsal alanda çalışıyor.'],
    ['2026-11-04', 'Fidanlık', 'Arpa ekimi devam ediyor: 107 dekar (Operatör: Fatih Özdem, İsa Özçalık)'],
    ['2026-11-05', 'Fidanlık', 'Arpa ekimi devam ediyor: 47 dekar (Operatör: Fatih Özdem, İsa Özçalık)'],
  ],
  'ekim': [
    ['Şekersüt', 'Silajlık mısır', 670, 670],
    ['Şekersüt', 'Buğday (dane)', 1700, 1700],
    ['Şekersüt', 'Pancar', 700, ''],
    ['Aslım', 'Silajlık mısır', 140, 140],
    ['Aslım', 'Arpa', 1340, 1340],
    ['Aslım', 'Buğday', 520, 520],
    ['Aslım', 'Şeker pancarı', 1000, ''],
    ['Aslım', 'Yonca', 1410, 1410],
    ['Taşağıl', 'Patates', 400, 400],
    ['Taşağıl', 'Şeker pancarı', 230, ''],
    ['Fidanlık', 'Arpa', 660, 404],
    ['Fidanlık', 'Buğday', 135, 100],
  ],
  'hasat': [
    ['Silajlık mısır', 'Şekersüt', 670, 3956300, 5904.925, '2026-09-20'],
    ['Patates', 'Taşağıl', 400, 1954747, 4886.8675, '2026-10-22'],
    ['Buğday dane (kısmi: 1., 3., 5. pivot)', 'Şekersüt', '', 1172900, '—', '2026-07-29'],
  ],
  'besi': [
    ['ŞEKERSÜT', 810, 30, 15],
    ['ASLIM', 0, 0, 0],
  ],
};
