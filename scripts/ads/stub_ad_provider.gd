class_name StubAdProvider
extends AdProvider
##
## Sahte saglayici: masaustu ve testler icin.
##
## DIKKAT -- Foldera'da aci bir ders: bu saglayici CIHAZDA da secilirse oyun
## sorunsuz gorunur, oyuncu sahte kaplamayi gercek reklam sanir ve gelir
## sessizce sifir kalir. Hicbir hata mesaji cikmaz. Bu yuzden `AdService`
## secilen saglayiciyi loga yaziyor.

func provider_name() -> String: return "stub"
func is_interstitial_ready() -> bool: return true
func is_rewarded_ready() -> bool: return true


func show_interstitial() -> bool:
	await _bekle(1.0)
	return true


func show_rewarded() -> bool:
	await _bekle(1.6)
	return true


func _bekle(s: float) -> void:
	await get_tree().create_timer(s).timeout
