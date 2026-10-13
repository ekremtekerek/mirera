class_name AdMobAdProvider
extends AdProvider
##
## Gercek AdMob saglayicisi (poing-studios/godot-admob-plugin v5).
##
## Bu dosyadaki her gozcu ve her `asama` atamasi YASANMIS bir arizanin
## karsiligi. Ortak ozellikleri sessiz olmalari: oyun kusursuz calisiyor,
## saglayici "admob" gorunuyor, dugmeler cikiyor, yalnizca hicbir reklam
## gelmiyor ve AdMob panosunda "istek: 0" yaziyor. Gunlerce fark edilmiyor.

const TEST_INTERSTITIAL := "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED := "ca-app-pub-3940256099942544/5224354917"
## Gercek birimler (yayinci ca-app-pub-6484682017091395). Yalnizca
## "liveads" etiketi tasiyan derlemede kullanilirlar.
##
## AdMob uygulamasi 2026-09-04'te acildi ve Play magaza girisine
## baglandi -- baglanti sart, yoksa sunum "sinirli" kaliyor.
##
## Uygulama kimligi AYRI bir yerde: project.godot > [admob] >
## general/android/app_id. Orasi bos kalirsa eklenti manifest e
## Google'in TEST uygulama kimligini yaziyor ve birimler dogru olsa
## bile hicbir istek gelmiyor -- 1.0.1 tam olarak boyle yayinlandi.
const LIVE_INTERSTITIAL := "ca-app-pub-6484682017091395/9209801793"
const LIVE_REWARDED := "ca-app-pub-6484682017091395/3901634794"

##
## iOS AYRI BIR UYGULAMA ve ayri birimler.
##
## AdMob'da uygulama PLATFORM BASINA aciliyor: Mirera'nin Android kaydi
## ve iOS kaydi birbirinden bagimsiz iki uygulama, iki ayri kimlik.
## Android birimlerini iOS'te kullanmak istekleri YANLIS uygulamaya
## yazar; AdMob bunu hata saymaz, yalnizca raporlar karisir.
##
## 2026-10-13'te acildi (iOS uygulamasi ...~7013735481). Magaza
## baglantisi HENUZ YOK, yani sunum ilk yayina kadar SINIRLI kalacak.
## Yayindan sonra AdMob > uygulama ayarlari > magazaya ekle adimi
## yapilacak ve TAM MAGAZA URL'siyle aranacak; paket adiyla arama
## bulmuyor.
const LIVE_INTERSTITIAL_IOS := "ca-app-pub-6484682017091395/8412693043"
const LIVE_REWARDED_IOS := "ca-app-pub-6484682017091395/1564388673"

const SHOW_TIMEOUT := 90.0
const RELOAD_DELAY := 3.0

##
## Riza akisi askida kalirsa SDK'yi yine de baslatan gozcunun suresi.
## KASTEN uzun: AB'de riza formu gercekten gosteriliyorsa oyuncunun okuyup
## secmesi icin zaman birakmali. Form kapaninca `_init_sdk()` zaten kendi
## yolundan cagriliyor ve gozcu bos donuyor -- yani gozcu YALNIZCA hicbir
## sey olmadiginda devreye giriyor.
const CONSENT_TIMEOUT := 12.0
const INIT_TIMEOUT := 10.0


##
## CANLI reklam birimi ACIK IZIN ister: yalnizca "liveads" ozellik etiketi
## tasiyan derleme gercek birimleri yukler.
##
## Yon KASTEN boyle. Foldera'da kural "hata ayiklama degilse canli" idi ve
## bu, ic teste giden derlemeye CANLI birim koyuyordu -- kendi reklamina
## tiklamak AdMob politikasi ihlali ve hesap askiya alma sebebi. Simdi
## unutmak zararsiz tarafa dusuyor: etiketi koymazsan uretimde test reklami
## cikar, gelir sifir olur ama hesap risk almaz ve ilk raporda fark edilir.
var _live := (OS.has_feature("liveads") and not OS.is_debug_build()
	and canli_birimler_hazir())
var interstitial_id := canli_inter() if _live else TEST_INTERSTITIAL
var rewarded_id := canli_rew() if _live else TEST_REWARDED


## Platforma gore canli birim. Tek yerde secilmesi onemli: iki ayri
## kosul yazilirsa biri gun gelir guncellenmeden kalir.
static func _apple() -> bool:
	return OS.get_name() == "iOS"


