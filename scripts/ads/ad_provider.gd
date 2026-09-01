class_name AdProvider
extends Node
##
## Reklam saglayicisinin sozlesmesi. Oyun kodu YALNIZCA bu arayuzu taniyor;
## ne AdMob'u ne sahte saglayiciyi biliyor. Masaustunde gelistirme surerken
## cihazda gercek reklam calisabiliyor, cagri noktalari degismiyor.
##
## Butun `show_*` fonksiyonlari await edilebilir ve HER ZAMAN doner --
## reklam dolmadiysa, hata verdiyse ya da kullanici kapattiysa bile. Oyun
## akisi reklamin sonucunu beklerken asla kilitlenmemeli.

signal state_changed

var consent := ""          ## "" | "personalized" | "limited"

##
## Son yukleme hatasi ve basarisiz deneme sayisi.
##
## "Reklam izle dugmesi hic cikmadi" ile "reklam doldurulmadi" disaridan
## AYIRT EDILEMIYOR: ikisi de sessiz. Oysa ilki bir kod hatasi, ikincisi
## yeni bir uygulamada tamamen normal. Sebebi saklamazsak her seferinde
## bastan tahmin yurutmek zorunda kaliyoruz.
var son_hata := ""
var basarisiz := 0

##
## Baslatma zincirinin NEREDE takildigini soyleyen asama etiketi.
##
##   "baslamadi" -> initialize hic cagrilmadi
##   "riza"      -> UMP donmedi
##   "sdk"       -> SDK baslatma donmedi
##   "yukleme"   -> istek atildi ama dolmadi
##   "hazir"     -> reklam yuklu
##
## Bu etiket olmadan disaridan hepsi ayni gorunuyor: dugme cikiyor, reklam
## gelmiyor. Oyuncuya gosterilen "reklam yok" mesajinin sonuna ekleniyor --
## tek kelime, dort ayri arizayi ayirt ediyor.
var asama := "baslamadi"


func provider_name() -> String:
	return "temel"


func initialize(consent_mode: String) -> void:
	consent = consent_mode


## Reklam hazir mi. Hazir degilse cagiran taraf reklami ATLAMALI, beklememeli.
func is_interstitial_ready() -> bool:
	return false


func is_rewarded_ready() -> bool:
	return false


## Gosterildi mi (yuklenemediyse false).
func show_interstitial() -> bool:
	return false


## Odul hak edildi mi (kullanici erken kapattiysa false).
func show_rewarded() -> bool:
	return false


func preload_all() -> void:
	pass
