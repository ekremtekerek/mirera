# Mirera — Android

## Üç ön ayar, tek fark

| ön ayar | özellik etiketi | reklam birimi | nereye |
|---|---|---|---|
| `Android APK (test)` | — | **test** | telefona doğrudan kurulum |
| `Android AAB` | — | **test** | iç test, alfa, beta |
| `Android AAB (yayin)` | `liveads` | **canlı** | yalnızca üretim |

```bash
tools/android_build.sh test      # telefona kurulacak APK
tools/android_build.sh aab       # test reklamlı AAB
tools/android_build.sh yayin     # CANLI reklamlı AAB
```

**İmza parolası depoya girmiyor.** Godot'un yayın imzası ya ön ayarın içine
ya ortam değişkenlerine yazılıyor; ön ayara yazmak parolayı
`export_presets.cfg` üzerinden depoya sokar. `tools/android_build.sh`
parolayı depo dışındaki `D:/Tools/android-keys/mirera-upload.README.txt`
dosyasından okuyup yalnızca o sürece veriyor.

**Neden iki AAB ön ayarı.** Foldera'da kural "hata ayıklama değilse canlı"
idi ve iç teste giden derlemeye **canlı** reklam birimi koyuyordu. Kendi
reklamına tıklamak AdMob politikası ihlali ve hesap askıya alma sebebi —
üstelik sessizce olur. Şimdi hata yönü tersine: etiketi unutursan üretimde
test reklamı çıkar, gelir sıfır olur ama zarar vermez ve ilk raporda fark
edilir.

**Her yüklemeden önce `version/code` artırılmalı** — üç ön ayarda birden.
Play aynı sürüm kodunu ikinci kez kabul etmiyor.

## Cihazda ilk bakılacak satır

```
[ads] saglayici: admob  PoingGodotAdMob kayitli mi: true
[ads] birim kipi: TEST  interstitial=ca-app-pub-3940256099942544/1033173712
```

`stub / false` yazıyorsa AdMob devrede değil ve **reklam geliri sıfırdır** —
oyun sorunsuz görünse bile.

## Yayın öncesi kapatılacak iki madde

Şu an ikisi de **açık**, ve testler bunu her çalıştırmada söylüyor:

1. **AdMob uygulaması açılmadı.** `LIVE_INTERSTITIAL` / `LIVE_REWARDED`
   boş, `admob/general/android/app_id` Google'ın test kimliği. Üçü birlikte
   güncellenecek — biri eksik kalırsa istekler test uygulamasına gider.
2. **AdMob uygulaması Play mağaza girişine bağlanmadı.** Bağlanmadan durum
   *"Sınırlı reklam sunumu"* kalıyor ve dolgu neredeyse sıfır oluyor.
   Bağlama **yayına çıkmadan yapılamıyor**: AdMob'un arama kutusu mağazada
   olmayan paket adını bulamıyor. Sıra: Play incelemesi biter → mağazada
   görünür → AdMob > Uygulamalar > Mağaza ekle.

## Derleme ortamını sıfırdan kurmak

Godot'nun `--install-android-build-template` bayrağı **başsız kipte sessizce
hiçbir şey yapmıyor** — hata da vermiyor, klasör de oluşmuyor. Şablon elle
açılıyor:

```bash
unzip -q -o "$APPDATA/Godot/export_templates/4.7.1.stable/android_source.zip" -d android/build
echo "4.7.1.stable" > android/.build_version
: > android/.gdignore          # <-- bunu unutma, aşağıya bak
```

`android/` depoya girmiyor (207 MB, tamamen üretilebilir).

Yollar düzenleyici ayarlarından geliyor, projeden değil —
`editor_settings-4.7.tres` içinde:

| ayar | değer |
|---|---|
| `export/android/java_sdk_path` | `D:/Tools/jdk17/jdk-17.0.20.1+1` |
| `export/android/android_sdk_path` | `D:/Tools/android-sdk` |
| `export/android/debug_keystore` | `D:/Tools/android-keys/debug.keystore` |

## Yedi tuzak

