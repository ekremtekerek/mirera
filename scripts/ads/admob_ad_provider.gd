class_name AdMobAdProvider
extends AdProvider
##
## Gercek AdMob saglayicisi (poing-studios/godot-admob-plugin v5).

const TEST_INTERSTITIAL := "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED := "ca-app-pub-3940256099942544/5224354917"
## Gercek birimler. Yalnizca "liveads" etiketi tasiyan derlemede
## kullanilirlar. MIRERA icin AdMob uygulamasi HENUZ ACILMADI -- bos
## birakildilar ve `canli_birimler_hazir()` bu yuzden false donuyor:
## derleme ne olursa olsun TEST birimi kullaniliyor. Doldurmadan once
## AdMob uygulamasinin Play magaza girisine baglanmasi da gerekiyor,
## yoksa sunum "sinirli" kaliyor; bkz. ANDROID.md.
const LIVE_INTERSTITIAL := ""
const LIVE_REWARDED := ""

const SHOW_TIMEOUT := 90.0


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
var interstitial_id := LIVE_INTERSTITIAL if _live else TEST_INTERSTITIAL
var rewarded_id := LIVE_REWARDED if _live else TEST_REWARDED


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
static func canli_birimler_hazir() -> bool:
	return LIVE_INTERSTITIAL != "" and LIVE_REWARDED != ""


var _interstitial: InterstitialAd = null
var _rewarded: RewardedAd = null
var _inter_loader: InterstitialAdLoader = null
var _rew_loader: RewardedAdLoader = null
var _initialized := false


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
##
## `PoingGodotAdMob`, eklentinin MobileAds API'sinin bagli oldugu tekil.
## Kayitliysa reklam katmani gercekten calisir.
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
		if _resolved: return
		_resolved = true
		done.emit(v)


func initialize(consent_mode: String) -> void:
	if not is_available():
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
	if consent_mode != "":
		_init_sdk()


func _init_sdk() -> void:
	if _initialized:
		return
	_initialized = true
	var on_init := OnInitializationCompleteListener.new()
	on_init.on_initialization_complete = func(_s: InitializationStatus) -> void:
		_load_interstitial()
		_load_rewarded()
	MobileAds.set_request_configuration(RequestConfiguration.new())
	MobileAds.initialize(on_init)


func _load_interstitial() -> void:
	if _inter_loader == null or interstitial_id == "":
		return
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_interstitial = ad
		state_changed.emit()
	cb.on_ad_failed_to_load = func(_e: LoadAdError) -> void:
		_interstitial = null
		state_changed.emit()
	_inter_loader.load(interstitial_id, AdRequest.new(), cb)


func _load_rewarded() -> void:
	if _rew_loader == null or rewarded_id == "":
		return
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		_rewarded = ad
		state_changed.emit()
	cb.on_ad_failed_to_load = func(_e: LoadAdError) -> void:
		_rewarded = null
		state_changed.emit()
	_rew_loader.load(rewarded_id, AdRequest.new(), cb)


func is_interstitial_ready() -> bool: return _interstitial != null
func is_rewarded_ready() -> bool: return _rewarded != null


func show_interstitial() -> bool:
	var ad := _interstitial
	if ad == null:
		return false
	_interstitial = null                       # ayni reklam iki kez gosterilemez
	var w := Waiter.new()
	var cb := FullScreenContentCallback.new()
	cb.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy(); _load_interstitial(); w.resolve(true)
	cb.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void:
		ad.destroy(); _load_interstitial(); w.resolve(false)
	ad.full_screen_content_callback = cb
	ad.show()
	_watchdog(w)
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
		ad.destroy(); _load_rewarded(); w.resolve(earned[0])
	cb.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void:
		ad.destroy(); _load_rewarded(); w.resolve(false)
	ad.full_screen_content_callback = cb
	var reward := OnUserEarnedRewardListener.new()
	# ODUL YALNIZCA bu geri cagriyla verilir. Reklamin kapanmasi tek basina
	# odul anlamina GELMEZ -- kullanici erken kapatmis olabilir.
	reward.on_user_earned_reward = func(_i: RewardedItem) -> void:
		earned[0] = true
	ad.show(reward)
	_watchdog(w)
	return await w.done


## SDK bazen hicbir geri cagriyi tetiklemiyor (ag kopmasi, arka plan).
## Zaman asimi olmasa `await` sonsuza kadar askida kalir ve OYUN KILITLENIR.
func _watchdog(w: Waiter) -> void:
	var t := get_tree().create_timer(SHOW_TIMEOUT)
	t.timeout.connect(func() -> void: w.resolve(false))