static func canli_inter() -> String:
	return LIVE_INTERSTITIAL_IOS if _apple() else LIVE_INTERSTITIAL


static func canli_rew() -> String:
	return LIVE_REWARDED_IOS if _apple() else LIVE_REWARDED


## Uygulama kimliginin BULUNDUGU ayar da platforma bagli. Eklenti
## ikisini ayri tutuyor ve iOS'inki kurulmazsa Google'in TEST kimligini
## koyuyor.
static func app_id_ayari() -> String:
	return "admob/general/ios/app_id" if _apple() \
		else "admob/general/android/app_id"

var _interstitial: InterstitialAd = null
var _rewarded: RewardedAd = null
var _inter_loader: InterstitialAdLoader = null
var _rew_loader: RewardedAdLoader = null
var _consent: ConsentInformation = null
var _initialized := false
var _preloaded := false


##
## Canli birimler DOLDURULDU mu.
##
## Bos bir birim kimligiyle AdMob istegi sessizce basarisiz oluyor: oyun
## kusursuz calisiyor, reklam hic gelmiyor, gelir sifir. "liveads" etiketli
## bir derleme alinip birimler unutulursa bunun magazada fark edilmesi
## haftalar surer -- Foldera'da tam olarak boyle uc tur kaybettik.
##
## O yuzden eksikse CANLIYA GECILMIYOR: test birimiyle devam ediliyor ve
## gunluge hata basiliyor. Gorunur bir "test reklami" yanlis kimlikle
## sessizce olmekten iyidir.
##
## UYGULAMA KIMLIGI de sayiliyor. Birimler dogru olsa bile
## project.godot > [admob] > general/android/app_id bos birakilirsa
## eklenti manifest'e GOOGLE'IN TEST uygulama kimligini yaziyor; SDK
## acilis yapiyor, oyun kusursuz gorunuyor ve hicbir istek sayilmiyor.
## Mirera 1.0.1 tam olarak boyle yayinlandi ve sifir kazandi.
const TEST_APP_ID := "ca-app-pub-3940256099942544~3347511713"

static func canli_birimler_hazir() -> bool:
	var app_id := str(ProjectSettings.get_setting(app_id_ayari(), ""))
	return (canli_inter() != "" and canli_rew() != ""
		and app_id != "" and app_id != TEST_APP_ID)


##
## Eklentinin CALISMA ZAMANI kaydini soruyoruz -- dosya varligini ya da
## ozellik etiketini degil.
##
## Foldera'da bu satir IKI kere yanlisti ve ikisi de sessizdi:
##   OS.has_feature("mobile")  -> "mobile" bir ISLEYICI adi; gl_compatibility
##                                kullanan projede Android'de bile false.
##   ResourceLoader.exists(cfg) -> `.cfg` Godot kaynagi degil; dosya pakette
##                                dururken bile her platformda false.
## Ikisi birlikte cihazda sahte saglayicinin secilmesine yol acti.
static func is_available() -> bool:
	return Engine.has_singleton("PoingGodotAdMob")


func provider_name() -> String:
	return "admob"


## Tek atislik sonuc kanali: geri cagri tabanli SDK ile await eden oyun
## kodu arasindaki kopru. Ikinci kez cozulemez.
class Waiter extends RefCounted:
	signal done(ok: bool)
	var _resolved := false
	func resolve(v: bool) -> void:
		if _resolved:
			return
		_resolved = true
		done.emit(v)


func initialize(consent_mode: String) -> void:
	super.initialize(consent_mode)
	if not is_available():
		push_warning("[admob] eklenti kayitli degil -- bu saglayici secilmemeliydi")
		return
	# Etiket canli diyor ama birimler bos: sessizce test reklamina dusuyoruz.
	# Gunluge HATA olarak basiliyor cunku bu, yayindaki bir derlemede gelirin
	# tamamini kaybettiren ve baska hicbir belirtisi olmayan bir durum.
	if OS.has_feature("liveads") and not canli_birimler_hazir():
		push_error("[ads] liveads etiketi var ama LIVE_* birim kimlikleri bos"
			+ " -- test reklamiyla devam ediliyor, GELIR SIFIR")
	_inter_loader = InterstitialAdLoader.new()
	_rew_loader = RewardedAdLoader.new()
	# Yukleyiciler RefCounted, Node degil -- sahneye eklenmiyorlar.
	_request_consent()


