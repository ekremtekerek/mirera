class_name AdPolicy
extends RefCounted
##
## Reklam sikligi kurallari. SAF fonksiyonlar: dogrudan test edilebiliyor,
## cihaz ya da SDK gerekmiyor.
##
## "Her yasa hitap etsin" karari burada da isliyor: ilk on seviye tamamen
## reklamsiz. Oyuncu once oyunu sevmeli; ilk dakikada reklam gosteren oyun
## silinir.

const FIRST_FREE_LEVELS := 10
const EVERY_N_LEVELS := 3
const MIN_GAP_SECONDS := 90.0
const REWARD_COOLDOWN_SECONDS := 45.0


static func should_show_interstitial(state: Dictionary) -> bool:
	# Satin alma her seyi kapatir -- ILK kontrol bu olmali.
	if bool(state.get("ads_removed", false)):
		return false
	if int(state.get("level", 1)) <= FIRST_FREE_LEVELS:
		return false
	if int(state.get("levels_since_ad", 0)) < EVERY_N_LEVELS:
		return false
	if float(state.get("seconds_since_ad", 0.0)) < MIN_GAP_SECONDS:
		return false
	# Odullu reklam izledikten hemen sonra gecis reklami gostermek
	# kullaniciyi cezalandirmak gibi duruyor.
	if float(state.get("seconds_since_reward", 9999.0)) < REWARD_COOLDOWN_SECONDS:
		return false
	return true
