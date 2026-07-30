# Keşfedilebilirlik Notları — Tasarım Spec'i

**Tarih:** 2026-07-30
**Hedef sürüm:** 1.2.2 (build tetiklenmeden önce dahil edilecek — kullanıcı kararı)
**Durum:** Onaylandı (tasarım sunumu üzerine)

## 1. Problem

Huni verisi (2026-07-30, son 7 gün): barkod akışı fiilen ölü (1 cihaz),
`product_viewed` ≈ 0. Barkod yolunun değer hikâyesini taşıyan iki özellik —
**kıyaslama** (2 ürün yan yana) ve **topluluk ürün kaydı** (bulunamayan
barkodu bir kez kaydet, sonrakiler anında bulur) — arayüzde neredeyse
görünmez:

1. Kıyaslama yalnızca ürün detayının ALTERNATİF sekmesinin içinde; sekmeye
   girmeyen kullanıcı özelliğin varlığını hiç öğrenmiyor.
2. ALTERNATİF sekmesindeki "Kıyasla" butonu ne yaptığını anlatmıyor.
3. Ürün-bulunamadı ekranındaki intro, kaydın **tek seferlik** olduğunu ve
   sonraki taramalarda ürünün anında açılacağını söylemiyor — kullanıcı
   "her seferinde form mu dolduracağım?" diye düşünüp kaçabilir.

## 2. Kapsam — üç değişiklik

### 2.1 Ürün detayı: tek seferlik kıyas ipucu şeridi

- **Yer:** `product_detail_screen.dart` — sekme çubuğunun hemen altında,
  hangi sekme açık olursa olsun görünen ince bir şerit.
- **Davranış:** Cihazda daha önce kapatılmamışsa görünür. Sağdaki X'e
  basınca `SharedPreferences`'a flag yazılır ve bir daha asla görünmez.
  Otomatik kaybolma yok, sekme değişiminde kaybolma yok — yalnızca X.
- **Metin (TR):** "İpucu: İki ürünü yan yana kıyaslayabilirsin —
  ALTERNATİF sekmesine bak."
- **Neden bu kapsıyor:** Ürün detayına hem başarılı taramadan hem de yeni
  ürün kaydı akışının sonundan düşülüyor; "taratınca ya da kaydedince,
  ilk seferde göster" isteğinin ikisi de tek mekanizmayla karşılanıyor.
- **State pattern'i:** `app_session.dart`'taki `hasSeenOnboardingProvider`
  pattern'i birebir: `sharedPreferencesProvider`'dan oku,
  `Provider<bool>` + kapatma anında `prefs.setBool` + provider invalidate.
  **Savunmacı varsayılan:** prefs erişilemezse şerit GÖSTERİLMEZ
  (onboarding'in tersine — bozuk prefs kullanıcıyı her açılışta ipucuyla
  rahatsız etmesin).
- **Görsel dil:** Mevcut muted yüzeyler (`surfaceCard` + `border`),
  `Icons.compare_arrows_rounded` başta, X sonda; 12-13px metin. Yeni renk
  tanımı yok.

### 2.2 ALTERNATİF sekmesi: Kıyasla butonu altına kalıcı açıklama

- **Yer:** `product_detail_screen.dart` → `_buildAlternativeTab` —
  mevcut "Kıyasla" `OutlinedButton`'ının hemen altına.
- **Davranış:** Kalıcı, durumsuz, her zaman görünür.
- **Metin (TR):** "İki ürünün besin değerlerini, katkılarını ve
  skorlarını yan yana gör."
- **Görsel dil:** `textMuted`, 12-13px, sola hizalı tek satır (uzun
  dillerde 2 satıra sarabilir — `softWrap` açık, kırpma yok).

### 2.3 Ürün-bulunamadı ekranı: intro metni güncellemesi

- **Yer:** Yeni widget YOK — yalnızca mevcut `addProductIntro` l10n
  anahtarının metni değişir (`product_not_found_screen.dart` zaten bu
  anahtarı gösteriyor).