# ------------------------------------------------------------------- riza

##
## Once UMP riza akisi, SONRA SDK baslatma.
##
## Sira onemli: AB/Birlesik Krallik'ta riza alinmadan reklam istegi atmak
## politika ihlali. UMP cogu ulkede "gerekli degil" dondugu icin akis
## kendiliginden ilerliyor.
##
## Riza adimi HER TURLU SDK baslatmaya devam ediyor: hata durumunda oyuncuyu
## reklamsiz birakmak yerine kisisellestirilmemis reklam gostermek dogru olan.
##
## BURASI FUSERA'DA YANLIS. Orada riza akisi hic yok; yerine
## `if consent_mode != "": _init_sdk()` konmus. `Save.consent` ilk kurulumda
## "" ve HICBIR YERDE doldurulmuyor -- yani SDK hic baslamiyor, tek bir
## reklam istegi cikmiyor. Kod dogru gorunuyor, oyun calisiyor, gelir sifir.
func _request_consent() -> void:
	asama = "riza"
	_gozcu_baslat()
	_consent = ConsentInformation.new()
	_consent.update(
		ConsentRequestParameters.new(),
		func() -> void:
			if _consent.get_is_consent_form_available():
				_load_consent_form()
			else:
				_init_sdk(),
		func(form_error: FormError) -> void:
			push_warning("[admob] UMP riza guncellemesi basarisiz: %s" % form_error.message)
			_init_sdk()
	)


func _load_consent_form() -> void:
	UserMessagingPlatform.load_consent_form(
		func(form: ConsentForm) -> void:
			form.show(func(_err: FormError) -> void: _init_sdk()),
		func(form_error: FormError) -> void:
			push_warning("[admob] UMP formu yuklenemedi: %s" % form_error.message)
			_init_sdk()
	)


##
## BIRINCI gozcu: riza akisi hicbir geri cagri vermezse SDK'yi yine de
## baslatir. `_init_sdk()` zaten `_initialized` ile korunuyor, iki kez
## calismiyor.
func _gozcu_baslat() -> void:
	await get_tree().create_timer(CONSENT_TIMEOUT).timeout
	if _initialized:
		return
	push_warning("[admob] riza akisi %s sn icinde donmedi -- SDK yine de baslatiliyor"
		% CONSENT_TIMEOUT)
	_init_sdk()


func _init_sdk() -> void:
	if _initialized:
		return
	_initialized = true
	# Hangi birimlerin yuklendigi logcat'te acikca gorunsun: yanlis kipte
	# yayina cikmak sessizce olmasin.
	print("[ads] birim kipi: ", "CANLI" if _live else "TEST",
		"  interstitial=", interstitial_id)
	asama = "sdk"
	var on_init := OnInitializationCompleteListener.new()
	on_init.on_initialization_complete = func(_status: InitializationStatus) -> void:
		preload_all()
	MobileAds.set_request_configuration(RequestConfiguration.new())
	MobileAds.initialize(on_init)
	_yukleme_gozcusu()


##
## IKINCI gozcu: SDK baslatma geri cagrisi donmezse yuklemeyi yine de
## baslatir.
##
## Foldera'da riza adimina gozcu konuldu ama BIR KAT ASAGIDAKI ayni tuzak
## acikta kaldi: `preload_all()` yalnizca `on_initialization_complete`
## icinde cagriliyordu. O geri cagri donmezse tek bir reklam istegi
## cikmiyor -- hata yok, saglayici hala "admob", "reklam izle" dugmesi
## cikiyor, panoda istek SIFIR. Iki gun boyunca tam olarak bu goruldu.
func _yukleme_gozcusu() -> void:
	await get_tree().create_timer(INIT_TIMEOUT).timeout
	if _preloaded:
		return
	push_warning("[admob] SDK baslatma %s sn icinde donmedi -- yukleme yine de baslatiliyor"
		% INIT_TIMEOUT)
	preload_all()


# ---------------------------------------------------------------- yukleme

func preload_all() -> void:
	# Ikinci gozcu bunu tekrar cagirabilir; yukleyiciler tek atislik oldugu
	# ve basarisizlikta kendi yeniden deneme dongusu bulundugu icin zararsiz.
	_preloaded = true
	asama = "yukleme"
	_load_interstitial()
	_load_rewarded()


