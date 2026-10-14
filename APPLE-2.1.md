# Apple — Guideline 2.1 "Information Needed" (13 Eki 2026)

MIRERA 1.0 App Review'dan **Guideline 2.1 – Information Needed – New App
Submission** aldı. App Store Connect'te "Rejected" görünüyor ama **bu bir
kusur bildirimi değil**: yeni geliştirici hesaplarına sorulan standart bilgi
talebi. Apple'ın kendi cümlesi:

> This app has been submitted by a developer account that has a limited App
> Review history. We need additional information to better understand the app
> and complete the review.

FOLDERA 1.0 da aynı gün, aynı dakikada (07:29) birebir aynı mesajı aldı.
SMS Onay 1.0.3 de aynı talebi almıştı — yani hesaba özgü, uygulamaya değil.

## Apple'ın istediği altı madde

| # | İstenen | Durum |
|---|---|---|
| 1 | Fiziksel cihazda çekilmiş ekran kaydı | **eksik — kullanıcıda** |
| 2 | Amaç ve hedef kitle | yazıldı |
| 3 | Kurulum ve özelliklere erişim yönergesi | yazıldı |
| 4 | Kullanılan dış servisler | yazıldı |
| 5 | Bölgesel farklar | yazıldı |
| 6 | Düzenlenmiş sektör / üçüncü taraf materyal | yazıldı |

2–6 maddelerin tam metni `store/apple-review-notes.txt` içinde ve
**App Store Connect'teki App Review Information → Notes alanına yüklendi**
(`node tools/appstore_kurulum.mjs`). Apple bunu açıkça istiyor: *"also add
this information to the Notes field ... for reference on future
submissions"*.

## Eksik olan tek şey: ekran kaydı

Apple'ın şartı: **fiziksel cihazda**, **en güncel iOS**'ta, **uygulamanın
açılışıyla başlayan** ve tipik kullanıcı akışını gösteren bir kayıt.

MIRERA için bu çok kısa: giriş yok, hesap yok, satın alma yok. 60–90 saniye
yeter.

**Kayıtta olması gerekenler, sırayla:**

1. Ana ekrandan uygulamayı aç (kayıt uygulama açılmadan önce başlamalı)
2. İlk bölüm açılsın, bir aynaya dokun — ışının anında yeniden çizildiği
   görünsün
3. Işını hedefe ulaştırıp bölümü bitir, yıldız ekranı görünsün
4. Sonraki bölüme geç, birkaç dokunuş daha
5. Tema ekranını kısaca göster

**Nasıl çekilir:** Paket zaten TestFlight'ta. iPhone'a TestFlight'tan kurun,
Ayarlar → Denetim Merkezi → **Ekran Kaydı**'nı ekleyin, denetim merkezinden
başlatıp oyunu oynayın, durdurun. Video Fotoğraflar'a düşer.

> Simulator kaydı riskli: Apple açıkça "physical device" diyor. Elde iPhone
> yoksa Mac'teki Simulator'dan çekilebilir ama aynı sebeple ikinci kez
> reddedilme ihtimali var.

## Gönderme sırası — ÖNEMLİ

**Video hazır olmadan "Resubmit to App Review"e BASMA.** Videosuz yeniden
gönderim aynı sebeple tekrar reddediliyor. 2.1 bilgi talebinde süre baskısı
yok; uygulama cevap bekler durumda askıda kalıyor.

Sıra:

1. Videoyu çek
2. ASC → Mirera → **App Review** → ilgili gönderim → **Reply**
3. Aşağıdaki metni yapıştır + videoyu ekle
4. Gönder, sonra **Resubmit to App Review**

## Resolution Center'a yapıştırılacak metin

```
Hello,

Thank you for the review. Please find the requested information below. The
same text has also been added to the Notes field in App Review Information.

1. SCREEN RECORDING
Attached. It was captured on a physical iPhone running the latest iOS and
begins with launching the app from the Home Screen. The app has no account
registration, login or deletion flow, no user-generated content and no paid
content, so none of those flows appear in the recording.

2. PURPOSE AND TARGET AUDIENCE
Mirera is a light-routing puzzle. A beam leaves the source and travels in a
straight line; tapping a mirror turns it ninety degrees. The player bends the
beam until it reaches the target. The audience is casual puzzle players of any
age who want a calm game with no timers, no lives and no pressure. Nothing is
hidden: the beam is redrawn the instant a mirror is touched, so the player
always sees exactly what the move did. Every level is built backwards from its
own solution, so an unsolvable board cannot exist. Three stars means the
player used the fewest possible taps, a number the game computes before the
level starts.

3. SETUP AND ACCESS
There is nothing to set up. Launch the app and the first level starts. There
is no account, no login, no registration and no configuration screen, so no
credentials are needed to review the app. Levels are generated and verified on
the device and never run out; the entire app works offline, including in
airplane mode. Walls and spare mirrors appear automatically as the player
progresses. Themes unlock by collecting stars and change colours only.

4. EXTERNAL SERVICES
Google AdMob (Google Mobile Ads SDK) for advertising is the only external
service the app contacts. There is no backend of our own, no authentication
service, no payment processor, no AI service and no third-party analytics
SDK. The app is built with Godot Engine 4.7.

There are no in-app purchases on iOS: the purchase layer in the codebase is
Google Play Billing only and is disabled on this platform, so no purchase or
restore controls are shown.

5. REGIONAL DIFFERENCES
None. The app behaves identically in every region. It is localized into 13
languages (text only; the puzzles, rules and content are the same
everywhere). Advertising is non-personalised in all regions: the app does not
present an App Tracking Transparency prompt and requests non-personalised ads
only, which is why the App Privacy labels declare no tracking.

6. REGULATED INDUSTRY OR PROTECTED MATERIAL
Not applicable. The app is a self-contained puzzle game in no regulated
industry. All artwork, audio, level data and source code are original work by
the developer, which matches the content rights declaration on this listing.

Kind regards,
Hasan Ekrem Tekerek
```