- **Yeni metin (TR):** "Bu ürün henüz veritabanımızda yok. Bir kez
  kaydetmen yeterli — sonraki taramalarda ürün anında açılır ve diğer
  kullanıcılar da yararlanır."
- Eski metin: "Bu ürün henüz veritabanımızda yok.\nBilgileri girerek
  topluluk veritabanına ekleyebilirsiniz!"

## 3. l10n

- **Yeni anahtarlar (3):** `compareHintStrip` (2.1), `compareCaption` (2.2),
  `compareHintDismiss` (X butonunun erişilebilirlik etiketi).
- **Güncellenen anahtar (1):** `addProductIntro` (2.3).
- **Diller (6):** tr, en, es, pt, ar, zh — hepsi ayrı çevrilecek, makine
  kalıbı değil doğal ifade. Arapça RTL: standart `Row`/`Text` kullanımı,
  özel işlem gerekmez (X ikonu `Row`'un sonunda — RTL'de otomatik başa
  geçer, doğru davranış).
- Şeridin kapatma butonu ikon-only (X); mevcut arb'lerde genel bir
  "kapat" anahtarı YOK (tarandı, 2026-07-30) → erişilebilirlik etiketi
  için üçüncü yeni anahtar eklenir: `compareHintDismiss` ("Kapat" /
  "Dismiss" vb.). Toplam yeni anahtar: 3.

## 4. Teknik detaylar

- **Prefs anahtarı:** `compare_hint_dismissed` (bool). Anahtar sabiti,
  `kOnboardingSeenKey`'in tanımlandığı yerde (aynı sabitler dosyası).
- **Provider:** `compareHintDismissedProvider` — pattern
  `hasSeenOnboardingProvider` ile aynı, ama yeri ürün feature'ı:
  `lib/features/product/presentation/providers/compare_hint_provider.dart`
  (yeni küçük dosya — bu bir oturum/kimlik durumu değil, ürün-detayı
  UI durumu; `app_session.dart`'a AİT DEĞİL).
- **Widget:** `CompareHintStrip` — küçük, bağımsız, `ConsumerWidget`;
  kapatma callback'i prefs yazar + provider'ı invalidate eder.
- **Yeni bağımlılık yok.** Yeni ekran yok. Route değişikliği yok.

## 5. Test

1. Şerit widget testi: ilk render'da görünür → X'e bas → prefs flag
   yazıldı → yeniden pump → görünmez.
2. Prefs erişilemez (null) durumunda şerit görünmez (savunmacı varsayılan).
3. ALTERNATİF sekmesi caption'ı render oluyor (mevcut ürün detay testine
   ekleme ya da yeni küçük test).
4. `addProductIntro` yeni metni: `flutter gen-l10n` sonrası derleme +
   mevcut testlerin kırılmaması (metne exact-match assert eden test var mı
   plan aşamasında taranacak).
5. **Canlı doğrulama (zorunlu — live-device-verification dersi):**
   emülatörde ürün detayı aç → şerit görünüyor mu, X çalışıyor mu,
   yeniden açılışta gelmiyor mu; ALTERNATİF sekmesi caption'ı; bulunamayan
   barkodla not-found ekranı metni. Ekran görüntüsüyle teyit.

## 6. Kapsam dışı (YAGNI — bilinçli)

- Favoriler çoklu-seçim kıyasına ayrıca not (erişim zaten var).
- Scanner ekranına not/rozet.
- Ayarlarda "ipuçlarını sıfırla" girdisi.
- Şeridin farklı ekranlarda (favoriler, geçmiş) tekrarı.
- `compare_hint_dismissed`'in analytics'e işlenmesi (olay eklemek ayrı
  karar; bu iş yalnızca UI notları).

## 7. Başarı kriteri

- `flutter analyze` temiz, tüm testler yeşil (yeni testler dahil).
- Emülatörde 3 notun üçü de görsel olarak doğrulandı (madde 5.5).
- 6 dilin 6'sında da anahtarlar dolu (`untranslated` kalmadı).
- 1.2.2 build'i bu değişikliklerle tetikleniyor.
