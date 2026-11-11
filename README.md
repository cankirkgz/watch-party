# WatchParty

Flutter ile Android ve iOS için senkron YouTube izleme ve çok dilli sohbet uygulaması. Mevcut Firebase projesi: `watch-party-d4610`.

### Şarkı altyazısı

İzleyiciler her zamanki gibi YouTube bağlantısıyla odaya girer. Şarkı sözleri
videonun altında, kişinin uygulama dilinde görünür ve altyazı düğmesiyle
kapatılabilir. WatchParty yeni videoda altyazıyı en fazla altı saniye bekler.
Sonradan gelen çeviri aynı video hâlâ açıksa oynatmanın güncel konumundan
görünür. Altyazı yoksa normal YouTube oynatma kullanılabilir.

Sunucuda her yayınlanabilir kayıt için `_songLyrics/{youtubeVideoId}` belgesi
gerekir. Bu koleksiyona yalnızca Firebase Admin erişir. Belge `enabled: true`,
`language: "tr"` ve `cues: [{startMs, endMs, text}, …]` alanlarını içerir.
Zamanlar ilgili YouTube videosunun başlangıcına göredir, milisaniye cinsindendir
ve satırlar çakışmamalıdır. Yalnızca ilgili ülkelerde GPT ile işlenmesine,
çevirinin gösterilmesine ve önbelleğe alınmasına izin verilen kayıtları
etkinleştirin. Kayıt kimliği tam eşleşir, başka kliplerin sözleri kullanılmaz.
Katalogda belge yoksa GPT çağrısı yapılmaz.

Canlı Türkçe katalog 11 Kasım 2026'da üç anonim türküyle açıldı:

- [Üsküdar’a Gider İken (Kâtibim) — Ezgi Köker](https://www.youtube.com/watch?v=CWOrDXnnmOc)
- [Hey Onbeşli — Doğa İçin Çal](https://www.youtube.com/watch?v=80aWAOrE4GQ)
- [Havada Bulut Yok (Yemen Türküsü) — Doğa İçin Çal](https://www.youtube.com/watch?v=t4DBc0z7ki4)

Bu sürümlerin söz kaynakları ve LRCLIB zaman çizelgeleri
`catalog/traditional-tr.json` dosyasında kayıtlıdır. Katalog anonim geleneksel
sözleri ve zaman kodlarını içerir. Kayıtların kendisi YouTube oynatıcısında açılır.
Bir bağlantıdaki `v` değeri katalogdaki video kimliğiyle eşleşmelidir.

`node functions/test/live-song-subtitles.mjs --live` üç linkin gerçek Firebase
işlevinden Rusça satır döndürdüğünü ve zaman kodlarını koruduğunu denetler.
Bu komut canlı projede geçici bir kullanıcı ve odalar oluşturur, test sonunda
bunları temizler ve önbellek boşsa GPT çağrısı yapar.

Firebase emülatörleri çalışırken Android oda akışını denemek için:

```powershell
node functions/test/seed-song-subtitles.mjs
flutter drive --driver=test_driver/mobile.dart --target=integration_test/song_subtitle_flow_test.dart -d emulator-5558 --dart-define=USE_FIREBASE_EMULATORS=true
```

Bu test yalnızca yerel Firebase'e özgün örnek sözler ve önceden hazırlanmış Rusça
çeviri yazar. Videonun açılmasını, odanın beklemesini, diğer izleyiciden gelen
ileri sarma komutunu ve altyazı düğmesini gerçek Android oynatıcısıyla sınar.

## Yeni deneyim

### 1.1.0 birlikte konuşma ve mesajlaşma

- Klavye açılınca video üstte görünür ve aynı yerel oynatıcıda çalışır. Başlık, zaman çizgisi ve sekmeler yer açar; mesaj alanı klavyenin üzerinde kalır. Dar alanda yanıt önizlemesi yazma alanına taşınır.
- Mesajı sağa kaydırarak metne, fotoğrafa veya ses kaydına yanıt verilebilir. Alıntı, kaynak mesajın kimliğini ve gönderenini saklar. Uzun basma menüsünde 32 emoji vardır; sunucu kuralları aynı listeyi destekler.
- Sesli mesajlarda ses seviyesi çizgisi, geçen süre, duraklat/devam et, yerel dosyadan dinleme, silme ve gönderme vardır. Kayıt en fazla iki dakikadır; geçici dosyalar temizlenir.
- Odanın sağ üstündeki kulaklık simgesi canlı sesli sohbeti ve ses ayarlarını açar. Katılım isteğe bağlı ve mikrofon kapalıdır. Mikrofon aç/kapat, konuşmaları sessize alma, konuşmacı göstergesi ve ayrılma desteklenir. Video sesi ve konuşma sesi bağımsızdır; yerel ayarlar saklanır.
- Canlı mikrofon sesli mesaj kaydında geçici olarak durur. Uygulama arka plana gidince canlı ses bağlantısı kapanır; yeniden katılım kullanıcı eylemi gerektirir. Bu sürüm arka planda telefon görüşmesi hizmeti çalıştırmaz.
- Erken YouTube bağlantı/gömme hatalarında en fazla iki yeni oynatıcı denemesi yapılır; beklerken bağlantı durumu gösterilir. Video sahibinin gerçek gömme yasağı veya ağ erişim engeli aşılamaz.

Canlı ses için **LiveKit Cloud Build** projesi oluşturuldu (Frankfurt veri bölgesi, ajan gözlemlenebilirliği kapalı). Yalnızca WebRTC ses aktarımı kullanılır; kayıt, ajan, konuşma tanıma veya AI çağrısı yoktur. Ücretsiz dahil kullanım sınırı aşılınca yeni istekler reddedilir; [LiveKit kota açıklaması](https://docs.livekit.io/deploy/admin/quotas-and-limits/). Firebase'in mevcut Blaze planındaki callable/Firestore tüketimi ayrı olarak geçerlidir.

`joinVoiceRoom` callable işlevi `europe-west1` bölgesindedir. Firebase oturumu ve oda üyeliği doğrulanır, kullanıcı başına dakikada en fazla 10 bağlantı bileti üretilir. Bilet beş dakika geçerli, tek odaya ve yalnızca mikrofon yayınına yetkilidir; veri/video yayını veya yönetici yetkisi verilmez. Boş ses odası temizlenir; oda sınırı 50 katılımcıdır.

Üretim erişimi Firebase Secret Manager'daki **LIVEKIT_CONFIG** JSON sırrıyla sağlanır: `url`, `apiKey`, `apiSecret`. Telefona özel anahtar gönderilmez. Yerel `.env.local`, `functions/.secret.local` ve kaynak paketinden çıkarılan diğer gizli dosyalar Git'e eklenmez. Ses oturumu ayarları için deneysel SDK API'si kullanıldığından LiveKit 2.13.1 ve flutter_webrtc 1.6.2+hotfix.4 sabitlenmiştir.

Doğrulama: 46 Flutter testi, 5 sunucu testi ve 6 Firebase Emulator kural testi geçti; statik analiz temiz. Android'de gerçek YouTube oynarken iki LiveKit istemcisiyle uzak ses RTP alımı, mikrofon açma, ayrı konuşma seviyesi, konuşmaları susturma ve ayrılma doğrulandı. Yerel ses kaydı, duraklat/devam et, önizleme ve silme de videoyu durdurmadan denendi. Yeni ses paneli beş dilde, 320 piksel genişlik ve %130 yazı ölçeğiyle sınandı. Bu sürümün testlerinde OpenAI çağrısı yapılmadı. Fiziksel Redmi/VPN ve iOS cihazı üzerinde doğrulama yapılmadı.

`integration_test/chat_reply_test.dart` Android'de ayrıca geçti: gerçek sağa kaydırma ve klavye üzerinden gönderilen yanıtın kaynak mesaj kimliği/göndereni, genişletilmiş emoji menüsünden seçilen 🍿 tepkisi sunucudan okunarak doğrulandı. Tam oda testinde metin sonrası gönder düğmesinin yeniden çizimi beklenir; geçici YouTube tamponlaması gerçek medya kullanan test süresini etkileyebilir.

```powershell
# Windows'ta bu terminalde yalnızca mobil derleme; global Flutter ayarını değiştirmez.
$env:FLUTTER_WINDOWS='false'
$env:FLUTTER_LINUX='false'
$env:WATCHPARTY_QA_DEVICE='emulator-5558'
$env:WATCHPARTY_QA_ADB="$env:LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
flutter drive --driver=test_driver/mobile.dart --target=integration_test/room_regression_test.dart -d emulator-5558 --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
flutter build apk --release --target=lib/main.dart
```

Oda testi yerel Firebase kullanır. Gerçek ses aktarımı testi iki kısa LiveKit katılımı kullanır; OpenAI çağrısı yapmaz. Yalnızca mesajlaşma/kayıt kontrollerini tekrar ederken `--dart-define=SKIP_LIVE_VOICE_QA=true` eklenerek tekrar ses kotası kullanılmaz. Otomatik mikrofon izni yalnızca açıkça belirtilen `WatchParty_QA` emülatörüne verilir. Android emülatöründeki YouTube platform görünümünde Flutter görüntüye dönüştürme ekran görüntüsü işlevi takılabildiğinden ekran görüntüleri ADB ile ayrıca alınır.

### 1.0.3 oynatıcı düzeltmesi

- Video yükleme isteği iframe başlatılmadan önce kuyruğa girer. JavaScript komutunun tamamlanması hazır sayılmaz; `cued`, `playing` veya `paused` olayı beklenir. Başlangıç tamamlanmadan senkron komutları çalışmaz, süre henüz bilinmiyorken otomatik seek gönderilmez.
- Yerel embed kimliği Android applicationId / iOS bundle ID ile eşleşir: `https://com.example.watchparty`. Paket kimliği değişirse `nativeYoutubeAppOrigin` da güncellenmelidir.
- YouTube hatası kendi kodunu gösterir; oynatıcı başlatma hatası, gömme yasağı ve ağ bağlantısı aynı mesajla sunulmaz. VPN yönlendirmesi yalnızca bağlantı hatasında gösterilir. Klavye ve okundu mekanizması korunur.
- Sorun bildirilen `XTdU5RSodZ4` videosuyla release APK içinde yeniden üretildi: eski başlatma sırası hata 2, düzeltilen sıra hata 0 ve gerçek oynatma verdi. Duraklatılmış başlangıç, uygulama kimliği ve oynayan videoya katılım ayrı ayrı denendi. 38 Flutter testi geçti.

İsteğe bağlı, Firebase/OpenAI kullanmayan release oynatıcı testi:

```powershell
flutter build apk --release --target=test_driver/player_release_probe.dart
# Bu yalnızca test APK'sıdır. Kullanıcıya verilecek normal paketi ardından üret:
flutter build apk --release
```

Başlatma sıra/olay testleri `test/youtube_player_startup_test.dart` içindedir. Tam Android oda regresyonu da aynı müzik videosunu kullanır. [YouTube hata kodları](https://developers.google.com/youtube/iframe_api_reference#onError), [yerel istemci kimliği](https://developers.google.com/youtube/terms/required-minimum-functionality#embedded-player-api-client-identity).

### 1.0.2 güncellemesi

- Klavye yüksekliği `Scaffold` içeriği yeniden boyutlandırılmadan önce okunur; yazma alanı IME üzerinde kalır. Küçük boş sohbet görünümü kaydırılabilir.
- YouTube, mobil overlay portal yerine doğrudan oda yerleşiminde Android hybrid composition ile çizilir. Oynayan odaya katılımda ilk video `loadVideoById` ile güncel konumdan başlatılır. Başlangıç çağrıları beklenir ve zaman aşımı/hata durumları gösterilir.
- Bağlantı hatasında **Yeniden bağlan** oynatıcıyı yeniden oluşturur; VPN'den uygulamaya dönünce başarısız bağlantı tekrar kurulur. Odanın güncel konumu korunur. VPN'in yalnızca seçili uygulamaları kapsadığı durumda WatchParty'nin de listeye eklenmesi hatırlatılır. Kullanıcının VPN ayarları değiştirilmez; YouTube ülke/ağ erişiminin garanti edildiği iddia edilmez.
- Gönderilmiş mesaj tek tik, karşı taraftaki görünür sohbetin okuma işaretinden sonra çift tik gösterir; bekleyen gönderim saat simgesi kullanır. Okuma imleci `readReceipts/{uid}` içinde tutulur; kapalı sohbet, arka plan ve ekran dışında kalan mesajlar için yeni okuma imleci gönderilmez. Yazımlar kısa süre birleştirilir ve tekrarlar atlanır.
- Okuma kayıtları yalnızca oda üyelerine açıktır. Kullanıcı yalnızca kendi kaydını, gerçek bir gelen mesajın sunucu zamanına kadar ve geriye gitmeden güncelleyebilir.

Bu güncellemede 35 Flutter testi ve 6 Firebase Emulator kural testi geçti. Android'de gerçek YouTube ile geç katılma, paylaşılan pause/seek, gerçek ekran klavyesi üzerinde görünür metin alanı, okuma/çift tik, tam ekran ve simüle edilmiş oynatıcı hatasından toparlanma uçtan uca doğrulandı. Testlerin tamamı yerel Firebase kullandı; OpenAI çağrısı yapılmadı. Arkadaşın fiziksel Redmi Note 11S / Android 13 cihazına erişim yok; o cihaz ve VPN sağlayıcısı üzerinde ayrıca denenmelidir.

- Sıcak kâğıt tonları, sinema bileti esintili çift ekran çizimi, Manrope ve Instrument Serif yazı tipleri; izleme sırasında koyu yeşil salon.
- Adla misafir girişi, e-posta/şifreyle kayıt ve giriş, şifre sıfırlama.
- YouTube watch, youtu.be, Shorts ve embed bağlantılarıyla oda açma; altı karakterli kodla katılma.
- Oynatma, duraklatma ve ileri/geri sarmayı tüm oda için paylaşma. Geç katılma, sunucu zamanıyla konum hesaplama, uygulamaya dönünce ve düzenli aralıklarla konum düzeltme.
- Ortak video sırası; sıradan bir videoyu herkes için başlatma veya kaldırma.
- Anlık sohbet, mesaja yanıt, emoji tepkileri, mesajın yazıldığı video anına dönme.
- Fotoğraf seçme/çekme, gönderim öncesi önizleme, tam ekran fotoğraf yakınlaştırma.
- İki dakikaya kadar ses kaydı, silme, göndermeden önce dinleme ve sesli mesaj oynatma. Başarısız gönderimde metin/kayıt korunur.
- Ülke seçimi ve katılımcı bayrakları; ülke, arayüz dili ve çeviri hedefi birbirinden bağımsızdır.
- Türkçe, İngilizce, Rusça, Almanca ve İspanyolca arayüz; 20 hedef dilde GPT mesaj çevirisi ve isteğe bağlı otomatik çeviri. Özgün metin korunur.
- İlk dil cihazın ülke/bölge ayarından seçilir: TR → Türkçe, RU → Rusça, DE → Almanca, İspanyolca konuşulan ülkeler → İspanyolca, diğer ülkeler → İngilizce. Bölge bilgisi yoksa desteklenen cihaz dili, o da yoksa İngilizce kullanılır. Konum/GPS veya ücretli IP sorgusu yapılmaz.
- Dil ilk açılışta cihazda, girişten sonra hesap profilinde saklanır. Kayıtlı hesap tercihi tekrar girişte geri yüklenir; kullanıcı dil menüsünden veya profilden değiştirebilir. Sohbet çevirisi hedefi bağımsızdır.
- Android/iOS üzerinde mevcut ML Kit cihaz içi çeviri de mesaja basılı tutularak kullanılabilir. İlk kullanımda dil modeli indirilir.
- Sistem paylaşım menüsü, kod kopyalama ve `watchparty://watch/room/ABC234` uygulama bağlantısı.

## Canlı servis durumu — 2 Kasım 2026

Firebase hesabına erişim, aktif Firestore veritabanı, misafir girişi ve iki gerçek Firebase istemcisi arasında oda güncellemeleri doğrulandı. Firestore ve Storage kuralları canlı projeye yayımlandı.

**Blaze/faturalandırma açık ve canlı GPT bağlantısı kuruldu.** `translateMessage` fonksiyonu `europe-west1` bölgesinde yayımlandı; OpenAI anahtarı Secret Manager'da saklanıyor. Storage üyelik denetiminin Firestore'a erişmesi için Firebase Storage servis hesabına gerekli cross-service rolü verildi.

İki gerçek Firebase oturumu ile oynatma, duraklatma ve konum paylaşımı doğrulandı. Tek kısa Rusça mesaj gerçek GPT ile Türkçeye çevrildi; aynı mesajın ikinci isteği önbellekten döndü. 70 baytlık PNG diğer oda üyesince yüklenip okundu. Test odası, dosya, çeviri önbelleği, hız sınırı kaydı ve test hesapları temizlendi. Canlı ücretli testler tekrar döngüsünde çalıştırılmadı.

Maliyet ayarları: sıfır bekleyen örnek, en fazla bir çalışan örnek, 256 MiB bellek, 1/6 CPU ve tek eşzamanlı istek. OpenAI otomatik tekrar denemeleri kapalıdır; sunucu önbelleği ve dakikada kullanıcı başına 30 yeni çeviri sınırı vardır. Eski dağıtım görüntüleri bir gün sonra otomatik temizlenir. Bu ayarlar toplam harcamaya parasal bir üst sınır koymaz; önceki bütçe alarmı hatasının giderildiği doğrulanmadı.

[Firebase proje konsolu](https://console.firebase.google.com/project/watch-party-d4610/overview). Yeniden dağıtım için:

```powershell
node scripts/publish-openai-secret.mjs
Copy-Item functions/.env.example functions/.env.watch-party-d4610
npx firebase-tools deploy --only functions:watchparty,firestore:rules,storage --project watch-party-d4610
```

Anahtar onaylanan, Git tarafından yok sayılan kök `.env.local` dosyasındadır. Yalnızca sunucu/yerel test betikleri okur. Flutter `assets` içine veya `dart-define` ile uygulamaya eklenmez. Yukarıdaki betik anahtarı stdout'a yazmadan Firebase Secret Manager'a aktarır.

## Çalıştırma

```powershell
flutter pub get
flutter run -d <android-cihaz-id>
flutter build apk --release
```

Android: minimum API 24, compile/target 36, Java 17 uyumluluğu. iOS: minimum 15.5; derleme ve gerçek cihaz doğrulaması macOS/Xcode gerektirir. Mevcut `com.example.watchparty` paket adı ve test imzası korunmuştur; mağaza dağıtımı için kalıcı paket kimliği ve yayın imzası gerekir.

## Yerel sunucu ve uçtan uca test

Node 22 ve Java 21+ önerilir. Firebase emülatörleri gerçek kullanıcı verisini kullanmaz. OpenAI çevirisi yerel emülatörde de gerçek API kullanır.

```powershell
npm --prefix functions ci
node scripts/emulators.mjs
flutter run --dart-define=USE_FIREBASE_EMULATORS=true
# Android Emulator varsayılan host: 10.0.2.2. Fiziksel cihaz için:
# --dart-define=FIREBASE_EMULATOR_HOST=<bilgisayarın-yerel-adresi>
```

Başka bir terminalde:

```powershell
flutter test
npm --prefix functions test
npx firebase-tools emulators:exec --only firestore,storage --project demo-watchparty-rules "npm --prefix functions run test:rules"
node functions/test/openai-smoke.mjs
node functions/test/live-flow.mjs --emulator
flutter drive --driver=test_driver/mobile.dart --target=integration_test/mobile_flow_test.dart -d <emulator-id> --dart-define=USE_FIREBASE_EMULATORS=true
```

`live-flow.mjs --serve` yalnızca geliştirme içindir; ayrı test oturumları açar. İsteğe bağlı yerel QA kontrolü 127.0.0.1:4377'de dinler. Canlı test bu aracı kullanırsa oluşturulan `QA...` test odası ve test profilleri sonrasında temizlenmelidir.

## Veri ve yetkiler

- `users/{uid}`: görünen ad, ülke, arayüz dili, çeviri hedefi ve otomatik çeviri tercihi.
- `rooms/{code}`: video, sıra, katılımcılar, `currentTime`, `isPlaying`, `lastUpdatedAt`, `syncEventId`.
- `rooms/{code}/messages/{id}`: metin/fotoğraf/ses, kaynak dil, ülke, yanıt, video anı ve kullanıcı başına tek emoji.
- `rooms/{code}/presence/{uid}`: 25 saniyelik kalp atışı; 90 saniyeden eski katılımcılar gizlenir.
- `rooms/{code}/readReceipts/{uid}`: görülen son gelen mesajın `messageId`, `readThrough` ve `updatedAt` alanları; mesaj başına ayrı yazım yerine okuma imleci.
- `rooms/{code}/_translations/{messageId_language}` ve `_translationLimits/{uid}`: yalnızca sunucu erişir.
- Storage `room_media/{roomId}/{uid}/{file}`: yalnızca oda üyeleri okuyabilir; üye kendi dizinine 20 MB altında fotoğraf/ses ekleyebilir.

GPT callable fonksiyonu kullanıcı kimliğini ve oda üyeliğini kontrol eder. Metni mesaj kimliğiyle Firestore'dan alır; istemciden serbest çeviri metni kabul etmez. Metin sınırı 2000 karakter, hedef dil doğrulaması, kullanıcı başına dakikada 30 yeni çeviri ve sunucu önbelleği vardır. OpenAI isteğinde `store: false` kullanılır. Çeviri otomatik üretildiği için özgün mesaj her zaman erişilebilir kalır.

Font lisansları `assets/fonts/*-OFL.txt` içindedir.
