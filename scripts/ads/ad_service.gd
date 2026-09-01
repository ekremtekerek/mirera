extends Node
##
## Reklam katmani (autoload: Ads).

signal rewarded_earned(placement: String)

var provider: AdProvider = null
var busy := false

var _last_ad_msec := 0
var _last_reward_msec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	provider = AdMobAdProvider.new() if AdMobAdProvider.is_available() else StubAdProvider.new()
	add_child(provider)
	# Hangi saglayicinin secildigi logcat'te GORUNSUN.
	#
	# Foldera'da bu satir yoktu ve cihazda sahte saglayicinin calistigi uzun
	# sure fark edilmedi: oyun sorunsuz gorunuyor, oyuncu sahte kaplamayi
	# reklam saniyor, yalnizca AdMob panosu bos kaliyordu -- o da "yeni
	# uygulama" diye okunabiliyordu.
	print("[ads] saglayici: ", provider.provider_name(),
		"  PoingGodotAdMob kayitli mi: ", Engine.has_singleton("PoingGodotAdMob"))
	provider.initialize(Save.consent)
	_last_ad_msec = Time.get_ticks_msec()


func using_stub() -> bool:
	return provider != null and provider.provider_name() == "stub"


func _since(msec: int) -> float:
	return 99999.0 if msec <= 0 else float(Time.get_ticks_msec() - msec) / 1000.0


func maybe_show_interstitial(level: int) -> bool:
	if busy or provider == null:
		return false
	if not AdPolicy.should_show_interstitial({
			"level": level,
			"levels_since_ad": Save.levels_since_ad,
			"seconds_since_ad": _since(_last_ad_msec),
			"seconds_since_reward": _since(_last_reward_msec),
			"ads_removed": Save.ads_removed,
		}):
		return false
	if not provider.is_interstitial_ready():
		return false
	busy = true
	var gosterildi: bool = await provider.show_interstitial()
	busy = false
	if gosterildi:
		_last_ad_msec = Time.get_ticks_msec()
		Save.levels_since_ad = 0
		Save.save_data()
	return gosterildi


func rewarded_ready() -> bool:
	return provider != null and provider.is_rewarded_ready()


## Baslatma zincirinin hangi asamada oldugu. Oyuncuya gosterilen "reklam
## yok" mesajinin sonuna ekleniyor; tek kelime, dort ayri arizayi ayirt
## ediyor ve uzaktan teshisi mumkun kiliyor.
func asama() -> String:
	return provider.asama if provider != null else "yok"


##
## Odullu reklam SUNULABILIR mi -- su anda yuklu olup olmamasindan bagimsiz.
##
## Ipucu dugmesi once `rewarded_ready()` soruyordu ve reklam o an yuklu
## degilse dugmeyi HIC gostermiyordu. Oyuncunun gordugu sey, tikandigi
## seviyede hicbir cikis yolu olmayan bir ekran oldu -- oyun bozuk
## gorunuyor. Oysa yeni bir uygulamada doluluk gecikmesi normal.
##
## Artik dugme her zaman gorunuyor; hazir degilse KISA BIR SURE bekleniyor
## ve olmazsa oyuncuya durum soyleniyor. Sessizlik en kotu cevap.
func rewarded_possible() -> bool:
	return provider != null and not using_stub() and not Save.ads_removed


## Reklam hazir olana kadar bekler. Yukleme dongusu zaten arka planda
## `RELOAD_DELAY` araliklariyla donuyor; burada yalnizca onu bekliyoruz.
func await_rewarded(timeout: float = 8.0) -> bool:
	if provider == null:
		return false
	var gecen := 0.0
	while gecen < timeout:
		if provider.is_rewarded_ready():
			return true
		await get_tree().create_timer(0.25).timeout
		gecen += 0.25
	return false


func show_rewarded(placement: String) -> bool:
	if busy or provider == null or not provider.is_rewarded_ready():
		return false
	busy = true
	var kazandi: bool = await provider.show_rewarded()
	busy = false
	if kazandi:
		_last_reward_msec = Time.get_ticks_msec()
		rewarded_earned.emit(placement)
	return kazandi