Hepsi **sessiz**: oyun derleniyor, açılıyor, oynanıyor ve tek bir hata
mesajı vermeden yanlış çalışıyor. Yedisi de artık `t_kurulum()` testiyle
sabitlenmiş durumda — liste unutulur, test düşer.

**1. Tek dokunuş, iki olay.** Android'de `emulate_mouse_from_touch` açık
(varsayılan): parmak önce bir `InputEventScreenTouch`, ardından onun kopyası
olan **sahte bir fare tıklaması** üretiyor. İkisi de işlenirse ayna iki kez
döner, yani hiç dönmemiş gibi görünür. Sahte olayların cihaz kimliği
`DEVICE_ID_EMULATION` (-1); `board_view.gd` onu eliyor. **Masaüstünde bu
hata görünmüyor** çünkü orada yalnızca fare olayı var.

**2. `handheld/orientation` bir tam sayı.** 0=YATAY (varsayılan), 1=DİKEY.
Metin (`"portrait"`) yazılırsa sessizce yok sayılıyor ve oyun telefonda
yatay açılıyor. Doğrulaması: `aapt dump xmltree ... | grep screenOrientation`
→ `0x1` olmalı.

**3. `project.godot` içinde `##` yorumu.** Dosya bir ConfigFile ve yorum
karakteri **tek noktalı virgül**. `##` ile yazılan bir yorum bölüm
başlıklarının ayrıştırılmasını bozuyor: `[editor_plugins]` sessizce
kayboluyor, eklentiler **kayıtsız** sayılıyor, AdMob ve Billing derlemeye
hiç girmiyor. Belirti, derleme günlüğünde bir satırın **yokluğu**:

```
Exporting Poing AdMob '.cfg' file     <- bu satır yoksa eklenti çalışmadı
```

**4. `android/.gdignore`.** Resmî "Android derleme şablonunu kur" işlemi
`android/` içine boş bir `.gdignore` bırakıyor. Şablonu elle açarken bu
unutulursa düzenleyici `android/` altını normal proje içeriği sanıyor:
**ilk derleme geçiyor**, ikincisi kendi çıktısını yeniden içine alıp kat kat
derinleşen yollarda çöküyor. Hata mesajı eksik bir dosyadan söz ettiği için
asıl nedeni göstermiyor.

**5. Çeviri tablosu pakete girmiyor.** Yanında `.import` olan bir dosya dışa
aktarıma **girmiyor**: içeri aktarma işleyicisi onu her dil için bir
`Translation` kaynağına çevirip kaynak dosyayı dışarıda bırakıyor.
`FileAccess.open("res://locale/mirera.csv")` düzenleyicide çalışıyor, APK
içinde null dönüyor — yani telefonda bütün metinler `BTN_PLAY` gibi anahtar
adlarına düşüyor. `loc.gd` bu yüzden CSV'yi değil `.translation`
kaynaklarını yüklüyor.

**6. Reklam SDK'si hiç başlamıyor.** Fusera'da UMP rıza akışı yerine
`if consent_mode != "": _init_sdk()` vardı; `Save.consent` ilk kurulumda
`""` ve hiçbir yerde doldurulmuyor, yani `MobileAds.initialize()` hiç
çağrılmıyor. Tek bir reklam isteği çıkmıyor, kod doğru görünüyor, gelir
sıfır. Doğrusu: UMP rıza akışı **artı iki gözcü** — biri rıza akışı hiç
dönmezse, diğeri SDK başlatma geri çağrısı hiç dönmezse devreye giriyor.
İkincisi Foldera'da eksikti ve panoda iki gün "istek: 0" görüldü.

**7. AdMob uygulaması mağazaya bağlı değil.** Yukarıdaki "yayın öncesi"
maddesine bak. Kodda hiçbir belirti yok: SDK başlıyor, birim kimlikleri
doğru, yalnızca reklam gelmiyor.

## Play ürünleri

`no_ads` (tek seferlik) ve `hints_10` (tüketilebilir).

**Sıra önemli:** Play, `com.android.vending.BILLING` izni taşıyan bir
derleme yüklenmeden ürün oluşturmaya izin vermiyor. Önce billing'li AAB'yi
bir kanala yükle, sonra ürünleri oluştur.