##
## iOS ISTEKLERINDE KISISELLESTIRME KAPALI.
##
## Eklenti ATT (izleme izni) istemini hic sunmuyor -- yalnizca
## AppTrackingTransparency.framework bagli, cagri arayuzu yok. ATT onayi
## olmadan iOS zaten IDFA erisimini kesiyor; `npa=1` ile bunu Google'a
## acikca soyluyoruz. App Store gizlilik etiketinde bu yuzden izleme YOK
## yazili -- etiket ile kodun ayni seyi soylemesi sart, aksi Guideline
## 5.1.2'den ret sebebi.
##
## Android'de degisiklik yok: riza akisini UMP yonetiyor.
func _istek() -> AdRequest:
	var r := AdRequest.new()
	if _apple():
		r.extras["npa"] = "1"
	return r


func _load_interstitial() -> void:
	if _inter_loader == null or interstitial_id == "":
		return
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_interstitial = ad
		state_changed.emit()
	cb.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_interstitial = null
		son_hata = error.message
		basarisiz += 1
		state_changed.emit()
		_retry(_load_interstitial, "gecis", error.message)
	_inter_loader.load(interstitial_id, _istek(), cb)


func _load_rewarded() -> void:
	if _rew_loader == null or rewarded_id == "":
		return
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		_rewarded = ad
		asama = "hazir"
		state_changed.emit()
	cb.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_rewarded = null
		son_hata = error.message
		basarisiz += 1
		state_changed.emit()
		_retry(_load_rewarded, "odullu", error.message)
	_rew_loader.load(rewarded_id, _istek(), cb)


## Doluluk yoksa hemen tekrar denemek istegi bosa harcar ve pil yakar;
## kisa bir bekleme koyuyoruz.
func _retry(fn: Callable, kind: String, message: String) -> void:
	if not is_inside_tree():
		return
	print("[admob] %s reklam yuklenemedi (%s), %s sn sonra tekrar"
		% [kind, message, RELOAD_DELAY])
	await get_tree().create_timer(RELOAD_DELAY).timeout
	fn.call()


# --------------------------------------------------------------- gosterim

func is_interstitial_ready() -> bool:
	return _interstitial != null


func is_rewarded_ready() -> bool:
	return _rewarded != null


func show_interstitial() -> bool:
	var ad := _interstitial
	if ad == null:
		return false
	_interstitial = null                       # ayni reklam iki kez gosterilemez
	var w := Waiter.new()
	var cb := FullScreenContentCallback.new()
	cb.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		_load_interstitial()
		w.resolve(true)
	cb.on_ad_failed_to_show_full_screen_content = func(error: AdError) -> void:
		push_warning("[admob] gecis reklami gosterilemedi: %s" % error.message)
		ad.destroy()
		_load_interstitial()
		w.resolve(false)
	ad.full_screen_content_callback = cb
	ad.show()
	_arm_watchdog(w)
	return await w.done


func show_rewarded() -> bool:
	var ad := _rewarded
	if ad == null:
		return false
	_rewarded = null
	var w := Waiter.new()
	# GDScript lambda'lari degeri KOPYALAYARAK yakaliyor; degistirilebilir
	# bir kutu gerektigi icin tek elemanli dizi kullaniyoruz.
	var earned := [false]

	var cb := FullScreenContentCallback.new()
	cb.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		_load_rewarded()
		w.resolve(earned[0])
	cb.on_ad_failed_to_show_full_screen_content = func(error: AdError) -> void:
		push_warning("[admob] odullu reklam gosterilemedi: %s" % error.message)
		ad.destroy()
		_load_rewarded()
		w.resolve(false)
	ad.full_screen_content_callback = cb

	var reward := OnUserEarnedRewardListener.new()
	# ODUL YALNIZCA bu geri cagriyla verilir. Reklamin kapanmasi tek basina
	# odul anlamina GELMEZ -- kullanici erken kapatmis olabilir.
	reward.on_user_earned_reward = func(_item: RewardedItem) -> void:
		earned[0] = true
	ad.show(reward)
	_arm_watchdog(w)
	return await w.done


## SDK bazen hicbir geri cagriyi tetiklemiyor (ag kopmasi, arka plan).
## Zaman asimi olmasa `await` sonsuza kadar askida kalir ve OYUN KILITLENIR.
func _arm_watchdog(w: Waiter) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(SHOW_TIMEOUT).timeout
	if is_instance_valid(w):
		w.resolve(false)
