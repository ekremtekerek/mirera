extends Node
##
## Cok dillilik (autoload: Loc).
##
## Dil CIHAZDAN geliyor: oyuncuya dil sormuyoruz. Bir bulmaca oyununda ilk
## ekranda dil menusu gostermek gereksiz surtunme -- telefon zaten hangi
## dili konustugunu biliyor.
##
## Desteklenmeyen dilde ingilizceye dusuyoruz; bos ekran ya da anahtar
## adi gostermek yerine anlasilir bir sey gostermek her zaman daha iyi.

const SUPPORTED := ["en", "tr", "es", "pt", "de", "fr", "it",
	"ru", "pl", "nl", "id", "vi", "uk"]
const FALLBACK := "en"
## Ceviriler CSV'den DEGIL, Godot'nun CSV'den urettigi `.translation` 
## kaynaklarindan okunuyor.
##
## Ham CSV disa aktarima GIRMIYOR: iceri aktarma isleyicisi onu her dil icin
## bir Translation kaynagina cevirip kaynak dosyayi disarida birakiyor.
## `FileAccess.open("res://locale/mirera.csv")` duzenleyicide calisiyor,
## APK icinde null donuyor -- yani telefonda BUTUN metinler anahtar adina
## dusuyordu ("BTN_START" gibi) ve bu ancak cihazda fark edilirdi.
## `load()` her iki ortamda da ayni sekilde calisiyor.
const CEVIRI := "res://locale/mirera.%s.translation"

var _table := {}         ## dil kodu -> Translation
var lang := FALLBACK


func _ready() -> void:
	_load()
	lang = resolve(OS.get_locale_language())
	# Komut satirindan dil zorlama: `-- ru` gibi. Arayuz kurulmadan ONCE
	# calismasi sart, yoksa dugmeler eski dilde kaliyor.
	for a in OS.get_cmdline_user_args():
		if a.length() == 2 and SUPPORTED.has(a):
			lang = a
	print("[loc] cihaz: %s -> secilen: %s" % [OS.get_locale_language(), lang])


## Cihaz dilini destekledigimiz bir dile esler.
static func resolve(device: String) -> String:
	var kod := device.to_lower().split("_")[0].split("-")[0]
	return kod if SUPPORTED.has(kod) else FALLBACK


func t(key: String) -> String:
	var s := _cevir(lang, key)
	if s != "":
		return s
	s = _cevir(FALLBACK, key)
	return s if s != "" else key        # anahtar gorunsun ki eksik fark edilsin


func _cevir(kod: String, key: String) -> String:
	var c: Translation = _table.get(kod)
	if c == null:
		return ""
	return c.get_message(key)


## Bicimli metin: "{0}" yerine deger koyar.
func f(key: String, args: Array) -> String:
	var s := t(key)
	for i in args.size():
		s = s.replace("{%d}" % i, str(args[i]))
	return s


func _load() -> void:
	for kod in SUPPORTED:
		var c: Translation = ResourceLoader.load(CEVIRI % kod) as Translation
		if c == null:
			push_warning("[loc] ceviri yuklenemedi: %s" % kod)
			continue
		_table[kod] = c
	# Eksik dil sessizce ingilizceye dusuyor ama HIC dil yoksa oyun anahtar
	# adlariyla acilir; bunu paketleme hatasi olarak gorunur kilmak sart.
	if _table.is_empty():
		push_error("[loc] hicbir ceviri yuklenemedi -- metinler anahtar adiyla cikacak")
