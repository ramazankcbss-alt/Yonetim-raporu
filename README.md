# Yönetim Raporu (Android)

Çiftliklerin günlük ve haftalık yönetim raporu. Veriler
"Haftalik_Yonetim_Raporu_Ciftlikler" Google E-Tablosundan okunur; üst
yöneticiye gidecek rapor uygulamada PDF olarak hazırlanıp e-posta veya
WhatsApp ile paylaşılır.

## Ekranlar

| Sekme | İçerik |
|---|---|
| Günlük | Seçilen günün göstergeleri, işletme tablosu, süt değişimi |
| Haftalık | E-Tablodaki haftalık rapor sayfasının telefon görünümü |
| Tarım | Ekim alanları, hasat/verim, besi planı, son faaliyetler |
| Rapor | Günlük veya haftalık PDF oluşturma ve paylaşma |

## Kurulum

1. **Veri bağlantısı:** `apps_script/Kod.gs` dosyasındaki adımları izleyin
   (E-Tablo → Uzantılar → Apps Script). Bağlantı linki e-postanıza gelir.
2. **Uygulama:** Releases bölümündeki `yonetim-raporu.apk` dosyasını telefona
   kurun, ilk açılışta bağlantı linkini yapıştırın.

## Derleme

`main` dalına her gönderimde GitHub Actions APK derler ve Releases'e koyar.
İmza şifresi `YONETIM_KEYSTORE_PASSWORD` adlı Actions secret'ında durur;
aynı anahtar (`ci/yonetim-raporu.p12`) kullanıldığı için yeni sürümler
eskisinin üzerine kurulur.

Hesap kuralları E-Tablodaki haftalık sayfayla aynıdır (ESK-Taşağıl
toplamlara dahil edilmez, süt haftalık toplamdır, diğer değerler son
günün durumudur); `test/` altındaki testler bunu doğrular.
