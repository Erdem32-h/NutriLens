# Su ile geri dönüş (Seçenek 2) — kısa plan

**Dal:** `feat/water-retention` (`feat/water-card-top` üzerine; commit/push yok)
**Hedef:** İlk gün su ekleyenlerin 1-7. günde geri gelmesi. Şu an (60 gün): tüm cihazlar 140/756 (%19), su ekleyenler 14/48 (%29), hatırlatıcı açanlar 6/28 (%21).
**Anti-hedef:** Seri sayacı yok, baskı yok, suçlayıcı bildirim yok. Uygulamayı açmayan kullanıcıya bildirim birikmez.

## Bugünkü durum
- Su hatırlatıcısı: 09-21 arası 7 sabit saat. Son bardaktan sonra 2 saat sessiz kalır, hedef dolunca biter. Bugünün kalan saatleri ve yarının 7 saati önceden kurulur.
- Öğün hatırlatıcısı: saat 19:00'da tek bildirim; o gün öğün girilmişse kurulmaz.
- Bildirime dokunma ölçülmüyor. Bildirimin birini geri getirip getirmediği bilinmiyor.
- Su kartı ile kalori özeti (`_DailyTargetSummary`) Öğünler ekranında ayrı kartlar ve aralarında grafik var.

## Görevler

### 1. Bildirim açılışını ölç
- `NotificationService.init` → `onDidReceiveNotificationResponse` ve `getNotificationAppLaunchDetails` ile `FunnelEvents.notificationOpened` olayı, `{'type': 'water'|'meal'}`. Her bildirim `payload` taşır.
- Test: bir yanıt geldiğinde olay doğru `type` ile bir kez yazılır.

### 2. Hatırlatıcı zamanlaması: daha az, sadece gerideysen
- `waterReminderHours` = `[10, 13, 16, 19]` (günde en fazla 4).
- Yeni kural: bugünkü bir saat yalnızca kullanıcı o saatte beklenen temponun gerisindeyse kalır. Beklenen tempo `ceil(goal × (saat − 8) / 12)`. Bardak sayısı yalnızca uygulamadan değiştiği ve her değişiklikte yeniden kurulduğu için kural doğru çalışır.
- Bugün ve yarın dışında bir şey kurulmaz. Uygulama 2 gün açılmazsa bildirim durur. Bu zaten böyle; testle sabitlenir.
- Metin: `waterReminderSchedule` ve `waterReminderPrompt` 6 dilde güncellenir, örneğin "Gerideysen günde en fazla 4 kez". Bildirim gövdesi nötr kalır.
- Ramazan saatleri (`ramadanWaterTimes`) değişmez.
- Testler `water_reminder_schedule_test` içinde:
  - 4 saat kurulur.
  - Tempoda olan kullanıcıya bugünkü saat kurulmaz, gerideki kullanıcıya kurulur.
  - Hedef dolunca bugün için hiçbir saat kurulmaz.
  - Yarın her zaman 4 saat kurulur.

### 3. "Bugün" kartı ve günlük ilerleme
- Öğünler sekmesinin en üstünde tek kart: başlık "Bugün" ve tarih.
  - **Su satırı:** mevcut `WaterCard` içeriği (+1 bardak, bardaklar).
  - **Öğün satırı:** "N öğün · X / Y kcal" ve ilerleme çubuğu. Hiç öğün yoksa "Öğün ekle" butonu tarayıcıyı açar.
- `_DailyTargetSummary` bu kartın içine taşınır, tıbbi uyarı satırı korunur. Kalori grafiği kartın altında kalır.
- Dil övgü/nötr: "Hedefe ulaştın" var, "kaçırdın" yok.
- Testler:
  - Kart grafiğin üstünde.
  - Sıfır öğünde "Öğün ekle" görünür.
  - Öğün varken sayı ve kalori görünür.
  - Mevcut su kartı testleri geçmeye devam eder.

### 4. Doğrula
- `flutter analyze` ve tüm testler.
- Emülatör ekran görüntüsü: Türkçe arayüz, 1.3 yazı ölçeği.

## Ölçüm (yayından ~2 hafta sonra)
- Su ekleyenlerin 1-7. gün dönüşü: %29 → hedef %35+.
- `notification_opened` / kurulan bildirim oranı.
- Hatırlatıcı kapatma sayısı artmamalı.

## Kapsam dışı
- Seri sayacı.
- Bildirim iznini ilk öğün kaydından sonra sorma (ayrı iş).
- Öğün hatırlatıcısının saatini değiştirme.
